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
    public static func parse(_ text: String) -> EnvParseResult {
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
            case .success(let value): result.values[key] = value
            case .failure(let message): result.errors.append(.init(line: lineNumber, message: message))
            }
        }
        return result
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
