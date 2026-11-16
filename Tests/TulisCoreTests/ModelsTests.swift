import Foundation
import Testing
@testable import TulisCore

@Test func ordinalSamaDenganAndroid() {
    #expect(BrushKind.pen.rawValue == 0)
    #expect(BrushKind.marker.rawValue == 1)
    #expect(BrushKind.highlighter.rawValue == 2)
    #expect(NoteMode.infinite.rawValue == 0)
    #expect(NoteMode.paged.rawValue == 1)
    #expect(NoteMode.allCases.count == 2)
    #expect(PaperStyle.plain.rawValue == 0)
    #expect(PaperStyle.dots.rawValue == 1)
    #expect(PaperStyle.grid.rawValue == 2)
    #expect(PaperStyle.lines.rawValue == 3)
    #expect(PageOrientation.portrait.rawValue == 0)
    #expect(PageOrientation.landscape.rawValue == 1)
    #expect(Tool.pen.rawValue == 0)
    #expect(Tool.shape.rawValue == 6)
}

@Test func enumJsonName() {
    #expect(NoteMode.infinite.jsonName == "INFINITE")
    #expect(NoteMode.paged.jsonName == "PAGED")
    #expect(PaperStyle.plain.jsonName == "PLAIN")
    #expect(PaperStyle.dots.jsonName == "DOTS")
    #expect(PaperStyle.grid.jsonName == "GRID")
    #expect(PaperStyle.lines.jsonName == "LINES")
    #expect(PageOrientation.portrait.jsonName == "PORTRAIT")
    #expect(PageOrientation.landscape.jsonName == "LANDSCAPE")
    #expect(BrushKind.pen.jsonName == "PEN")
    #expect(BrushKind.marker.jsonName == "MARKER")
    #expect(BrushKind.highlighter.jsonName == "HIGHLIGHTER")
    #expect(Tool.eraser.jsonName == "ERASER")

    #expect(NoteMode(jsonName: "infinite") == nil)
    #expect(PaperStyle(jsonName: "dots") == nil)
    #expect(PageOrientation(jsonName: "landscape") == nil)
}

@Test func ukuranHalamanWorld() {
    #expect(PageOrientation.portrait.pageW == 1000)
    #expect(PageOrientation.portrait.pageH == 1414)
    #expect(PageOrientation.landscape.pageW == 1414)
    #expect(PageOrientation.landscape.pageH == 1000)
}

@Test func decodeDanEncodeUlangMetaAndroid() throws {
    let androidJson = """
    {
      "id": "e4b47da9-8a8b-4c07-bca9-59ebdf4dfaa8",
      "title": "Catatan Kuliah",
      "mode": "INFINITE",
      "pageCount": 5,
      "updatedAt": 1716000000000,
      "lastPage": 2,
      "paper": "DOTS",
      "paperSpacing": 35.0,
      "orientation": "PORTRAIT",
      "folderId": "folder-f2",
      "vp": [1.5, 120.0, -80.0]
    }
    """

    guard let meta = NotebookMeta.parse(json: androidJson) else {
        Issue.record("Gagal decode meta.json Android")
        return
    }

    #expect(meta.id == "e4b47da9-8a8b-4c07-bca9-59ebdf4dfaa8")
    #expect(meta.title == "Catatan Kuliah")
    #expect(meta.mode == .infinite)
    #expect(meta.pageCount == 5)
    #expect(meta.updatedAt == 1716000000000)
    #expect(meta.lastPage == 2)
    #expect(meta.paperStyle == .dots)
    #expect(meta.paperSpacing == 35.0)
    #expect(meta.orientation == .portrait)
    #expect(meta.folderId == "folder-f2")
    #expect(meta.vpScale == 1.5)
    #expect(meta.vpTx == 120.0)
    #expect(meta.vpTy == -80.0)

    let encodedData = try meta.serialize()
    let reDecoded = try JSONDecoder().decode(NotebookMeta.self, from: encodedData)
    #expect(reDecoded == meta)

    let jsonObject = try JSONSerialization.jsonObject(with: encodedData) as? [String: Any]
    #expect(jsonObject?["paper"] as? String == "DOTS")
    #expect(jsonObject?["mode"] as? String == "INFINITE")
    #expect(jsonObject?["orientation"] as? String == "PORTRAIT")
    #expect(jsonObject?["folderId"] as? String == "folder-f2")
    if let vp = jsonObject?["vp"] as? [NSNumber] {
        #expect(vp.count == 3)
        #expect(vp[0].floatValue == 1.5)
        #expect(vp[1].floatValue == 120.0)
        #expect(vp[2].floatValue == -80.0)
    } else {
        Issue.record("Key vp tidak valid di hasil encode")
    }
}

@Test func decodeDanEncodeUlangMetaPagedTanpaFolder() throws {
    let androidJson = """
    {
      "id": "7fa12345-6789-4abc-def0-123456789abc",
      "title": "Sketsa Desain",
      "mode": "PAGED",
      "pageCount": 12,
      "updatedAt": 1716100000000,
      "lastPage": 0,
      "paper": "GRID",
      "paperSpacing": 28.0,
      "orientation": "LANDSCAPE",
      "vp": [1.0, 0.0, 0.0]
    }
    """

    guard let meta = NotebookMeta.parse(json: androidJson) else {
        Issue.record("Gagal decode meta.json PAGED")
        return
    }

    #expect(meta.mode == .paged)
    #expect(meta.paperStyle == .grid)
    #expect(meta.orientation == .landscape)
    #expect(meta.folderId == nil)

    let encodedData = try meta.serialize()
    let reDecoded = try JSONDecoder().decode(NotebookMeta.self, from: encodedData)
    #expect(reDecoded == meta)

    let jsonObject = try JSONSerialization.jsonObject(with: encodedData) as? [String: Any]
    #expect(jsonObject?["folderId"] == nil)
}

@Test func defaultSaatFieldHilang() {
    let infiniteJson = """
    {
      "id": "nb-inf",
      "title": "Minimal Infinite",
      "mode": "INFINITE",
      "pageCount": 1,
      "updatedAt": 1000
    }
    """
    guard let metaInf = NotebookMeta.parse(json: infiniteJson) else {
        Issue.record("Gagal parse minimal infinite")
        return
    }
    #expect(metaInf.lastPage == 0)
    #expect(metaInf.paperStyle == .dots)
    #expect(metaInf.paperSpacing == 28.0)
    #expect(metaInf.orientation == .portrait)
    #expect(metaInf.folderId == nil)
    #expect(metaInf.vpScale == 1.0)
    #expect(metaInf.vpTx == 0.0)
    #expect(metaInf.vpTy == 0.0)

    let pagedJson = """
    {
      "id": "nb-paged",
      "title": "Minimal Paged",
      "mode": "PAGED",
      "pageCount": 2,
      "updatedAt": 2000
    }
    """
    guard let metaPaged = NotebookMeta.parse(json: pagedJson) else {
        Issue.record("Gagal parse minimal paged")
        return
    }
    #expect(metaPaged.paperStyle == .plain)
}

@Test func defaultNilaiTidakValidAtauKosong() {
    let json = """
    {
      "id": "nb-invalid-fields",
      "title": "Catatan",
      "mode": "INFINITE",
      "pageCount": 1,
      "updatedAt": 1000,
      "paper": "grid",
      "orientation": "",
      "folderId": "",
      "vp": [2.0, 5.0]
    }
    """
    guard let meta = NotebookMeta.parse(json: json) else {
        Issue.record("Gagal parse meta dengan field invalid")
        return
    }
    #expect(meta.paperStyle == .dots)
    #expect(meta.orientation == .portrait)
    #expect(meta.folderId == nil)
    #expect(meta.vpScale == 1.0)
    #expect(meta.vpTx == 0.0)
    #expect(meta.vpTy == 0.0)
}

@Test func clampingPaperSpacing() {
    let jsonBawah = """
    {
      "id": "nb-low",
      "title": "Bawah",
      "mode": "INFINITE",
      "pageCount": 1,
      "updatedAt": 1000,
      "paperSpacing": 5.0
    }
    """
    let metaLow = NotebookMeta.parse(json: jsonBawah)
    #expect(metaLow?.paperSpacing == 12.0)

    let jsonAtas = """
    {
      "id": "nb-high",
      "title": "Atas",
      "mode": "INFINITE",
      "pageCount": 1,
      "updatedAt": 1000,
      "paperSpacing": 250.0
    }
    """
    let metaHigh = NotebookMeta.parse(json: jsonAtas)
    #expect(metaHigh?.paperSpacing == 120.0)

    var meta = NotebookMeta(
        id: "nb-mutasi",
        title: "Mutasi",
        mode: .paged,
        pageCount: 1,
        updatedAt: 1000,
        paperSpacing: 10.0
    )
    #expect(meta.paperSpacing == 12.0)
    meta.paperSpacing = 200.0
    #expect(meta.paperSpacing == 120.0)
    meta.paperSpacing = 50.0
    #expect(meta.paperSpacing == 50.0)
}

@Test func folderCodableParentKosongJadiNil() throws {
    let json = """
    {
      "v": 1,
      "folders": [
        {"id": "f1", "name": "Kuliah", "parentId": null, "createdAt": 1000},
        {"id": "f2", "name": "Fisika", "parentId": "f1", "createdAt": 2000},
        {"id": "f3", "name": "Root Kosong", "parentId": "", "createdAt": 3000}
      ]
    }
    """
    let container = try JSONDecoder().decode(FoldersContainer.self, from: json.data(using: .utf8)!)
    #expect(container.v == 1)
    #expect(container.folders.count == 3)
    #expect(container.folders[0].parentId == nil)
    #expect(container.folders[1].parentId == "f1")
    #expect(container.folders[2].parentId == nil)

    let encoded = try JSONEncoder().encode(container)
    let reDecoded = try JSONDecoder().decode(FoldersContainer.self, from: encoded)
    #expect(reDecoded == container)
}

@Test func textItemBoundsDanLines() {
    let item = TextItem(
        x: 100,
        y: 200,
        sizeWorld: 20,
        colorArgb: 0x11223344,
        widthWorld: 300,
        text: "Satu\nDua\nTiga"
    )
    #expect(item.lineCount == 3)
    #expect(item.lineHeight == 26)
    #expect(item.heightWorld == 78)
    let bounds = item.worldBounds
    #expect(bounds.left == 100)
    #expect(bounds.top == 200)
    #expect(bounds.right == 400)
    #expect(bounds.bottom == 278)
}
