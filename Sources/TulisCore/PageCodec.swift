import Foundation

public enum PageCodecError: Error, Equatable, Sendable {
    case badMagic(UInt32)
    case unsupportedV1
    case unsupportedVersion(Int)
    case limitExceeded(String)
    case truncated(String)
    case invalidBrushKind(Int)
}

public enum PageCodec {
    public static let magic: UInt32 = 0x494E4B50
    public static let version1: UInt8 = 1
    public static let version2: UInt8 = 2

    public static let maxStrokes = 1_000_000
    public static let maxPointsPerStroke = 1_000_000
    public static let maxTextLen = 10 * 1024 * 1024
    public static let maxTexts = 100_000

    public static func pageVersion(_ data: Data) -> Int? {
        guard data.count >= 5 else { return nil }
        let magicRead = data.withUnsafeBytes { ptr -> UInt32 in
            ptr.loadUnaligned(fromByteOffset: 0, as: UInt32.self).bigEndian
        }
        guard magicRead == magic else { return nil }
        return Int(data[data.startIndex + 4])
    }

    public static func encode(_ page: PageContent) -> Data {
        var writer = ByteWriter()
        writer.writeUInt32(magic)
        writer.writeUInt8(version2)

        writer.writeInt32(Int32(page.strokes.count))
        for stroke in page.strokes {
            writer.writeUInt8(UInt8(stroke.brushKind.rawValue))
            writer.writeInt32(stroke.colorArgb)
            writer.writeFloat(stroke.sizePx)

            let transform = stroke.strokeToWorld
            writer.writeFloat(transform.a)
            writer.writeFloat(transform.c)
            writer.writeFloat(transform.tx)
            writer.writeFloat(transform.b)
            writer.writeFloat(transform.d)
            writer.writeFloat(transform.ty)

            writer.writeUInt8(stroke.toolType.rawValue)
            writer.writeFloat(stroke.strokeUnitLengthCm)

            writer.writeInt32(Int32(stroke.points.count))
            for pt in stroke.points {
                writer.writeFloat(pt.x)
                writer.writeFloat(pt.y)
                writer.writeInt64(pt.elapsedTimeMillis)
                writer.writeFloat(pt.pressure)
                writer.writeFloat(pt.tiltRadians)
                writer.writeFloat(pt.orientationRadians)
            }
        }

        writer.writeInt32(Int32(page.texts.count))
        for item in page.texts {
            writer.writeFloat(item.x)
            writer.writeFloat(item.y)
            writer.writeFloat(item.sizeWorld)
            writer.writeInt32(item.colorArgb)
            writer.writeFloat(item.widthWorld)

            let utf8Data = Data(item.text.utf8)
            writer.writeInt32(Int32(utf8Data.count))
            writer.writeData(utf8Data)
        }

        return writer.data
    }

    public static func decode(_ data: Data) throws -> PageContent {
        var reader = ByteReader(data: data)

        let magicRead = try reader.readUInt32("magic header")
        guard magicRead == magic else {
            throw PageCodecError.badMagic(magicRead)
        }

        let ver = try reader.readUInt8("version")
        if ver == version1 {
            throw PageCodecError.unsupportedV1
        }
        guard ver == version2 else {
            throw PageCodecError.unsupportedVersion(Int(ver))
        }

        let strokeCountRaw = try reader.readInt32("strokeCount")
        guard strokeCountRaw >= 0 else {
            throw PageCodecError.limitExceeded("Negative strokeCount: \(strokeCountRaw)")
        }
        guard strokeCountRaw <= maxStrokes else {
            throw PageCodecError.limitExceeded("strokeCount exceeds max (\(strokeCountRaw) > \(maxStrokes))")
        }
        let strokeCount = Int(strokeCountRaw)

        var strokes: [Stroke] = []
        strokes.reserveCapacity(strokeCount)

        for _ in 0..<strokeCount {
            let brushByte = try reader.readUInt8("brushKind")
            guard let brushKind = BrushKind(rawValue: Int(brushByte)) else {
                throw PageCodecError.invalidBrushKind(Int(brushByte))
            }

            let colorArgb = try reader.readInt32("colorArgb")
            let sizePx = try reader.readFloat("sizePx")

            let a = try reader.readFloat("matrix[0] (MSCALE_X)")
            let c = try reader.readFloat("matrix[1] (MSKEW_X)")
            let tx = try reader.readFloat("matrix[2] (MTRANS_X)")
            let b = try reader.readFloat("matrix[3] (MSKEW_Y)")
            let d = try reader.readFloat("matrix[4] (MSCALE_Y)")
            let ty = try reader.readFloat("matrix[5] (MTRANS_Y)")
            let strokeToWorld = AffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)

            let toolTypeByte = try reader.readUInt8("toolType")
            let toolType = ToolType(rawValue: toolTypeByte) ?? .unknown

            let strokeUnitLengthCm = try reader.readFloat("strokeUnitLengthCm")

            let pointCountRaw = try reader.readInt32("pointCount")
            guard pointCountRaw >= 0 else {
                throw PageCodecError.limitExceeded("Negative pointCount: \(pointCountRaw)")
            }
            guard pointCountRaw <= maxPointsPerStroke else {
                throw PageCodecError.limitExceeded("pointCount exceeds max (\(pointCountRaw) > \(maxPointsPerStroke))")
            }
            let pointCount = Int(pointCountRaw)

            var points: [StrokePoint] = []
            points.reserveCapacity(pointCount)

            for _ in 0..<pointCount {
                let x = try reader.readFloat("point.x")
                let y = try reader.readFloat("point.y")
                let elapsedTimeMillis = try reader.readInt64("point.elapsedTimeMillis")
                let pressure = try reader.readFloat("point.pressure")
                let tiltRadians = try reader.readFloat("point.tiltRadians")
                let orientationRadians = try reader.readFloat("point.orientationRadians")

                points.append(
                    StrokePoint(
                        x: x,
                        y: y,
                        elapsedTimeMillis: elapsedTimeMillis,
                        pressure: pressure,
                        tiltRadians: tiltRadians,
                        orientationRadians: orientationRadians
                    )
                )
            }

            strokes.append(
                Stroke(
                    brushKind: brushKind,
                    colorArgb: colorArgb,
                    sizePx: sizePx,
                    strokeToWorld: strokeToWorld,
                    toolType: toolType,
                    strokeUnitLengthCm: strokeUnitLengthCm,
                    points: points
                )
            )
        }

        let textCountRaw = try reader.readInt32("textCount")
        guard textCountRaw >= 0 else {
            throw PageCodecError.limitExceeded("Negative textCount: \(textCountRaw)")
        }
        guard textCountRaw <= maxTexts else {
            throw PageCodecError.limitExceeded("textCount exceeds max (\(textCountRaw) > \(maxTexts))")
        }
        let textCount = Int(textCountRaw)

        var texts: [TextItem] = []
        texts.reserveCapacity(textCount)

        for _ in 0..<textCount {
            let x = try reader.readFloat("text.x")
            let y = try reader.readFloat("text.y")
            let sizeWorld = try reader.readFloat("text.sizeWorld")
            let colorArgb = try reader.readInt32("text.colorArgb")
            let widthWorld = try reader.readFloat("text.widthWorld")

            let utf8LenRaw = try reader.readInt32("utf8Len")
            guard utf8LenRaw >= 0 else {
                throw PageCodecError.limitExceeded("Negative utf8Len: \(utf8LenRaw)")
            }
            guard utf8LenRaw <= maxTextLen else {
                throw PageCodecError.limitExceeded("utf8Len exceeds max (\(utf8LenRaw) > \(maxTextLen))")
            }
            let utf8Len = Int(utf8LenRaw)

            let textBytes = try reader.readBytes(count: utf8Len, field: "text.utf8Bytes")
            let text = String(decoding: textBytes, as: UTF8.self)

            texts.append(
                TextItem(
                    x: x,
                    y: y,
                    sizeWorld: sizeWorld,
                    colorArgb: colorArgb,
                    widthWorld: widthWorld,
                    text: text
                )
            )
        }

        return PageContent(strokes: strokes, texts: texts)
    }
}

private struct ByteWriter {
    private(set) var data: Data

    init(capacity: Int = 1024) {
        self.data = Data()
        self.data.reserveCapacity(capacity)
    }

    mutating func writeUInt8(_ value: UInt8) {
        data.append(value)
    }

    mutating func writeUInt32(_ value: UInt32) {
        var big = value.bigEndian
        withUnsafeBytes(of: &big) { data.append(contentsOf: $0) }
    }

    mutating func writeInt32(_ value: Int32) {
        var big = value.bigEndian
        withUnsafeBytes(of: &big) { data.append(contentsOf: $0) }
    }

    mutating func writeInt64(_ value: Int64) {
        var big = value.bigEndian
        withUnsafeBytes(of: &big) { data.append(contentsOf: $0) }
    }

    mutating func writeFloat(_ value: Float) {
        var big = value.bitPattern.bigEndian
        withUnsafeBytes(of: &big) { data.append(contentsOf: $0) }
    }

    mutating func writeData(_ bytes: Data) {
        data.append(bytes)
    }
}

private struct ByteReader {
    private let data: Data
    private var offset: Int

    init(data: Data) {
        self.data = data
        self.offset = 0
    }

    private mutating func ensureAvailable(_ count: Int, field: String) throws {
        guard offset + count <= data.count else {
            throw PageCodecError.truncated("Truncated while reading \(field) at offset \(offset), need \(count) bytes, total \(data.count)")
        }
    }

    mutating func readUInt8(_ field: String) throws -> UInt8 {
        try ensureAvailable(1, field: field)
        defer { offset += 1 }
        return data[data.startIndex + offset]
    }

    mutating func readUInt32(_ field: String) throws -> UInt32 {
        try ensureAvailable(4, field: field)
        let val = data.withUnsafeBytes { ptr -> UInt32 in
            ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self).bigEndian
        }
        offset += 4
        return val
    }

    mutating func readInt32(_ field: String) throws -> Int32 {
        try ensureAvailable(4, field: field)
        let val = data.withUnsafeBytes { ptr -> Int32 in
            Int32(bitPattern: ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self).bigEndian)
        }
        offset += 4
        return val
    }

    mutating func readInt64(_ field: String) throws -> Int64 {
        try ensureAvailable(8, field: field)
        let val = data.withUnsafeBytes { ptr -> Int64 in
            Int64(bitPattern: ptr.loadUnaligned(fromByteOffset: offset, as: UInt64.self).bigEndian)
        }
        offset += 8
        return val
    }

    mutating func readFloat(_ field: String) throws -> Float {
        try ensureAvailable(4, field: field)
        let bits = data.withUnsafeBytes { ptr -> UInt32 in
            ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self).bigEndian
        }
        offset += 4
        return Float(bitPattern: bits)
    }

    mutating func readBytes(count: Int, field: String) throws -> Data {
        try ensureAvailable(count, field: field)
        let sub = data.subdata(in: (data.startIndex + offset)..<(data.startIndex + offset + count))
        offset += count
        return sub
    }
}
