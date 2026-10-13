import Testing
@testable import AmpersandCore

@Test func basicPairsCommentsAndBlanks() {
    let r = EnvParser.parse("PORT=3000\n\n# comment\nNODE_ENV=development\n")
    #expect(r.values == ["PORT": "3000", "NODE_ENV": "development"])
    #expect(r.errors.isEmpty)
}

@Test func quotedValues() {
    let r = EnvParser.parse(#"""
    A="a b"
    B='c $HOME d'
    C="line\nbreak \"q\""
    D=plain # trailing comment
    E=
    """#)
    #expect(r.values["A"] == "a b")
    #expect(r.values["B"] == "c $HOME d")
    #expect(r.values["C"] == "line\nbreak \"q\"")
    #expect(r.values["D"] == "plain")
    #expect(r.values["E"] == "")
}

@Test func exportPrefixAndWhitespace() {
    let r = EnvParser.parse("  export   KEY = value  ")
    #expect(r.values == ["KEY": "value"])
}

@Test func laterKeysOverride() {
    #expect(EnvParser.parse("A=1\nA=2").values == ["A": "2"])
}

@Test func errorsCarryLineNumbers() {
    let r = EnvParser.parse("OK=1\nnot a pair\n1BAD=x\nQ=\"unterminated")
    #expect(r.values == ["OK": "1"])
    #expect(r.errors.map(\.line) == [2, 3, 4])
    #expect(r.errors[0].message == "Expected KEY=value")
    #expect(r.errors[1].message == "Invalid variable name \"1BAD\"")
    #expect(r.errors[2].message == "Missing closing quote")
}

@Test func pairsKeepOrderAndLastWins() {
    let pairs = EnvParser.parsePairs("B=2\n# note\nA=1\nB=3")
    #expect(pairs.map(\.key) == ["B", "A"])
    #expect(pairs.map(\.value) == ["3", "1"])
}

@Test func serializeRoundTripsAwkwardValues() {
    let pairs: [EnvParser.Pair] = [
        .init(key: "PLAIN", value: "abc"),
        .init(key: "SPACES", value: "a b"),
        .init(key: "HASH", value: "x #y"),
        .init(key: "QUOTES", value: #"say "hi""#),
        .init(key: "NEWLINE", value: "l1\nl2"),
        .init(key: "EMPTY", value: ""),
    ]
    let text = EnvParser.serialize(pairs)
    #expect(text.hasPrefix("PLAIN=abc\nSPACES=\"a b\""))
    #expect(EnvParser.parsePairs(text) == pairs)
    #expect(EnvParser.parse(text).errors.isEmpty)
}
