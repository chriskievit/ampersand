import AmpersandCore
import AppKit
import Observation

struct Banner: Identifiable, Equatable {
    enum Action: Equatable { case retrySave, revealConfig }
    let id = UUID()
    var message: String
    var action: Action?
}

enum EditorRequest: Identifiable, Equatable {
    case new
    case edit(UUID)
    case importProject

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let id): id.uuidString
        case .importProject: "import"
        }
    }
}

enum DetailTab: Hashable { case log, settings }

/// Single source of truth for the UI. Owns every Supervisor.
@MainActor @Observable
final class AppModel {
    private(set) var config: AppConfig = .empty
    private(set) var runtimes: [UUID: CommandRuntime] = [:]
    private(set) var configIsReadOnly = false
    var banner: Banner?
    var popoverSelection: UUID?
    var windowSelection: UUID?
    var windowTab: DetailTab = .log
    var editorRequest: EditorRequest?
    var isPopoverVisible = false { didSet { if isPopoverVisible { sampleNow() } } }
    var isWindowVisible = false { didSet { if isWindowVisible { sampleNow() } } }

    @ObservationIgnored let undoManager = UndoManager()
    @ObservationIgnored let notifications = NotificationService()
    @ObservationIgnored var openMainWindow: () -> Void = {}

    @ObservationIgnored private let store: ConfigStore
    @ObservationIgnored private let reaper: OrphanReaper
    @ObservationIgnored private var sampler = ResourceSampler()
    @ObservationIgnored private var loops: [Task<Void, Never>] = []
    @ObservationIgnored private var screenLocked = false
    @ObservationIgnored private var bannerDismissTask: Task<Void, Never>?

    init(directory: URL = ConfigStore.defaultDirectory()) {
        store = ConfigStore(directory: directory)
        reaper = OrphanReaper(fileURL: directory.appendingPathComponent("pgids.json"))
        notifications.onOpenLog = { [weak self] id in self?.showLog(id) }
    }

    // MARK: - Launch and quit

    func launch() {
        let cleaned = reaper.reap()
        do {
            config = try store.load()
        } catch {
            configIsReadOnly = true
            show(Banner(message: "Ampersand couldn’t read config.json, so no commands were loaded. Fix or move the file, then relaunch.",
                        action: .revealConfig), autoDismiss: false)
        }
        config.commands.forEach(makeRuntime)
        if cleaned > 0 {
            show(Banner(message: "Cleaned up \(cleaned) \(cleaned == 1 ? "process" : "processes") from the last session."))
        }
        for spec in config.commands where spec.autoStart { start(spec.id) }
        observeScreenLock()
        loops = [Task { await monitorLoop() }, Task { await healthLoop() }]
    }

    /// Quit path: stop every process in parallel (each SIGKILLed after 5 s), then forget them.
    func stopAll() async {
        await stopAllProcesses()
        finishQuitting()
    }

    func finishQuitting() {
        loops.forEach { $0.cancel() }
        reaper.clear()
    }

    private func stopAllProcesses() async {
        let supervisors = runtimes.values.map(\.supervisor)
        await withTaskGroup(of: Void.self) { group in
            for supervisor in supervisors { group.addTask { await supervisor.stop() } }
        }
    }

    // MARK: - Derived state

    var sections: [ConfigSection] { ConfigEditor.sections(of: config) }
    var orderedRuntimes: [CommandRuntime] { sections.flatMap(\.commands).compactMap { runtimes[$0.id] } }
    var activeCount: Int { runtimes.values.filter { $0.status.isActive }.count }
    var runningCount: Int { runtimes.values.filter { [.starting, .running].contains($0.status.kind) }.count }
    var attentionCount: Int { runtimes.values.filter { [.exited, .gaveUp, .failed].contains($0.status.kind) }.count }

    func runtime(_ id: UUID?) -> CommandRuntime? { id.flatMap { runtimes[$0] } }

    func commands(inGroup groupID: String?) -> [CommandRuntime] {
        sections.first { $0.id == (groupID ?? "") }?.commands.compactMap { runtimes[$0.id] } ?? []
    }

    // MARK: - Process intents

    func start(_ id: UUID, force: Bool = false) {
        guard let runtime = runtimes[id] else { return }
        runtime.portConflict = nil
        runtime.needsRestartToApply = false
        Task {
            if !force, !runtime.status.isActive, let port = runtime.spec.port,
               let owner = await PortProbe.owner(of: port), !ownsProcess(owner.pid) {
                runtime.portConflict = owner
                return
            }
            await notifications.requestAuthorizationIfNeeded()
            await runtime.supervisor.start()
        }
    }

    func stop(_ id: UUID) {
        guard let runtime = runtimes[id] else { return }
        runtime.portConflict = nil
        Task { await runtime.supervisor.stop() }
    }

    func restart(_ id: UUID) {
        guard let runtime = runtimes[id] else { return }
        runtime.needsRestartToApply = false
        Task { await runtime.supervisor.restart() }
    }

    func toggle(_ id: UUID) {
        guard let runtime = runtimes[id] else { return }
        runtime.status.isActive ? stop(id) : start(id)
    }

    /// Stops the whole group if anything in it is active, otherwise starts all of it.
    func toggleGroup(_ groupID: String?) {
        let members = commands(inGroup: groupID)
        if members.contains(where: { $0.status.isActive }) {
            members.forEach { stop($0.id) }
        } else {
            members.forEach { start($0.id) }
        }
    }

    func killPortOwnerAndStart(_ id: UUID) {
        guard let owner = runtimes[id]?.portConflict else { return }
        kill(owner.pid, SIGTERM)
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            start(id, force: true)
        }
    }

    func openInBrowser(_ id: UUID) {
        guard let port = runtimes[id]?.spec.port, let url = URL(string: "http://localhost:\(port)") else { return }
        NSWorkspace.shared.open(url)
    }

    func showLog(_ id: UUID) {
        windowSelection = id
        windowTab = .log
        openMainWindow()
    }

    func clearLog(_ id: UUID) {
        guard let runtime = runtimes[id] else { return }
        runtime.clearLog()
        Task { await runtime.supervisor.clearLog() }
    }

    private func ownsProcess(_ pid: pid_t) -> Bool {
        runtimes.values.contains { runtime in
            runtime.pid.map { ProcessTree.pids(inGroup: $0).contains(pid) } ?? false
        }
    }

    // MARK: - Editing intents

    func requestNew() { editorRequest = .new; openMainWindow() }
    func requestImport() { editorRequest = .importProject; openMainWindow() }

    func requestEdit(_ id: UUID) {
        windowSelection = id
        editorRequest = .edit(id)
        openMainWindow()
    }

    /// Adds a new command or updates an existing one. Never restarts on its own.
    func save(_ spec: CommandSpec) {
        if let runtime = runtimes[spec.id] {
            let old = runtime.spec
            let launchChanged = old.command != spec.command || old.cwd != spec.cwd
                || old.env != spec.env || old.envFile != spec.envFile
            ConfigEditor.update(spec, in: &config)
            runtime.spec = spec
            Task { await runtime.supervisor.update(spec: spec) }
            if launchChanged && runtime.status.isActive { runtime.needsRestartToApply = true }
        } else {
            ConfigEditor.add(spec, to: &config)
            makeRuntime(spec)
        }
        persist()
    }

    func add(_ specs: [CommandSpec], newGroupNamed groupName: String?) {
        let groupID = groupName.map { ConfigEditor.addGroup(named: $0, to: &config).id }
        for var spec in specs {
            if let groupID { spec.group = groupID }
            ConfigEditor.add(spec, to: &config)
            makeRuntime(spec)
        }
        persist()
    }

    func delete(_ id: UUID) {
        guard let runtime = runtimes[id], let deleted = ConfigEditor.delete(id: id, from: &config) else { return }
        runtimes[id] = nil
        if popoverSelection == id { popoverSelection = nil }
        if windowSelection == id { windowSelection = nil }
        Task { await runtime.supervisor.shutdown() }
        persist()
        undoManager.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated { model.restore(deleted) }
        }
        undoManager.setActionName("Delete “\(deleted.spec.name)”")
    }

    private func restore(_ deleted: DeletedCommand) {
        ConfigEditor.restore(deleted, in: &config)
        makeRuntime(deleted.spec)
        persist()
    }

    func duplicate(_ id: UUID) {
        guard let copy = ConfigEditor.duplicate(id: id, in: &config) else { return }
        makeRuntime(copy)
        popoverSelection = copy.id
        windowSelection = copy.id
        persist()
    }

    func move(_ id: UUID, toGroup group: String?) {
        ConfigEditor.move(id: id, toGroup: group, in: &config)
        runtimes[id]?.spec.group = group
        persist()
    }

    func reorder(_ id: UUID, before target: UUID?) {
        ConfigEditor.reorder(id: id, before: target, in: &config)
        persist()
    }

    @discardableResult
    func addGroup(named name: String) -> GroupSpec {
        let group = ConfigEditor.addGroup(named: name, to: &config)
        persist()
        return group
    }

    func renameGroup(_ id: String, to name: String) {
        ConfigEditor.renameGroup(id: id, to: name, in: &config)
        persist()
    }

    func deleteGroup(_ id: String) {
        ConfigEditor.deleteGroup(id: id, in: &config)
        for runtime in runtimes.values where runtime.spec.group == id { runtime.spec.group = nil }
        persist()
    }

    func exportConfig(to url: URL) {
        do { try store.export(config, to: url) }
        catch { show(Banner(message: "Couldn’t export: \(error.localizedDescription)")) }
    }

    /// Replaces every command with the imported file's, stopping what runs now.
    func importConfig(from url: URL) async {
        let imported: AppConfig
        do { imported = try store.importConfig(from: url) }
        catch {
            show(Banner(message: "Couldn’t import that file. It isn’t an Ampersand config."))
            return
        }
        await stopAllProcesses()
        runtimes.values.forEach { runtime in Task { await runtime.supervisor.shutdown() } }
        runtimes = [:]
        popoverSelection = nil
        windowSelection = nil
        config = imported
        configIsReadOnly = false
        config.commands.forEach(makeRuntime)
        persist()
    }

    // MARK: - Banner and persistence

    func show(_ banner: Banner, autoDismiss: Bool = true) {
        self.banner = banner
        bannerDismissTask?.cancel()
        guard autoDismiss else { return }
        bannerDismissTask = Task {
            guard (try? await Task.sleep(for: .seconds(8))) != nil else { return }
            if self.banner?.id == banner.id { self.banner = nil }
        }
    }

    func retrySave() {
        banner = nil
        persist()
    }

    func revealConfig() {
        NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
    }

    private func persist() {
        guard !configIsReadOnly else {
            show(Banner(message: "Changes can’t be saved while config.json is unreadable.", action: .revealConfig))
            return
        }
        do { try store.save(config) }
        catch {
            show(Banner(message: "Couldn’t save your changes: \(error.localizedDescription)", action: .retrySave),
                 autoDismiss: false)
        }
    }

    // MARK: - Supervisor events

    private func makeRuntime(_ spec: CommandSpec) {
        let runtime = CommandRuntime(spec: spec, supervisor: Supervisor(spec: spec))
        runtimes[spec.id] = runtime
        Task { [weak self] in
            for await event in runtime.supervisor.events {
                self?.handle(event, for: runtime)
            }
        }
    }

    private func handle(_ event: SupervisorEvent, for runtime: CommandRuntime) {
        switch event {
        case .status(let status):
            let previous = runtime.status
            runtime.status = status
            switch status.kind {
            case .starting:
                Task {
                    runtime.pid = await runtime.supervisor.currentPID
                    updateTrackedProcesses()
                }
            case .running, .stopping:
                break
            case .stopped, .backoff, .exited, .gaveUp, .failed:
                if let pid = runtime.pid { sampler.forget(group: pid) }
                runtime.pid = nil
                runtime.sample = nil
                runtime.health = nil
                runtime.healthFailingSince = nil
                updateTrackedProcesses()
            }
            notifications.notifyIfNeeded(command: runtime.spec, from: previous, to: status)
        case .output(let lines, let partial):
            runtime.receive(newLines: lines, partialLine: partial)
        case .logCleared:
            break
        }
    }

    private func updateTrackedProcesses() {
        let tracked = runtimes.values.compactMap { runtime -> TrackedProcess? in
            guard let pid = runtime.pid, let line = OrphanReaper.commandLine(of: pid) else { return nil }
            return TrackedProcess(pgid: pid, commandLine: line)
        }
        if tracked.isEmpty { reaper.clear() } else { try? reaper.record(tracked) }
    }

    // MARK: - Monitoring loops

    func sampleNow() {
        guard !screenLocked else { return }
        let now = Date()
        for runtime in runtimes.values {
            guard let pid = runtime.pid else { continue }
            runtime.sample = sampler.sample(group: pid, at: now)
        }
    }

    private func monitorLoop() async {
        while !Task.isCancelled {
            sampleNow()
            let visible = isPopoverVisible || isWindowVisible
            try? await Task.sleep(for: .seconds(visible ? 2 : 10))
        }
    }

    private func healthLoop() async {
        while !Task.isCancelled {
            if !screenLocked {
                for runtime in Array(runtimes.values) where [.starting, .running].contains(runtime.status.kind) {
                    guard let check = runtime.spec.health else { continue }
                    let result = await HealthChecker.check(check, port: runtime.spec.port)
                    runtime.health = result
                    if result == .healthy {
                        runtime.healthFailingSince = nil
                        await runtime.supervisor.markHealthy()
                    } else if runtime.healthFailingSince == nil {
                        runtime.healthFailingSince = Date()
                    }
                }
            }
            try? await Task.sleep(for: .seconds(10))
        }
    }

    private func observeScreenLock() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenLocked = true }
        }
        center.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.screenLocked = false
                self?.sampleNow()
            }
        }
    }
}
