import Testing
@testable import AmpersandCore

private let esc = "\u{1B}"

@Test func plainText() {
    var p = ANSIParser()
    #expect(p.parse("hello") == [StyledRun(text: "hello", style: .plain)])
}

@Test func basicColoursAndReset() {
    var p = ANSIParser()
    let runs = p.parse("\(esc)[32mok\(esc)[0m done")
    var green = ANSIStyle.plain; green.foreground = .standard(2)
    #expect(runs == [StyledRun(text: "ok", style: green), StyledRun(text: " done", style: .plain)])
}

@Test func brightBoldAndCombined() {
    var p = ANSIParser()
    let runs = p.parse("\(esc)[1;91mERR\(esc)[22;39m x")
    var style = ANSIStyle.plain; style.bold = true; style.foreground = .standard(9)
    #expect(runs == [StyledRun(text: "ERR", style: style), StyledRun(text: " x", style: .plain)])
}

@Test func paletteAndTruecolor() {
    var p = ANSIParser()
    let runs = p.parse("\(esc)[38;5;208ma\(esc)[48;2;10;20;30mb")
    #expect(runs[0].style.foreground == .palette(208))
    #expect(runs[1].style.background == .rgb(10, 20, 30))
    #expect(runs[1].style.foreground == .palette(208))
}

@Test func styleCarriesAcrossLines() {
    var p = ANSIParser()
    _ = p.parse("\(esc)[33mstart")
    #expect(p.parse("next").first?.style.foreground == .standard(3))
}

@Test func stripsOtherEscapes() {
    var p = ANSIParser()
    let runs = p.parse("\(esc)[2K\(esc)[1Gline\(esc)]0;title\u{07}!\(esc)(B")
    #expect(runs == [StyledRun(text: "line!", style: .plain)])
}

@Test func emptyParamsMeanReset() {
    var p = ANSIParser()
    _ = p.parse("\(esc)[4m")
    #expect(p.parse("\(esc)[mx") == [StyledRun(text: "x", style: .plain)])
}
