import Foundation
import Testing
@testable import TulisCore

struct NotebookRepositoryTests {
    private func makeTemporaryRepo() throws -> (NotebookRepository, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tulis-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let repo = NotebookRepository(rootURL: tempDir)
        return (repo, tempDir)
    }

    @Test func crudDiDirektoriSementara() throws {
        let (repo, tempDir) = try makeTemporaryRepo()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let meta = try repo.create(
            title: "Catatan Kuliah",
            mode: .infinite,
            orientation: .landscape,
            paperStyle: .grid,
            paperSpacing: 32.0
        )

        #expect(meta.title == "Catatan Kuliah")
        #expect(meta.mode == .infinite)
        #expect(meta.orientation == .landscape)
        #expect(meta.paperStyle == .grid)
        #expect(meta.paperSpacing == 32.0)
        #expect(meta.pageCount == 1)

        let readMeta = repo.readMeta(id: meta.id)
        #expect(readMeta == meta)

        let renamed = try repo.rename(id: meta.id, title: "Catatan Fisika")
        #expect(renamed)
        #expect(repo.readMeta(id: meta.id)?.title == "Catatan Fisika")

        let defaultMeta = try repo.create(title: "", mode: .paged)
        #expect(defaultMeta.title.starts(with: "Catatan "))
        #expect(defaultMeta.mode == .paged)
        #expect(defaultMeta.paperStyle == .plain)

        try repo.softDelete(id: meta.id)
        #expect(repo.readMeta(id: meta.id) == nil)
        #expect(repo.trashCount() == 1)
        let trash = repo.listTrash()
        #expect(trash.count == 1)
        #expect(trash.first?.meta.id == meta.id)

        try repo.restore(id: meta.id)
        #expect(repo.readMeta(id: meta.id)?.title == "Catatan Fisika")
        #expect(repo.trashCount() == 0)

        try repo.delete(id: meta.id)
        #expect(repo.readMeta(id: meta.id) == nil)
    }

    @Test func listMelewatiTrashDanMetaRusakDanUrutUpdatedAt() throws {
        let (repo, tempDir) = try makeTemporaryRepo()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var meta1 = try repo.create(title: "Note 1", mode: .infinite)
        meta1.updatedAt = 1000
        try repo.writeMeta(meta: meta1)

        var meta2 = try repo.create(title: "Note 2", mode: .paged)
        meta2.updatedAt = 3000
        try repo.writeMeta(meta: meta2)

        var meta3 = try repo.create(title: "Note 3", mode: .infinite)
        meta3.updatedAt = 2000
        try repo.writeMeta(meta: meta3)

        try repo.softDelete(id: meta1.id)

        let corruptDir = repo.notebookDir(id: "corrupt-note")
        try FileManager.default.createDirectory(at: corruptDir, withIntermediateDirectories: true)
        let corruptMeta = corruptDir.appendingPathComponent("meta.json", isDirectory: false)
        try "{ bukan json valid }".write(to: corruptMeta, atomically: true, encoding: .utf8)

        let emptyDir = repo.notebookDir(id: "empty-note")
        try FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)

        let list = repo.list()
        #expect(list.count == 2)
        #expect(list[0].id == meta2.id)
        #expect(list[1].id == meta3.id)
    }

    @Test func folderYatimDanSiklusDibersihkan() throws {
        let (repo, tempDir) = try makeTemporaryRepo()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let rawFolders = [
            Folder(id: "root", name: "Root", parentId: nil, createdAt: 100),
            Folder(id: "child", name: "Child", parentId: "root", createdAt: 200),
            Folder(id: "orphan", name: "Orphan", parentId: "missing_parent", createdAt: 300),
            Folder(id: "cycle1", name: "Cycle 1", parentId: "cycle2", createdAt: 400),
            Folder(id: "cycle2", name: "Cycle 2", parentId: "cycle1", createdAt: 500),
            Folder(id: "self_loop", name: "Self Loop", parentId: "self_loop", createdAt: 600)
        ]

        let container = FoldersContainer(v: 1, folders: rawFolders)
        let data = try JSONEncoder().encode(container)
        try repo.atomicWrite(to: repo.foldersFile, data: data)

        let cleaned = repo.listFolders()
        let byId = Dictionary(uniqueKeysWithValues: cleaned.map { ($0.id, $0) })

        #expect(byId["root"]?.parentId == nil)
        #expect(byId["child"]?.parentId == "root")
        #expect(byId["orphan"]?.parentId == nil)
        #expect(byId["self_loop"]?.parentId == nil)

        let c1Parent = byId["cycle1"]?.parentId
        let c2Parent = byId["cycle2"]?.parentId
        #expect(c1Parent == nil || c2Parent == nil)
    }

    @Test func foldersJsonKorupDiRename() throws {
        let (repo, tempDir) = try makeTemporaryRepo()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let corruptContent = "{ ini file folders rusak : tidak bisa diparse"
        try FileManager.default.createDirectory(at: repo.notebooksDir, withIntermediateDirectories: true)
        try corruptContent.write(to: repo.foldersFile, atomically: true, encoding: .utf8)

        #expect(FileManager.default.fileExists(atPath: repo.foldersFile.path))

        let folders = repo.listFolders()
        #expect(folders.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: repo.foldersFile.path))
        #expect(FileManager.default.fileExists(atPath: repo.corruptFoldersFile.path))

        let savedCorrupt = try String(contentsOf: repo.corruptFoldersFile, encoding: .utf8)
        #expect(savedCorrupt == corruptContent)
    }

    @Test func tulisAtomikTidakMeninggalkanFileSementara() throws {
        let (repo, tempDir) = try makeTemporaryRepo()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let target = repo.notebooksDir.appendingPathComponent("atomic_test.txt")
        let data1 = Data("Versi 1".utf8)
        let data2 = Data("Versi 2 Baru".utf8)

        try repo.atomicWrite(to: target, data: data1)
        #expect(FileManager.default.fileExists(atPath: target.path))
        let tmpFile = repo.notebooksDir.appendingPathComponent("atomic_test.txt.tmp")
        #expect(!FileManager.default.fileExists(atPath: tmpFile.path))

        try repo.atomicWrite(to: target, data: data2)
        #expect(FileManager.default.fileExists(atPath: target.path))
        #expect(!FileManager.default.fileExists(atPath: tmpFile.path))

        let read = try Data(contentsOf: target)
        #expect(read == data2)
    }

    @Test func writePageLaluReadPageSamaDanThumbnail() throws {
        let (repo, tempDir) = try makeTemporaryRepo()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let meta = try repo.create(title: "Pages Test", mode: .paged)
        let page0 = Data([0x01, 0x02, 0x03, 0x04, 0xAA, 0xBB])
        let page1 = Data([0xDE, 0xAD, 0xBE, 0xEF])

        try repo.writePage(id: meta.id, index: 0, data: page0)
        try repo.writePage(id: meta.id, index: 1, data: page1)

        #expect(repo.readPage(id: meta.id, index: 0) == page0)
        #expect(repo.readPage(id: meta.id, index: 1) == page1)
        #expect(repo.readPage(id: meta.id, index: 2) == nil)

        let thumbData = Data([0x89, 0x50, 0x4E, 0x47])
        try repo.writeThumb(id: meta.id, data: thumbData)
        #expect(repo.readThumb(id: meta.id) == thumbData)
        #expect(repo.thumbFile(id: meta.id).lastPathComponent == "thumb.png")

        let page1Thumb = Data([0x10, 0x20, 0x30])
        try repo.writePageThumb(id: meta.id, index: 1, data: page1Thumb)
        #expect(repo.readPageThumb(id: meta.id, index: 1) == page1Thumb)
        #expect(repo.pageThumbFile(id: meta.id, index: 1).lastPathComponent == "thumb_1.png")
    }

    @Test func operasiFolderDanMoveNotebook() throws {
        let (repo, tempDir) = try makeTemporaryRepo()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        guard let root = repo.createFolder(name: "Kuliah", parentId: nil) else {
            Issue.record("Gagal membuat root folder")
            return
        }

        guard let sub = repo.createFolder(name: "Semester 1", parentId: root.id) else {
            Issue.record("Gagal membuat sub folder")
            return
        }

        #expect(repo.descendantFolderIds(id: root.id).contains(sub.id))
        let path = repo.folderPath(folderId: sub.id)
        #expect(path.count == 2)
        #expect(path[0].id == root.id)
        #expect(path[1].id == sub.id)

        let renamed = repo.renameFolder(id: sub.id, name: "Semester Ganjil")
        #expect(renamed)
        #expect(repo.listFolders().first(where: { $0.id == sub.id })?.name == "Semester Ganjil")

        let note = try repo.create(title: "Matematika", mode: .paged, folderId: sub.id)
        #expect(repo.readMeta(id: note.id)?.folderId == sub.id)

        try repo.deleteFolder(id: sub.id)
        let noteAfterDeleteSub = repo.readMeta(id: note.id)
        #expect(noteAfterDeleteSub?.folderId == root.id)

        try repo.moveNotebook(id: note.id, folderId: nil)
        #expect(repo.readMeta(id: note.id)?.folderId == nil)
    }

    @Test func excludeFromBackupHelper() throws {
        let (repo, tempDir) = try makeTemporaryRepo()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let cacheURL = tempDir.appendingPathComponent("cache.tmp")
        try Data().write(to: cacheURL)
        try NotebookRepository.setExcludedFromBackup(true, for: cacheURL)
    }
}
