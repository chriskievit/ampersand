import Foundation

public struct DetectedScript: Sendable, Equatable, Identifiable {
    public var id: String { name }
    public var name: String
    public var body: String
    public var command: String
    public var port: Int?
}

public struct DetectedProject: Sendable, Equatable {
    public var folder: URL
    public var name: String
    public var packageManager: String
    public var scripts: [DetectedScript]
}

/// Reads a project folder's package.json and proposes commands.
public enum ProjectDetector {
    private static let preferredOrder = ["dev", "start", "serve", "storybook"]

    public static func detect(folder: URL) -> DetectedProject? {
        let packageURL = folder.appendingPathComponent("package.json")
        guard let data = try? Data(contentsOf: packageURL),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        let manager = packageManager(in: folder)
        let rawScripts = json["scripts"] as? [String: String] ?? [:]
        let scripts = rawScripts.keys.sorted(by: scriptOrder).map { name in
            DetectedScript(name: name, body: rawScripts[name]!, command: "\(manager) run \(name)",
                           port: guessPort(scriptBody: rawScripts[name]!))
        }
        let name = (json["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? folder.lastPathComponent
        return DetectedProject(folder: folder, name: name, packageManager: manager, scripts: scripts)
    }

    public static func makeSpecs(for project: DetectedProject, selecting names: [String], group: String?) -> [CommandSpec] {
        let cwd = (project.folder.path as NSString).abbreviatingWithTildeInPath
        return project.scripts.filter { names.contains($0.name) }.map {
            CommandSpec(name: $0.name, command: $0.command, cwd: cwd, group: group, port: $0.port)
        }
    }

    public static func guessPort(scriptBody: String) -> Int? {
        let tokens = CommandLineParser.tokenize(Substring(scriptBody))
        for (i, token) in tokens.enumerated() {
            if (token == "--port" || token == "-p"), i + 1 < tokens.count, let port = Int(tokens[i + 1]) { return port }
            if token.hasPrefix("--port="), let port = Int(token.dropFirst("--port=".count)) { return port }
        }
        func subcommand(after tool: String) -> String?? {
            guard let index = tokens.firstIndex(of: tool) else { return nil }
            return .some(index + 1 < tokens.count ? tokens[index + 1] : nil)
        }
        if let sub = subcommand(after: "vite") {
            switch sub {
            case nil, "dev", "serve": return 5173
            case "preview": return 4173
            case let s? where s.hasPrefix("-"): return 5173
            default: return nil
            }
        }
        if let sub = subcommand(after: "next"), sub == "dev" || sub == "start" { return 3000 }
        if let sub = subcommand(after: "storybook"), sub == "dev" { return 6006 }
        return nil
    }

    private static func packageManager(in folder: URL) -> String {
        let fm = FileManager.default
        func has(_ file: String) -> Bool { fm.fileExists(atPath: folder.appendingPathComponent(file).path) }
        if has("pnpm-lock.yaml") { return "pnpm" }
        if has("yarn.lock") { return "yarn" }
        if has("bun.lock") || has("bun.lockb") { return "bun" }
        return "npm"
    }

    private static func scriptOrder(_ a: String, _ b: String) -> Bool {
        let ia = preferredOrder.firstIndex(of: a) ?? Int.max
        let ib = preferredOrder.firstIndex(of: b) ?? Int.max
        return ia != ib ? ia < ib : a < b
    }
}
