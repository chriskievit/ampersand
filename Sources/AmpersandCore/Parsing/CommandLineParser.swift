import Foundation

public struct CommandSuggestions: Sendable, Equatable {
    public var command: String
    public var cwd: String?
    public var envLines: [String]
    public var port: Int?
    public var name: String?
    public var health: HealthCheck?

    public init(command: String, cwd: String?, envLines: [String], port: Int?, name: String?, health: HealthCheck?) {
        self.command = command; self.cwd = cwd; self.envLines = envLines
        self.port = port; self.name = name; self.health = health
    }
}

/// Extracts editable suggestions from a pasted shell command line. Detection only:
/// the returned `command` is the user's text minus the recognised prefixes.
public enum CommandLineParser {
    public static func parse(_ input: String) -> CommandSuggestions {
        var rest = Substring(input.trimmingCharacters(in: .whitespacesAndNewlines))
        var result = CommandSuggestions(command: "", cwd: nil, envLines: [], port: nil, name: nil, health: nil)

        // cd <path> &&
        if let (word, after) = scanWord(rest), word.unquoted == "cd",
           let (path, afterPath) = scanWord(after) {
            let tail = afterPath.drop(while: \.isWhitespace)
            if tail.hasPrefix("&&") {
                result.cwd = path.unquoted
                rest = tail.dropFirst(2).drop(while: \.isWhitespace)
            }
        }

        // KEY=value prefixes
        while let (word, after) = scanWord(rest), isAssignment(word.raw) {
            result.envLines.append(word.raw)
            let eq = word.unquoted.firstIndex(of: "=")!
            if word.unquoted[..<eq] == "PORT" {
                result.port = Int(word.unquoted[word.unquoted.index(after: eq)...])
            }
            rest = after.drop(while: \.isWhitespace)
        }

        result.command = String(rest)
        let tokens = tokenize(rest)
        guard let program = tokens.first else { return result }
        let programName = (program as NSString).lastPathComponent

        if programName == "kubectl", let pf = tokens.firstIndex(of: "port-forward") {
            result.health = .tcp
            let args = Array(tokens[(pf + 1)...])
            var i = 0
            var positionals: [String] = []
            while i < args.count {
                let a = args[i]
                if a.hasPrefix("-") {
                    // flags that take a separate value
                    if ["-n", "--namespace", "--address", "--context", "--pod-running-timeout"].contains(a) { i += 1 }
                } else {
                    positionals.append(a)
                }
                i += 1
            }
            if let resource = positionals.first {
                result.name = resource.split(separator: "/").last.map(String.init) ?? resource
            }
            if let portSpec = positionals.dropFirst().first,
               let local = Int(portSpec.split(separator: ":").first ?? "") {
                result.port = local
            }
            return result
        }

        for (i, t) in tokens.enumerated() {
            if t == "--port", i + 1 < tokens.count, let p = Int(tokens[i + 1]) { result.port = p }
            if t.hasPrefix("--port="), let p = Int(t.dropFirst("--port=".count)) { result.port = p }
            if t == "-p", tokens.contains("next"), i + 1 < tokens.count, let p = Int(tokens[i + 1]) { result.port = p }
        }

        if ["npm", "pnpm", "yarn", "bun"].contains(programName), tokens.count > 1 {
            result.name = tokens[1] == "run" && tokens.count > 2 ? tokens[2] : tokens[1]
        } else {
            result.name = programName
        }
        return result
    }

    // MARK: - Shell-ish scanning

    struct Word { let raw: String; let unquoted: String }

    /// Reads one shell word from the start of `text` (after leading spaces).
    static func scanWord(_ text: Substring) -> (Word, Substring)? {
        let s = text.drop(while: \.isWhitespace)
        guard !s.isEmpty else { return nil }
        var unquoted = ""
        var quote: Character? = nil
        var idx = s.startIndex
        while idx < s.endIndex {
            let ch = s[idx]
            if let q = quote {
                if ch == q { quote = nil } else { unquoted.append(ch) }
            } else if ch == "\"" || ch == "'" {
                quote = ch
            } else if ch == "\\", s.index(after: idx) < s.endIndex {
                idx = s.index(after: idx)
                unquoted.append(s[idx])
            } else if ch.isWhitespace {
                break
            } else {
                unquoted.append(ch)
            }
            idx = s.index(after: idx)
        }
        return (Word(raw: String(s[s.startIndex..<idx]), unquoted: unquoted), s[idx...])
    }

    static func tokenize(_ text: Substring) -> [String] {
        var tokens: [String] = []
        var rest = text
        while let (word, after) = scanWord(rest) {
            tokens.append(word.unquoted)
            rest = after
        }
        return tokens
    }

    private static func isAssignment(_ raw: String) -> Bool {
        guard let eq = raw.firstIndex(of: "="), eq != raw.startIndex else { return false }
        let name = raw[..<eq]
        guard let first = name.first, first == "_" || first.isLetter else { return false }
        return name.allSatisfy { $0 == "_" || $0.isLetter || $0.isNumber }
    }
}
