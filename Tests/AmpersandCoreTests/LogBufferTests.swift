import Testing
@testable import AmpersandCore

private func bytes(_ s: String) -> [UInt8] { Array(s.utf8) }

@Test func commitsLinesOnNewline() {
    var b = LogBuffer()
    #expect(b.append(bytes("one\ntwo\nthr")) == ["one", "two"])
    #expect(b.partialLine == "thr")
    #expect(b.append(bytes("ee\n")) == ["three"])
    #expect(b.lines == ["one", "two", "three"])
    #expect(b.totalCommitted == 3)
}

@Test func crlfIsOneNewline() {
    var b = LogBuffer()
    _ = b.append(bytes("a\r"))
    _ = b.append(bytes("\nb\r\n"))
    #expect(b.lines == ["a", "b"])
}

@Test func carriageReturnOverwrites() {
    var b = LogBuffer()
    _ = b.append(bytes("progress 10%\rprogress 50%\rprogress 100%\ndone\n"))
    #expect(b.lines == ["progress 100%", "done"])
}

@Test func partialLineIsHeld() {
    var b = LogBuffer()
    _ = b.append(bytes("no newline yet"))
    #expect(b.lines.isEmpty)
    #expect(b.tail(5) == ["no newline yet"])
}

@Test func splitUTF8IsReassembled() {
    var b = LogBuffer()
    let euro = Array("€\n".utf8)          // E2 82 AC 0A
    _ = b.append(Array(euro[0..<2]))
    _ = b.append(Array(euro[2...]))
    #expect(b.lines == ["€"])
}

@Test func ringDropsOldest() {
    var b = LogBuffer(capacity: 3)
    _ = b.append(bytes("1\n2\n3\n4\n5\n"))
    #expect(b.lines == ["3", "4", "5"])
    #expect(b.totalCommitted == 5)
}

@Test func tailAndClear() {
    var b = LogBuffer()
    _ = b.append(bytes("a\nb\nc\n"))
    #expect(b.tail(2) == ["b", "c"])
    b.clear()
    #expect(b.lines.isEmpty && b.partialLine.isEmpty)
}

@Test func invalidUTF8IsReplaced() {
    var b = LogBuffer()
    _ = b.append([0x61, 0xFF, 0x62, 0x0A])
    #expect(b.lines == ["a\u{FFFD}b"])
}
