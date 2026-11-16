import Testing
@testable import TulisCore

@Test func ordinalSamaDenganAndroid() {
    #expect(BrushKind.pen.rawValue == 0)
    #expect(BrushKind.marker.rawValue == 1)
    #expect(BrushKind.highlighter.rawValue == 2)
    #expect(NoteMode.allCases.count == 2)
    #expect(PaperStyle.lines.rawValue == 3)
    #expect(PageOrientation.landscape.rawValue == 1)
}
