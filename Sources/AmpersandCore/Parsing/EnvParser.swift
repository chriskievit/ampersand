import Foundation

public struct EnvParseError: Sendable, Equatable {
    public let line: Int
    public let message: String
}

public struct EnvParseResult: Sendable, Equatable {
    public var values: [String: String]
    public var errors: [EnvParseError]
}

/// Parses `.env`-style text: `KEY=value`, `export KEY=value`, `#` comments,
/// single quotes (literal), double quotes (supports \n, \t, \", \\).
public enum EnvParser {
    public struct Pair: Sendable, Equatable {
        public var key: String
        public var value: String
        public init(key: String, value: String) { self.key = key; self.value = value }
    }

    public static func parse(_ text: String) -> EnvParseResult {
        let scanned = scan(text)
        var values: [String: String] = [:]
        for pair in scanned.pairs { values[pair.key] = pair.value }
        return EnvParseResult(values: values, errors: scanned.errors)
    }

    /// Variables in file order; a repeated key keeps its first position and its last value.
    public static func parsePairs(_ text: String) -> [Pair] { scan(text).pairs }

    /// Writes variables as `.env` text that `parsePairs` reads back exactly.
    public static func serialize(_ pairs: [Pair]) -> String {
        pairs.map { "\($0.key)=\(quoted($0.value))" }.joined(separator: "\n")
    }

    private static func quoted(_ value: String) -> String {
        let needsQuotes = value.contains { $0.isWhitespace || "#\"'\\".contains($0) }
        guard needsQuotes else { return value }
        var out = "\""
        for ch in value {
            switch ch {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\t": out += "\\t"
            default: out.append(ch)
            }
        }
        return out + "\""
    }

    private static func scan(_ text: String) -> (pairs: [Pair], errors: [EnvParseError]) {
        var pairs: [Pair] = []
        var result = EnvParseResult(values: [:], errors: [])
        for (index, rawLine) in text.components(separatedBy: "\n").enumerated() {
            let lineNumber = index + 1
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("export ") {
                line = String(line.dropFirst("export ".count)).trimmingCharacters(in: .whitespaces)
            }
            guard let eq = line.firstIndex(of: "=") else {
                result.errors.append(.init(line: lineNumber, message: "Expected KEY=value"))
                continue
            }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            guard isValidName(key) else {
                result.errors.append(.init(line: lineNumber, message: "Invalid variable name \"\(key)\""))
                continue
            }
            let rawValue = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            switch parseValue(rawValue) {
            case .success(let value):
                if let i = pairs.firstIndex(where: { $0.key == key }) { pairs[i].value = value }
                else { pairs.append(Pair(key: key, value: value)) }
            case .failure(let message): result.errors.append(.init(line: lineNumber, message: message))
            }
        }
        return (pairs, result.errors)
    }

    private enum ValueResult { case success(String), failure(String) }

    private static func isValidName(_ name: String) -> Bool {
        guard let first = name.unicodeScalars.first,
              first == "_" || CharacterSet.letters.contains(first), first.isASCII else { return false }
        return name.unicodeScalars.allSatisfy {
            $0.isASCII && ($0 == "_" || CharacterSet.alphanumerics.contains($0))
        }
    }

    private static func parseValue(_ raw: String) -> ValueResult {
        if raw.hasPrefix("'") {
            let body = raw.dropFirst()
            guard let close = body.firstIndex(of: "'") else { return .failure("Missing closing quote") }
            return .success(String(body[..<close]))
        }
        if raw.hasPrefix("\"") {
            var out = ""
            var escaped = false
            for ch in raw.dropFirst() {
                if escaped {
                    switch ch {
                    case "n": out.append("\n")
                    case "t": out.append("\t")
                    default: out.append(ch)
                    }
                    escaped = false
                } else if ch == "\\" {
                    escaped = true
                } else if ch == "\"" {
                    return .success(out)
                } else {
                    out.append(ch)
                }
            }
            return .failure("Missing closing quote")
        }
        if let hash = raw.range(of: " #") {
            return .success(raw[..<hash.lowerBound].trimmingCharacters(in: .whitespaces))
        }
        return .success(raw)
    }
}
