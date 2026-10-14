import AmpersandCore
import AppKit
import UniformTypeIdentifiers
import Observation

struct Banner: Identifiable, Equatable {
    enum Action: Equatable { case retrySave, revealConfig }
    let id = UUID()
    var message: String
    var action: Action?
    /// Problems get the warning triangle; plain information gets the info icon (DESIGN.md).
    var isProblem = true
}

enum EditorRequest: Identifiable, Equatable {
    case new(prefill: String = "")
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

/// Running commands whose working directory changed through their group; the window asks to restart them.
struct RestartPrompt: Equatable {
    var ids: [UUID]
}

/// Single source of truth for the UI. Owns every Supervisor.
@MainActor @Observable
final class AppModel {
    private(set) var config: AppConfig = .empty
    private(set) var runtimes: [UUID: CommandRuntime] = [:]
    private(set) var configIsReadOnly = false
    /// Run Once processes from the editor: not in the config, but quit and crash cleanup must know them.
    private(set) var transientRuntimes: [UUID: CommandRuntime] = [:]
    var banner: Banner?
    var popoverSelection: UUID?
    var windowSelection: UUID?
    var windowTab: DetailTab = .log
    var editorRequest: EditorRequest?
    /// The window's "New group" alert; the toolbar and the Command menu both open it.
    var isAddingGroup = false
    var restartPrompt: RestartPrompt?
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
    /// Supervisors of deleted or replaced commands that are still shutting down.
    @ObservationIgnored private var retiring: [UUID: Supervisor] = [:]

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
            show(Banner(message: "Cleaned up \(cleaned) \(cleaned == 1 ? "process" : "processes") from the last session.", isProblem: false))
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

    /// True while anything Ampersand started could still be alive, so quitting must wait.
    var needsGracefulQuit: Bool {
        activeCount > 0 || !retiring.isEmpty || transientRuntimes.values.contains { $0.status.isActive }
    }

    private func stopAllProcesses() async {
        let supervisors = runtimes.values.map(\.supervisor)
            + transientRuntimes.values.map(\.supervisor)
            + Array(retiring.values)
        await withTaskGroup(of: Void.self) { group in
            for supervisor in supervisors { group.addTask { await supervisor.stop() } }
        }
    }

    // MARK: - Derived state

    var sections: [ConfigSection] { ConfigEditor.sections(of: config) }
    var orderedRuntimes: [CommandRuntime] { sections.flatMap(\.commands).compactMap { runtimes[$0.id] } }
    var activeCount: Int { runtimes.values.filter { $0.status.isActive }.count }
    /// Commands with a live process (what quitting actually stops); excludes pending restarts.
    var processCount: Int {
        runtimes.values.filter { [.starting, .running, .stopping].contains($0.status.kind) }.count
    }
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

    /// The command's log without ANSI escapes, for copying and exporting.
    func plainLog(_ id: UUID) -> String {
        guard let runtime = runtimes[id] else { return "" }
        return (runtime.lines + (runtime.partialLine.isEmpty ? [] : [runtime.partialLine]))
            .map { line in
                var parser = ANSIParser()
                return parser.parse(line).map(\.text).joined()
            }
            .joined(separator: "\n")
    }

    func copyLog(_ id: UUID) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(plainLog(id), forType: .string)
    }

    func exportLog(_ id: UUID) {
        guard let runtime = runtimes[id] else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(runtime.spec.name).log"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try plainLog(id).write(to: url, atomically: true, encoding: .utf8) }
        catch { show(Banner(message: "Couldn’t export the log: \(error.localizedDescription)"), autoDismiss: false) }
    }

    /// Moves a command one place up or down within its group (menu alternative to dragging).
    func move(_ id: UUID, by offset: Int) {
        guard let spec = runtimes[id]?.spec else { return }
        let siblings = config.commands.filter { $0.group == spec.group }.map(\.id)
        guard let index = siblings.firstIndex(of: id), siblings.indices.contains(index + offset) else { return }
        if offset < 0 {
            reorder(id, before: siblings[index - 1])
        } else {
            reorder(siblings[index + 1], before: id)
        }
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

    func requestNew(prefill: String = "") { editorRequest = .new(prefill: prefill); openMainWindow() }
    func requestImport() { editorRequest = .importProject; openMainWindow() }
    func requestNewGroup() { isAddingGroup = true; openMainWindow() }

    func requestEdit(_ id: UUID) {
        windowSelection = id
        editorRequest = .edit(id)
        openMainWindow()
    }

    /// An edit from the auto-applying Settings tab: saves it and registers Undo back to `previous`.
    @discardableResult
    func applyEdit(_ spec: CommandSpec, previous: CommandSpec) -> Bool {
        guard save(spec) else { return false }
        undoManager.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated { model.applyEdit(previous, previous: spec) }
        }
        undoManager.setActionName("Edit “\(previous.name)”")
        return true
    }

    /// Adds a new command or updates an existing one. Never restarts on its own.
    /// Returns false when the change could not be written (the banner says why).
    @discardableResult
    func save(_ spec: CommandSpec) -> Bool {
        if let runtime = runtimes[spec.id] {
            let old = runtime.spec
            let oldCwd = ConfigEditor.effectiveCwd(of: old, in: config)
            ConfigEditor.update(spec, in: &config)
            runtime.spec = spec
            let cwdChanged = oldCwd != ConfigEditor.effectiveCwd(of: spec, in: config)
            let launchChanged = old.command != spec.command || cwdChanged
                || old.env != spec.env || old.envFile != spec.envFile
            Task { await runtime.supervisor.update(spec: ConfigEditor.launchSpec(for: spec, in: config)) }
            if launchChanged && runtime.status.isActive {
                // Clearing its own folder hands it the group's: ask, as for the other group-level changes.
                let nowInherits = WorkingDirectory.normalized(old.cwd) != nil && WorkingDirectory.normalized(spec.cwd) == nil
                if cwdChanged && nowInherits { offerRestart([spec.id]) } else { runtime.needsRestartToApply = true }
            }
        } else {
            ConfigEditor.add(spec, to: &config)
            makeRuntime(spec)
        }
        return persist()
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
        retire(runtime.supervisor)
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
        changeGroups { config in ConfigEditor.move(id: id, toGroup: group, in: &config) }
    }

    /// A sidebar drop: into `group`, next to a row or at the end. Never restarts on its own.
    func move(_ id: UUID, toGroup group: String?, placing: ConfigEditor.Placement) {
        changeGroups { config in ConfigEditor.move(id: id, toGroup: group, placing: placing, in: &config) }
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

    /// Name and working directory from the group's settings sheet.
    func updateGroup(_ id: String, name: String, cwd: String) {
        changeGroups { config in
            ConfigEditor.renameGroup(id: id, to: name, in: &config)
            ConfigEditor.setGroupCwd(id: id, to: cwd, in: &config)
        }
    }

    func deleteGroup(_ id: String) {
        changeGroups { config in ConfigEditor.deleteGroup(id: id, in: &config) }
    }

    /// A change to groups or group membership. Commands whose effective working directory
    /// changes get it for their next start; running ones are offered a restart.
    private func changeGroups(_ change: (inout AppConfig) -> Void) {
        let old = config
        change(&config)
        for spec in config.commands {
            guard let runtime = runtimes[spec.id], runtime.spec != spec else { continue }
            runtime.spec = spec
        }
        let changed = ConfigEditor.cwdChanges(from: old, to: config)
        for id in changed {
            guard let runtime = runtimes[id] else { continue }
            let launch = ConfigEditor.launchSpec(for: runtime.spec, in: config)
            Task { await runtime.supervisor.update(spec: launch) }
        }
        persist()
        offerRestart(changed)
    }

    /// Asks in the window whether to restart running commands now. Without a visible window
    /// (a change from the popover) they get the passive "restart to apply" notice instead.
    private func offerRestart(_ ids: [UUID]) {
        let active = ids.filter { id in
            guard let runtime = runtimes[id], runtime.status.isActive else { return false }
            return runtime.launchedCwd != ConfigEditor.effectiveCwd(of: runtime.spec, in: config)
        }
        guard !active.isEmpty else { return }
        guard isWindowVisible else {
            active.forEach { runtimes[$0]?.needsRestartToApply = true }
            return
        }
        let pending = restartPrompt?.ids ?? []
        restartPrompt = RestartPrompt(ids: pending + active.filter { !pending.contains($0) })
    }

    var restartPromptText: (title: String, message: String) {
        StatusText.restartPrompt(names: (restartPrompt?.ids ?? []).compactMap { runtimes[$0]?.spec.name })
    }

    func answerRestartPrompt(restartNow: Bool) {
        guard let prompt = restartPrompt else { return }
        restartPrompt = nil
        for id in prompt.ids {
            if restartNow { restart(id) } else { runtimes[id]?.needsRestartToApply = true }
        }
    }

    func exportConfig(to url: URL) {
        do { try store.export(config, to: url) }
        catch { show(Banner(message: "Couldn’t export: \(error.localizedDescription)"), autoDismiss: false) }
    }

    /// Replaces every command with the imported file's, stopping what runs now.
    func importConfig(from url: URL) async {
        let imported: AppConfig
        do { imported = try store.importConfig(from: url) }
        catch {
            show(Banner(message: "Couldn’t import that file. It isn’t an Ampersand config."), autoDismiss: false)
            return
        }
        await stopAllProcesses()
        runtimes.values.forEach { retire($0.supervisor) }
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

    @discardableResult
    private func persist() -> Bool {
        guard !configIsReadOnly else {
            show(Banner(message: "Changes can’t be saved while config.json is unreadable.", action: .revealConfig),
                 autoDismiss: false)
            return false
        }
        do {
            try store.save(config)
            return true
        } catch {
            show(Banner(message: "Couldn’t save your changes: \(error.localizedDescription)", action: .retrySave),
                 autoDismiss: false)
            return false
        }
    }

    // MARK: - Supervisor events

    /// Shuts a supervisor down while keeping it visible to quit until its processes are gone.
    private func retire(_ supervisor: Supervisor) {
        retiring[supervisor.id] = supervisor
        Task {
            await supervisor.shutdown()
            retiring[supervisor.id] = nil
        }
    }

    /// A Run Once process: tracked for quit and crash cleanup, never notified about, never saved.
    func makeTransientRuntime(_ spec: CommandSpec) -> CommandRuntime {
        let runtime = CommandRuntime(spec: spec, supervisor: Supervisor(spec: ConfigEditor.launchSpec(for: spec, in: config)))
        transientRuntimes[spec.id] = runtime
        Task { [weak self] in
            for await event in runtime.supervisor.events {
                self?.handle(event, for: runtime, notify: false)
            }
        }
        return runtime
    }

    func retireTransient(_ runtime: CommandRuntime) {
        guard transientRuntimes.removeValue(forKey: runtime.id) != nil else { return }
        retire(runtime.supervisor)
    }

    private func makeRuntime(_ spec: CommandSpec) {
        let runtime = CommandRuntime(spec: spec, supervisor: Supervisor(spec: ConfigEditor.launchSpec(for: spec, in: config)))
        runtimes[spec.id] = runtime
        Task { [weak self] in
            for await event in runtime.supervisor.events {
                self?.handle(event, for: runtime)
            }
        }
    }

    private func handle(_ event: SupervisorEvent, for runtime: CommandRuntime, notify: Bool = true) {
        switch event {
        case .status(let status):
            let previous = runtime.status
            runtime.status = status
            switch status.kind {
            case .starting:
                Task {
                    runtime.launchedCwd = await runtime.supervisor.currentSpec.cwd
                    runtime.pid = await runtime.supervisor.currentPID
                    updateTrackedProcesses()
                }
            case .running, .stopping:
                break
            case .stopped, .backoff, .exited, .finished, .gaveUp, .failed:
                if let pid = runtime.pid { sampler.forget(group: pid) }
                runtime.pid = nil
                runtime.sample = nil
                runtime.health = nil
                runtime.healthFailingSince = nil
                updateTrackedProcesses()
            }
            if notify { notifications.notifyIfNeeded(command: runtime.spec, from: previous, to: status) }
        case .output(let lines, let partial):
            runtime.receive(newLines: lines, partialLine: partial)
        case .logCleared:
            break
        }
    }

    private func updateTrackedProcesses() {
        let tracked = (Array(runtimes.values) + Array(transientRuntimes.values)).compactMap { runtime -> TrackedProcess? in
            guard let pid = runtime.pid, let started = OrphanReaper.startTime(of: pid) else { return nil }
            return TrackedProcess(pgid: pid, startTime: started)
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
