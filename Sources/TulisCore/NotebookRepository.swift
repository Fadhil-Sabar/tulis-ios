import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

private func posixRename(_ from: String, _ to: String) -> Int32 {
    rename(from, to)
}

public struct TrashedNotebook: Equatable, Sendable {
    public var meta: NotebookMeta
    public var deletedAt: Int64

    public init(meta: NotebookMeta, deletedAt: Int64) {
        self.meta = meta
        self.deletedAt = deletedAt
    }
}

public enum NotebookRepositoryError: Error, Equatable, Sendable {
    case fileWriteFailed(String)
    case notFound(String)
}

public final class NotebookRepository: @unchecked Sendable {
    public let rootURL: URL
    private let lock = NSRecursiveLock()

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    public var notebooksDir: URL {
        rootURL.appendingPathComponent("notebooks", isDirectory: true)
    }

    public var trashDir: URL {
        notebooksDir.appendingPathComponent(".trash", isDirectory: true)
    }

    public var foldersFile: URL {
        notebooksDir.appendingPathComponent("folders.json", isDirectory: false)
    }

    public var corruptFoldersFile: URL {
        notebooksDir.appendingPathComponent("folders.json.corrupt", isDirectory: false)
    }

    public func notebookDir(id: String) -> URL {
        notebooksDir.appendingPathComponent(id, isDirectory: true)
    }

    public func metaFile(id: String) -> URL {
        notebookDir(id: id).appendingPathComponent("meta.json", isDirectory: false)
    }

    public func pageFile(id: String, index: Int) -> URL {
        notebookDir(id: id).appendingPathComponent("page_\(index).bin", isDirectory: false)
    }

    public func thumbFile(id: String) -> URL {
        notebookDir(id: id).appendingPathComponent("thumb.png", isDirectory: false)
    }

    public func pageThumbFile(id: String, index: Int) -> URL {
        if index == 0 {
            return thumbFile(id: id)
        } else {
            return notebookDir(id: id).appendingPathComponent("thumb_\(index).png", isDirectory: false)
        }
    }

    public func trashNotebookDir(id: String) -> URL {
        trashDir.appendingPathComponent(id, isDirectory: true)
    }

    public func trashMetaFile(id: String) -> URL {
        trashNotebookDir(id: id).appendingPathComponent("meta.json", isDirectory: false)
    }

    public func trashThumbFile(id: String) -> URL {
        trashNotebookDir(id: id).appendingPathComponent("thumb.png", isDirectory: false)
    }

    public func atomicWrite(to targetURL: URL, data: Data) throws {
        let fm = FileManager.default
        let parentURL = targetURL.deletingLastPathComponent()
        try fm.createDirectory(at: parentURL, withIntermediateDirectories: true)
        let tmpURL = parentURL.appendingPathComponent(targetURL.lastPathComponent + ".tmp")
        do {
            guard fm.createFile(atPath: tmpURL.path, contents: nil) else {
                throw NotebookRepositoryError.fileWriteFailed(tmpURL.path)
            }
            let handle = try FileHandle(forWritingTo: tmpURL)
            defer { try? handle.close() }
            try handle.write(contentsOf: data)
            try handle.synchronize()
            if posixRename(tmpURL.path, targetURL.path) != 0 {
                throw NotebookRepositoryError.fileWriteFailed(targetURL.path)
            }
        } catch {
            try? fm.removeItem(at: tmpURL)
            throw error
        }
    }

    public static func defaultTitle(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMM HH.mm"
        return "Catatan " + formatter.string(from: date)
    }

    @discardableResult
    public func create(
        id: String? = nil,
        title: String = "",
        mode: NoteMode,
        orientation: PageOrientation = .portrait,
        folderId: String? = nil,
        paperStyle: PaperStyle? = nil,
        paperSpacing: Float = 28.0
    ) throws -> NotebookMeta {
        lock.lock()
        defer { lock.unlock() }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = cleanTitle.isEmpty ? Self.defaultTitle() : title
        let finalId = id ?? UUID().uuidString.lowercased()
        let defaultPaper = paperStyle ?? (mode == .infinite ? .dots : .plain)

        let meta = NotebookMeta(
            id: finalId,
            title: finalTitle,
            mode: mode,
            pageCount: 1,
            updatedAt: Int64(Date().timeIntervalSince1970 * 1000),
            vpScale: 1.0,
            vpTx: 0.0,
            vpTy: 0.0,
            lastPage: 0,
            paperStyle: defaultPaper,
            paperSpacing: paperSpacing,
            orientation: orientation,
            folderId: folderId
        )

        let dir = notebookDir(id: finalId)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try writeMeta(meta: meta)
        return meta
    }

    public func readMeta(id: String) -> NotebookMeta? {
        lock.lock()
        defer { lock.unlock() }

        let file = metaFile(id: id)
        guard let data = try? Data(contentsOf: file) else { return nil }
        return NotebookMeta.parse(data: data)
    }

    public func writeMeta(meta: NotebookMeta) throws {
        lock.lock()
        defer { lock.unlock() }

        let file = metaFile(id: meta.id)
        let data = try meta.serialize()
        try atomicWrite(to: file, data: data)
    }

    @discardableResult
    public func rename(id: String, title: String) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard var meta = readMeta(id: id) else { return false }
        meta.title = title
        try writeMeta(meta: meta)
        return true
    }

    public func list() -> [NotebookMeta] {
        lock.lock()
        defer { lock.unlock() }

        let dir = notebooksDir
        guard let entries = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: []) else {
            return []
        }

        var result: [NotebookMeta] = []
        for entry in entries {
            guard entry.lastPathComponent != ".trash" else { continue }
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }
            let mf = entry.appendingPathComponent("meta.json", isDirectory: false)
            guard let data = try? Data(contentsOf: mf),
                  let meta = NotebookMeta.parse(data: data) else {
                continue
            }
            result.append(meta)
        }

        let known = Set(listFolders().map { $0.id })
        for i in result.indices {
            if let folderId = result[i].folderId, !known.contains(folderId) {
                result[i].folderId = nil
            }
        }

        result.sort { $0.updatedAt > $1.updatedAt }
        return result
    }

    public func readPage(id: String, index: Int) -> Data? {
        lock.lock()
        defer { lock.unlock() }

        let url = pageFile(id: id, index: index)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    public func writePage(id: String, index: Int, data: Data) throws {
        lock.lock()
        defer { lock.unlock() }

        let url = pageFile(id: id, index: index)
        try atomicWrite(to: url, data: data)
    }

    public func deletePage(id: String, index: Int, pageCount: Int) throws {
        lock.lock()
        defer { lock.unlock() }

        let target = pageFile(id: id, index: index)
        if FileManager.default.fileExists(atPath: target.path) {
            try? FileManager.default.removeItem(at: target)
        }
        let thumbTarget = pageThumbFile(id: id, index: index)
        if FileManager.default.fileExists(atPath: thumbTarget.path) {
            try? FileManager.default.removeItem(at: thumbTarget)
        }

        for k in (index + 1)..<pageCount {
            let oldFile = pageFile(id: id, index: k)
            let newFile = pageFile(id: id, index: k - 1)
            if FileManager.default.fileExists(atPath: oldFile.path) {
                try? FileManager.default.removeItem(at: newFile)
                try? FileManager.default.moveItem(at: oldFile, to: newFile)
            }

            let oldThumb = pageThumbFile(id: id, index: k)
            let newThumb = pageThumbFile(id: id, index: k - 1)
            if FileManager.default.fileExists(atPath: oldThumb.path) {
                try? FileManager.default.removeItem(at: newThumb)
                try? FileManager.default.moveItem(at: oldThumb, to: newThumb)
            }
        }
    }

    public func insertPage(id: String, index: Int, pageCount: Int, data: Data) throws {
        lock.lock()
        defer { lock.unlock() }

        if pageCount - 2 >= index {
            for k in stride(from: pageCount - 2, through: index, by: -1) {
                let src = pageFile(id: id, index: k)
                let dst = pageFile(id: id, index: k + 1)
                if FileManager.default.fileExists(atPath: src.path) {
                    try? FileManager.default.removeItem(at: dst)
                    try? FileManager.default.moveItem(at: src, to: dst)
                }

                let srcThumb = pageThumbFile(id: id, index: k)
                let dstThumb = pageThumbFile(id: id, index: k + 1)
                if FileManager.default.fileExists(atPath: srcThumb.path) {
                    try? FileManager.default.removeItem(at: dstThumb)
                    try? FileManager.default.moveItem(at: srcThumb, to: dstThumb)
                }
            }
        }

        try writePage(id: id, index: index, data: data)

        if var meta = readMeta(id: id) {
            meta.pageCount = pageCount
            try writeMeta(meta: meta)
        }
    }

    public func readThumb(id: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }

        let url = thumbFile(id: id)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    public func writeThumb(id: String, data: Data) throws {
        lock.lock()
        defer { lock.unlock() }

        let url = thumbFile(id: id)
        try atomicWrite(to: url, data: data)
    }

    public func readPageThumb(id: String, index: Int) -> Data? {
        lock.lock()
        defer { lock.unlock() }

        let url = pageThumbFile(id: id, index: index)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    public func writePageThumb(id: String, index: Int, data: Data) throws {
        lock.lock()
        defer { lock.unlock() }

        let url = pageThumbFile(id: id, index: index)
        try atomicWrite(to: url, data: data)
    }

    public func deleteAllThumbs(id: String, pageCount: Int) {
        lock.lock()
        defer { lock.unlock() }

        for i in 0..<pageCount {
            let url = pageThumbFile(id: id, index: i)
            try? FileManager.default.removeItem(at: url)
        }
    }

    public func delete(id: String) throws {
        lock.lock()
        defer { lock.unlock() }

        let dir = notebookDir(id: id)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    public func softDelete(id: String) throws {
        lock.lock()
        defer { lock.unlock() }

        let src = notebookDir(id: id)
        guard FileManager.default.fileExists(atPath: src.path) else { return }

        try FileManager.default.createDirectory(at: trashDir, withIntermediateDirectories: true)
        let dst = trashNotebookDir(id: id)
        if FileManager.default.fileExists(atPath: dst.path) {
            try FileManager.default.removeItem(at: dst)
        }

        try FileManager.default.moveItem(at: src, to: dst)
        let deletedAtURL = dst.appendingPathComponent("deleted_at", isDirectory: false)
        let timestamp = "\(Int64(Date().timeIntervalSince1970 * 1000))"
        try timestamp.write(to: deletedAtURL, atomically: true, encoding: .utf8)
    }

    public func listTrash() -> [TrashedNotebook] {
        lock.lock()
        defer { lock.unlock() }

        guard let entries = try? FileManager.default.contentsOfDirectory(at: trashDir, includingPropertiesForKeys: [.isDirectoryKey], options: []) else {
            return []
        }

        var result: [TrashedNotebook] = []
        for entry in entries {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }
            let mf = entry.appendingPathComponent("meta.json", isDirectory: false)
            guard let data = try? Data(contentsOf: mf),
                  let meta = NotebookMeta.parse(data: data) else {
                continue
            }
            let deletedAtURL = entry.appendingPathComponent("deleted_at", isDirectory: false)
            let deletedAt: Int64
            if let text = try? String(contentsOf: deletedAtURL, encoding: .utf8),
               let parsed = Int64(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                deletedAt = parsed
            } else if let attrs = try? FileManager.default.attributesOfItem(atPath: entry.path),
                      let modDate = attrs[.modificationDate] as? Date {
                deletedAt = Int64(modDate.timeIntervalSince1970 * 1000)
            } else {
                deletedAt = 0
            }
            result.append(TrashedNotebook(meta: meta, deletedAt: deletedAt))
        }

        result.sort { $0.deletedAt > $1.deletedAt }
        return result
    }

    public func restore(id: String) throws {
        lock.lock()
        defer { lock.unlock() }

        let src = trashNotebookDir(id: id)
        guard FileManager.default.fileExists(atPath: src.path) else { return }

        let dst = notebookDir(id: id)
        if FileManager.default.fileExists(atPath: dst.path) {
            try FileManager.default.removeItem(at: dst)
        }

        try FileManager.default.moveItem(at: src, to: dst)
        let deletedAtURL = dst.appendingPathComponent("deleted_at", isDirectory: false)
        if FileManager.default.fileExists(atPath: deletedAtURL.path) {
            try? FileManager.default.removeItem(at: deletedAtURL)
        }
    }

    public func deleteForever(id: String) throws {
        lock.lock()
        defer { lock.unlock() }

        let dir = trashNotebookDir(id: id)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    public func emptyTrash() throws {
        lock.lock()
        defer { lock.unlock() }

        guard let entries = try? FileManager.default.contentsOfDirectory(at: trashDir, includingPropertiesForKeys: nil, options: []) else {
            return
        }
        for entry in entries {
            try? FileManager.default.removeItem(at: entry)
        }
    }

    public func purgeExpired(days: Int = 30) throws {
        lock.lock()
        defer { lock.unlock() }

        guard FileManager.default.fileExists(atPath: trashDir.path),
              let entries = try? FileManager.default.contentsOfDirectory(at: trashDir, includingPropertiesForKeys: nil, options: []) else {
            return
        }
        let cutoff = Int64(Date().timeIntervalSince1970 * 1000) - (Int64(days) * 24 * 60 * 60 * 1000)
        for entry in entries {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }
            let deletedAtURL = entry.appendingPathComponent("deleted_at", isDirectory: false)
            let deletedAt: Int64
            if let text = try? String(contentsOf: deletedAtURL, encoding: .utf8),
               let parsed = Int64(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                deletedAt = parsed
            } else if let attrs = try? FileManager.default.attributesOfItem(atPath: entry.path),
                      let modDate = attrs[.modificationDate] as? Date {
                deletedAt = Int64(modDate.timeIntervalSince1970 * 1000)
            } else {
                deletedAt = 0
            }
            if deletedAt < cutoff {
                try? FileManager.default.removeItem(at: entry)
            }
        }
    }

    public func trashCount() -> Int {
        lock.lock()
        defer { lock.unlock() }

        guard let entries = try? FileManager.default.contentsOfDirectory(at: trashDir, includingPropertiesForKeys: [.isDirectoryKey], options: []) else {
            return 0
        }
        var count = 0
        for entry in entries {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue {
                count += 1
            }
        }
        return count
    }

    public func listFolders() -> [Folder] {
        lock.lock()
        defer { lock.unlock() }

        let file = foldersFile
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }

        do {
            let data = try Data(contentsOf: file)
            let container = try JSONDecoder().decode(FoldersContainer.self, from: data)
            var out = container.folders

            let ids = Set(out.map { $0.id })
            for i in out.indices {
                if let parentId = out[i].parentId, !ids.contains(parentId) {
                    out[i].parentId = nil
                }
            }

            for i in out.indices {
                if hasCycle(start: out[i], all: out) {
                    out[i].parentId = nil
                }
            }

            return out
        } catch {
            let corruptURL = corruptFoldersFile
            try? FileManager.default.removeItem(at: corruptURL)
            try? FileManager.default.moveItem(at: file, to: corruptURL)
            return []
        }
    }

    private func hasCycle(start: Folder, all: [Folder]) -> Bool {
        var byId: [String: Folder] = [:]
        for folder in all {
            byId[folder.id] = folder
        }
        var cur = start.parentId
        var steps = 0
        while let current = cur {
            if current == start.id || steps > all.count {
                return true
            }
            steps += 1
            cur = byId[current]?.parentId
        }
        return false
    }

    public func writeFolders(_ folders: [Folder]) throws {
        lock.lock()
        defer { lock.unlock() }

        let container = FoldersContainer(v: 1, folders: folders)
        let encoder = JSONEncoder()
        let data = try encoder.encode(container)
        try atomicWrite(to: foldersFile, data: data)
    }

    private func nameTaken(folders: [Folder], parentId: String?, name: String, exceptId: String?) -> Bool {
        folders.contains { folder in
            folder.parentId == parentId &&
            folder.id != exceptId &&
            folder.name.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    public func descendantFolderIds(id: String) -> Set<String> {
        lock.lock()
        defer { lock.unlock() }

        let all = listFolders()
        var out = Set<String>()
        var queue = [id]
        while !queue.isEmpty {
            let cur = queue.removeFirst()
            for folder in all where folder.parentId == cur {
                if out.insert(folder.id).inserted {
                    queue.append(folder.id)
                }
            }
        }
        return out
    }

    public func createFolder(name: String, parentId: String?) -> Folder? {
        lock.lock()
        defer { lock.unlock() }

        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return nil }
        var all = listFolders()
        if let parentId = parentId, !all.contains(where: { $0.id == parentId }) {
            return nil
        }
        if nameTaken(folders: all, parentId: parentId, name: clean, exceptId: nil) {
            return nil
        }

        let folder = Folder(
            id: UUID().uuidString.lowercased(),
            name: clean,
            parentId: parentId,
            createdAt: Int64(Date().timeIntervalSince1970 * 1000)
        )
        all.append(folder)
        do {
            try writeFolders(all)
            return folder
        } catch {
            return nil
        }
    }

    public func renameFolder(id: String, name: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return false }
        var all = listFolders()
        guard let targetIndex = all.firstIndex(where: { $0.id == id }) else { return false }
        let target = all[targetIndex]
        if nameTaken(folders: all, parentId: target.parentId, name: clean, exceptId: id) {
            return false
        }
        all[targetIndex].name = clean
        do {
            try writeFolders(all)
            return true
        } catch {
            return false
        }
    }

    public func moveFolder(id: String, newParentId: String?) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        var all = listFolders()
        guard let targetIndex = all.firstIndex(where: { $0.id == id }) else { return false }
        let target = all[targetIndex]
        if let newParentId = newParentId {
            if newParentId == id || descendantFolderIds(id: id).contains(newParentId) {
                return false
            }
            if !all.contains(where: { $0.id == newParentId }) {
                return false
            }
        }
        if nameTaken(folders: all, parentId: newParentId, name: target.name, exceptId: id) {
            return false
        }
        all[targetIndex].parentId = newParentId
        do {
            try writeFolders(all)
            return true
        } catch {
            return false
        }
    }

    public func deleteFolder(id: String) throws {
        lock.lock()
        defer { lock.unlock() }

        var all = listFolders()
        guard let targetIndex = all.firstIndex(where: { $0.id == id }) else { return }
        let target = all[targetIndex]
        let parent = target.parentId
        all.remove(at: targetIndex)
        for i in all.indices {
            if all[i].parentId == id {
                all[i].parentId = parent
            }
        }
        try writeFolders(all)

        guard let entries = try? FileManager.default.contentsOfDirectory(at: notebooksDir, includingPropertiesForKeys: [.isDirectoryKey], options: []) else {
            return
        }
        for entry in entries {
            guard entry.lastPathComponent != ".trash" else { continue }
            let mf = entry.appendingPathComponent("meta.json", isDirectory: false)
            guard let data = try? Data(contentsOf: mf),
                  var meta = NotebookMeta.parse(data: data) else {
                continue
            }
            if meta.folderId == id {
                meta.folderId = parent
                try writeMeta(meta: meta)
            }
        }
    }

    @discardableResult
    public func moveNotebook(id: String, folderId: String?) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if let folderId = folderId, !listFolders().contains(where: { $0.id == folderId }) {
            return false
        }
        guard var meta = readMeta(id: id) else { return false }
        meta.folderId = folderId
        try writeMeta(meta: meta)
        return true
    }

    public func folderPath(folderId: String?) -> [(id: String, name: String)] {
        lock.lock()
        defer { lock.unlock() }

        var byId: [String: Folder] = [:]
        for f in listFolders() {
            byId[f.id] = f
        }
        var out: [(id: String, name: String)] = []
        var cur = folderId
        while let current = cur, out.count <= byId.count {
            guard let folder = byId[current] else { break }
            out.insert((id: folder.id, name: folder.name), at: 0)
            cur = folder.parentId
        }
        return out
    }

    public static func setExcludedFromBackup(_ excluded: Bool, for url: URL) throws {
        #if canImport(Darwin)
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = excluded
        try mutableURL.setResourceValues(values)
        #else
        _ = excluded
        _ = url
        #endif
    }
}
