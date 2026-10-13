import Foundation

public enum ANSIColor: Sendable, Hashable {
    case standard(Int)
    case palette(Int)
    case rgb(UInt8, UInt8, UInt8)
}

public struct ANSIStyle: Sendable, Hashable {
    public var foreground: ANSIColor?
    public var background: ANSIColor?
    public var bold = false
    public var dim = false
    public var italic = false
    public var underline = false
    public static let plain = ANSIStyle()
    public init() {}
}

public struct StyledRun: Sendable, Equatable {
    public var text: String
    public var style: ANSIStyle
    public init(text: String, style: ANSIStyle) { self.text = text; self.style = style }
}

/// Converts SGR escape sequences to styled runs and strips every other escape.
public struct ANSIParser: Sendable {
    private var style = ANSIStyle.plain

    public init() {}

    public mutating func parse(_ line: String) -> [StyledRun] {
        var runs: [StyledRun] = []
        var text = ""
        let scalars = Array(line.unicodeScalars)
        var i = 0

        func flush() {
            guard !text.isEmpty else { return }
            if let last = runs.last, last.style == style {
                runs[runs.count - 1].text += text
            } else {
                runs.append(StyledRun(text: text, style: style))
            }
            text = ""
        }

        while i < scalars.count {
            let c = scalars[i]
            guard c == "\u{1B}" else {
                if c.value >= 0x20 || c == "\t" { text.unicodeScalars.append(c) }
                i += 1
                continue
            }
            guard i + 1 < scalars.count else { i += 1; continue }
            let kind = scalars[i + 1]
            if kind == "[" {
                var j = i + 2
                var params = ""
                while j < scalars.count, !(0x40...0x7E).contains(scalars[j].value) {
                    params.unicodeScalars.append(scalars[j]); j += 1
                }
                if j < scalars.count, scalars[j] == "m" {
                    flush()
                    applySGR(params)
                }
                i = j + 1
            } else if kind == "]" {
                var j = i + 2
                while j < scalars.count {
                    if scalars[j] == "\u{07}" { j += 1; break }
                    if scalars[j] == "\u{1B}", j + 1 < scalars.count, scalars[j + 1] == "\\" { j += 2; break }
                    j += 1
                }
                i = j
            } else if kind == "(" || kind == ")" {
                i += 3
            } else {
                i += 2
            }
        }
        flush()
        return runs
    }

    private mutating func applySGR(_ params: String) {
        let codes = params.isEmpty ? [0] : params.split(separator: ";", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
        var k = 0
        while k < codes.count {
            let code = codes[k]
            switch code {
            case 0: style = .plain
            case 1: style.bold = true
            case 2: style.dim = true
            case 3: style.italic = true
            case 4: style.underline = true
            case 22: style.bold = false; style.dim = false
            case 23: style.italic = false
            case 24: style.underline = false
            case 30...37: style.foreground = .standard(code - 30)
            case 39: style.foreground = nil
            case 40...47: style.background = .standard(code - 40)
            case 49: style.background = nil
            case 90...97: style.foreground = .standard(code - 90 + 8)
            case 100...107: style.background = .standard(code - 100 + 8)
            case 38, 48:
                var color: ANSIColor?
                if k + 2 < codes.count, codes[k + 1] == 5 {
                    color = .palette(codes[k + 2]); k += 2
                } else if k + 4 < codes.count, codes[k + 1] == 2 {
                    color = .rgb(UInt8(clamping: codes[k + 2]), UInt8(clamping: codes[k + 3]), UInt8(clamping: codes[k + 4])); k += 4
                }
                if code == 38 { style.foreground = color } else { style.background = color }
            default: break
            }
            k += 1
        }
    }
}
