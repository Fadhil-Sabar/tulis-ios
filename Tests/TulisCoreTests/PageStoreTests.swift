import Foundation
import Testing
@testable import TulisCore

@Suite struct PageStoreTests {
    private func makeTemporaryRepo() throws -> (NotebookRepository, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TulisTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let repo = NotebookRepository(rootURL: tempDir)
        return (repo, tempDir)
    }

    @Test func binaryPageStoreMenulisPageBinV2() throws {
        let (repo, tempDir) = try makeTemporaryRepo()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let notebook = try repo.create(title: "Buku Catatan", mode: .infinite)
        let store = BinaryPageStore(repository: repo)

        let initialContent = try store.load(notebookId: notebook.id, pageIndex: 0)
        #expect(initialContent == nil)

        let points = [
            StrokePoint(x: 10, y: 20, elapsedTimeMillis: 100, pressure: 0.5, tiltRadians: 0.1, orientationRadians: 0.2),
            StrokePoint(x: 30, y: 40, elapsedTimeMillis: 200, pressure: 0.8, tiltRadians: 0.2, orientationRadians: 0.3)
        ]
        let stroke1 = Stroke(
            brushKind: .highlighter,
            colorArgb: -256,
            sizePx: 18.0,
            strokeToWorld: AffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 5, ty: 10),
            toolType: .stylus,
            strokeUnitLengthCm: StrokeConstants.noStrokeUnitLength,
            points: points
        )
        let stroke2 = Stroke(
            brushKind: .pen,
            colorArgb: -16777216,
            sizePx: 4.0,
            strokeToWorld: .identity,
            toolType: .touch,
            strokeUnitLengthCm: StrokeConstants.noStrokeUnitLength,
            points: [
                StrokePoint(x: 50, y: 60, elapsedTimeMillis: 300, pressure: 0.6)
            ]
        )
        let text1 = TextItem(x: 100, y: 150, sizeWorld: 24, colorArgb: -16777216, widthWorld: 200, text: "Halo dunia")

        let originalContent = PageContent(strokes: [stroke1, stroke2], texts: [text1])

        try store.save(notebookId: notebook.id, pageIndex: 0, content: originalContent)

        let binFile = repo.pageFile(id: notebook.id, index: 0)
        let raw = try Data(contentsOf: binFile)
        #expect(PageCodec.pageVersion(raw) == 2)
        #expect(try store.load(notebookId: notebook.id, pageIndex: 0) == originalContent)
    }

    @Test func halamanTakTerbacaMelemparErrorBukanKosong() throws {
        let (repo, tempDir) = try makeTemporaryRepo()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let notebook = try repo.create(title: "Lama", mode: .infinite)
        try repo.writePage(id: notebook.id, index: 0, data: Data([0x49, 0x4E, 0x4B, 0x50, 0x01, 0, 0, 0, 0]))
        let store = BinaryPageStore(repository: repo)
        #expect(throws: PageCodecError.unsupportedV1) {
            try store.load(notebookId: notebook.id, pageIndex: 0)
        }
    }
}
