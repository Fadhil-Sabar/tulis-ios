import Foundation

/// Padanan enum di `model/Models.kt` versi Android.
/// Urutan case harus sama karena nilainya ditulis sebagai ordinal ke file.
/// Di JSON enum ditulis sebagai nama Kotlin (`INFINITE`, `DOTS`), case-sensitive seperti `valueOf`.

public protocol KotlinNamedEnum: CaseIterable, Codable, Sendable {}

extension KotlinNamedEnum {
    public var jsonName: String { String(describing: self).uppercased() }

    public init?(jsonName: String) {
        guard let value = Self.allCases.first(where: { $0.jsonName == jsonName }) else { return nil }
        self = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let name = try container.decode(String.self)
        guard let value = Self(jsonName: name) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown \(Self.self): \(name)"
            )
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(jsonName)
    }
}

public enum NoteMode: Int, KotlinNamedEnum {
    case infinite, paged
}

public enum PaperStyle: Int, KotlinNamedEnum {
    case plain, dots, grid, lines
}

public enum Tool: Int, KotlinNamedEnum {
    case pen, marker, highlighter, eraser, text, pan, shape
}

public enum BrushKind: Int, KotlinNamedEnum {
    case pen, marker, highlighter
}

public enum PageOrientation: Int, KotlinNamedEnum {
    case portrait, landscape

    public var pageW: Float { self == .landscape ? 1414 : 1000 }
    public var pageH: Float { self == .landscape ? 1000 : 1414 }
}

public struct NotebookMeta: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var mode: NoteMode
    public var pageCount: Int
    public var updatedAt: Int64
    public var vpScale: Float
    public var vpTx: Float
    public var vpTy: Float
    public var lastPage: Int
    public var paperStyle: PaperStyle
    public var paperSpacing: Float {
        didSet {
            paperSpacing = min(max(paperSpacing, 12.0), 120.0)
        }
    }
    public var orientation: PageOrientation
    public var folderId: String?

    public init(
        id: String,
        title: String,
        mode: NoteMode,
        pageCount: Int,
        updatedAt: Int64,
        vpScale: Float = 1.0,
        vpTx: Float = 0.0,
        vpTy: Float = 0.0,
        lastPage: Int = 0,
        paperStyle: PaperStyle? = nil,
        paperSpacing: Float = 28.0,
        orientation: PageOrientation = .portrait,
        folderId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.mode = mode
        self.pageCount = pageCount
        self.updatedAt = updatedAt
        self.vpScale = vpScale
        self.vpTx = vpTx
        self.vpTy = vpTy
        self.lastPage = lastPage
        self.paperStyle = paperStyle ?? (mode == .infinite ? .dots : .plain)
        self.paperSpacing = min(max(paperSpacing, 12.0), 120.0)
        self.orientation = orientation
        self.folderId = (folderId?.isEmpty == true) ? nil : folderId
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case mode
        case pageCount
        case updatedAt
        case lastPage
        case paperStyle = "paper"
        case paperSpacing
        case orientation
        case folderId
        case vp
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)

        let modeStr = try container.decode(String.self, forKey: .mode)
        guard let decodedMode = NoteMode(jsonName: modeStr) else {
            throw DecodingError.dataCorruptedError(
                forKey: .mode,
                in: container,
                debugDescription: "Unknown NoteMode: \(modeStr)"
            )
        }
        self.mode = decodedMode

        self.pageCount = try container.decode(Int.self, forKey: .pageCount)
        self.updatedAt = try container.decode(Int64.self, forKey: .updatedAt)
        self.lastPage = (try? container.decodeIfPresent(Int.self, forKey: .lastPage)) ?? 0

        if let vp = try? container.decodeIfPresent([Double].self, forKey: .vp), vp.count >= 3 {
            self.vpScale = Float(vp[0])
            self.vpTx = Float(vp[1])
            self.vpTy = Float(vp[2])
        } else {
            self.vpScale = 1.0
            self.vpTx = 0.0
            self.vpTy = 0.0
        }

        let defaultPaper: PaperStyle = (decodedMode == .infinite ? .dots : .plain)
        if let paperStr = try? container.decodeIfPresent(String.self, forKey: .paperStyle),
           !paperStr.isEmpty,
           let style = PaperStyle(jsonName: paperStr) {
            self.paperStyle = style
        } else {
            self.paperStyle = defaultPaper
        }

        let rawSpacing = (try? container.decodeIfPresent(Double.self, forKey: .paperSpacing)) ?? 28.0
        self.paperSpacing = Float(min(max(rawSpacing, 12.0), 120.0))

        if let orientationStr = try? container.decodeIfPresent(String.self, forKey: .orientation),
           !orientationStr.isEmpty,
           let ori = PageOrientation(jsonName: orientationStr) {
            self.orientation = ori
        } else {
            self.orientation = .portrait
        }

        if let folder = try? container.decodeIfPresent(String.self, forKey: .folderId), !folder.isEmpty {
            self.folderId = folder
        } else {
            self.folderId = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(mode.jsonName, forKey: .mode)
        try container.encode(pageCount, forKey: .pageCount)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(lastPage, forKey: .lastPage)
        try container.encode(paperStyle.jsonName, forKey: .paperStyle)
        try container.encode(Double(paperSpacing), forKey: .paperSpacing)
        try container.encode(orientation.jsonName, forKey: .orientation)
        if let folderId = folderId, !folderId.isEmpty {
            try container.encode(folderId, forKey: .folderId)
        }
        try container.encode([Double(vpScale), Double(vpTx), Double(vpTy)], forKey: .vp)
    }

    public static func parse(data: Data) -> NotebookMeta? {
        try? JSONDecoder().decode(NotebookMeta.self, from: data)
    }

    public static func parse(json: String) -> NotebookMeta? {
        guard let data = json.data(using: .utf8) else { return nil }
        return parse(data: data)
    }

    public func serialize() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self)
    }

    public func serializeString() -> String? {
        guard let data = try? serialize() else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

public struct Folder: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var parentId: String?
    public var createdAt: Int64

    public init(id: String, name: String, parentId: String? = nil, createdAt: Int64 = 0) {
        self.id = id
        self.name = name
        self.parentId = (parentId?.isEmpty == true) ? nil : parentId
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, parentId, createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        if let parent = try? container.decodeIfPresent(String.self, forKey: .parentId), !parent.isEmpty {
            self.parentId = parent
        } else {
            self.parentId = nil
        }
        self.createdAt = (try? container.decodeIfPresent(Int64.self, forKey: .createdAt)) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        if let parentId = parentId, !parentId.isEmpty {
            try container.encode(parentId, forKey: .parentId)
        }
        try container.encode(createdAt, forKey: .createdAt)
    }
}

public struct FoldersContainer: Codable, Equatable, Sendable {
    public var v: Int
    public var folders: [Folder]

    public init(v: Int = 1, folders: [Folder] = []) {
        self.v = v
        self.folders = folders
    }
}

public struct TextItem: Codable, Equatable, Sendable {
    public var x: Float
    public var y: Float
    public var sizeWorld: Float
    public var colorArgb: Int32
    public var widthWorld: Float
    public var text: String

    public init(
        x: Float,
        y: Float,
        sizeWorld: Float,
        colorArgb: Int32,
        widthWorld: Float,
        text: String
    ) {
        self.x = x
        self.y = y
        self.sizeWorld = sizeWorld
        self.colorArgb = colorArgb
        self.widthWorld = widthWorld
        self.text = text
    }

    public init(
        x: Float,
        y: Float,
        sizeWorld: Float,
        colorArgb: Int,
        widthWorld: Float,
        text: String
    ) {
        self.init(
            x: x,
            y: y,
            sizeWorld: sizeWorld,
            colorArgb: Int32(truncatingIfNeeded: colorArgb),
            widthWorld: widthWorld,
            text: text
        )
    }

    public var lineHeight: Float {
        sizeWorld * 1.3
    }

    public var lineCount: Int {
        var lines = 1
        for ch in text {
            if ch == "\n" {
                lines += 1
            }
        }
        return lines
    }

    public var heightWorld: Float {
        Float(lineCount) * lineHeight
    }

    public var worldBounds: (left: Float, top: Float, right: Float, bottom: Float) {
        (x, y, x + widthWorld, y + heightWorld)
    }
}
