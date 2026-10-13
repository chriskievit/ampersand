import Foundation

/// Bounded line buffer fed with raw pty bytes.
public struct LogBuffer: Sendable {
    public let capacity: Int
    public private(set) var lines: [String] = []
    public private(set) var partialLine = ""
    public private(set) var totalCommitted = 0

    private var pendingBytes: [UInt8] = []   // current line's undecoded bytes
    private var pendingCR = false

    public init(capacity: Int = 10_000) { self.capacity = capacity }

    public mutating func append(_ bytes: [UInt8]) -> [String] {
        var committed: [String] = []
        for byte in bytes {
            if pendingCR {
                pendingCR = false
                if byte == 0x0A { committed.append(commitLine()); continue }
                pendingBytes.removeAll(keepingCapacity: true)   // lone \r: overwrite
            }
            switch byte {
            case 0x0A: committed.append(commitLine())
            case 0x0D: pendingCR = true
            default: pendingBytes.append(byte)
            }
        }
        partialLine = Self.decode(pendingBytes, dropIncompleteTail: true)
        if lines.count > capacity { lines.removeFirst(lines.count - capacity) }
        return committed
    }

    public func tail(_ n: Int) -> [String] {
        var out = Array(lines.suffix(partialLine.isEmpty ? n : max(n - 1, 0)))
        if !partialLine.isEmpty { out.append(partialLine) }
        return out
    }

    public mutating func clear() {
        lines.removeAll()
        partialLine = ""
        pendingBytes.removeAll()
        pendingCR = false
    }

    private mutating func commitLine() -> String {
        let line = Self.decode(pendingBytes, dropIncompleteTail: false)
        pendingBytes.removeAll(keepingCapacity: true)
        lines.append(line)
        totalCommitted += 1
        return line
    }

    /// Decodes UTF-8, replacing invalid bytes. When `dropIncompleteTail` is true a
    /// truncated multi-byte sequence at the end is left out (it may complete later).
    private static func decode(_ bytes: [UInt8], dropIncompleteTail: Bool) -> String {
        var slice = bytes[...]
        if dropIncompleteTail {
            var back = 0
            for b in bytes.reversed().prefix(3) {
                back += 1
                if b & 0xC0 == 0xC0 {   // lead byte
                    let needed = b >= 0xF0 ? 4 : b >= 0xE0 ? 3 : 2
                    if needed > back { slice = bytes[..<(bytes.count - back)] }
                    break
                }
                if b & 0xC0 != 0x80 { break }   // ASCII: nothing pending
            }
        }
        return String(decoding: slice, as: UTF8.self)
    }
}
