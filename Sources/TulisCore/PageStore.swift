import Foundation

public protocol PageStore: Sendable {
    func load(notebookId: String, pageIndex: Int) throws -> PageContent?
    func save(notebookId: String, pageIndex: Int, content: PageContent) throws
}

public struct BinaryPageStore: PageStore {
    public let repository: NotebookRepository

    public init(repository: NotebookRepository) {
        self.repository = repository
    }

    public func load(notebookId: String, pageIndex: Int) throws -> PageContent? {
        guard let data = repository.readPage(id: notebookId, index: pageIndex) else { return nil }
        return try PageCodec.decode(data)
    }

    public func save(notebookId: String, pageIndex: Int, content: PageContent) throws {
        try repository.writePage(id: notebookId, index: pageIndex, data: PageCodec.encode(content))
    }
}
