import Foundation
import Testing
@testable import TulisCore

@Suite struct PageCodecTests {
    private func loadFixtureData(name: String, ext: String) throws -> Data {
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "Fixtures")
                ?? bundle.url(forResource: name, withExtension: ext) else {
            // Fallback direct path in case Bundle resource resolution differs
            let directURL = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("Fixtures")
                .appendingPathComponent("\(name).\(ext)")
            return try Data(contentsOf: directURL)
        }
        return try Data(contentsOf: url)
    }

    @Test func pageVersionDetection() throws {
        let infiniteData = try loadFixtureData(name: "infinite_v2_page_0", ext: "bin")
        #expect(PageCodec.pageVersion(infiniteData) == 2)

        var v1Data = infiniteData
        v1Data[4] = 1
        #expect(PageCodec.pageVersion(v1Data) == 1)

        var badMagicData = infiniteData
        badMagicData[0] = 0x00
        #expect(PageCodec.pageVersion(badMagicData) == nil)

        let shortData = Data([0x49, 0x4E, 0x4B])
        #expect(PageCodec.pageVersion(shortData) == nil)
    }

    @Test func decodeInfiniteFixtureValues() throws {
        let data = try loadFixtureData(name: "infinite_v2_page_0", ext: "bin")
        let page = try PageCodec.decode(data)

        #expect(page.strokes.count == 4)
        #expect(page.texts.count == 2)

        // Stroke 0: Stylus Pen
        let s0 = page.strokes[0]
        #expect(s0.brushKind == .pen)
        #expect(s0.colorArgb == Int32(bitPattern: 0xFF112233))
        #expect(s0.sizePx == 4.5)
        #expect(s0.toolType == .stylus)
        #expect(s0.strokeUnitLengthCm == 0.05)
        #expect(s0.strokeToWorld.a == 1.0)
        #expect(s0.strokeToWorld.c == 0.0)
        #expect(s0.strokeToWorld.tx == 10.0)
        #expect(s0.strokeToWorld.b == 0.0)
        #expect(s0.strokeToWorld.d == 1.0)
        #expect(s0.strokeToWorld.ty == 20.0)
        #expect(s0.points.count == 3)
        #expect(s0.points[0].x == 10.0)
        #expect(s0.points[0].y == 20.0)
        #expect(s0.points[0].elapsedTimeMillis == 0)
        #expect(s0.points[0].pressure == 0.2)
        #expect(s0.points[0].tiltRadians == 0.1)
        #expect(s0.points[0].orientationRadians == 0.4)

        #expect(s0.points[2].x == 20.0)
        #expect(s0.points[2].y == 30.0)
        #expect(s0.points[2].elapsedTimeMillis == 32)
        #expect(s0.points[2].pressure == 0.8)
        #expect(s0.points[2].tiltRadians == 0.3)
        #expect(s0.points[2].orientationRadians == 0.6)

        // Stroke 1: Marker Touch with sentinels
        let s1 = page.strokes[1]
        #expect(s1.brushKind == .marker)
        #expect(s1.colorArgb == Int32(bitPattern: 0xFF00AA55))
        #expect(s1.sizePx == 12.0)
        #expect(s1.toolType == .touch)
        #expect(s1.strokeUnitLengthCm == StrokeConstants.noStrokeUnitLength)
        #expect(s1.strokeToWorld.a == 1.5)
        #expect(s1.strokeToWorld.c == 0.1)
        #expect(s1.strokeToWorld.tx == 50.0)
        #expect(s1.strokeToWorld.b == 0.1)
        #expect(s1.strokeToWorld.d == 1.5)
        #expect(s1.strokeToWorld.ty == 100.0)
        #expect(s1.points.count == 2)
        #expect(s1.points[0].pressure == StrokeConstants.noPressure)
        #expect(s1.points[0].tiltRadians == StrokeConstants.noTilt)
        #expect(s1.points[0].orientationRadians == StrokeConstants.noOrientation)

        // Stroke 2: Highlighter Mouse
        let s2 = page.strokes[2]
        #expect(s2.brushKind == .highlighter)
        #expect(s2.colorArgb == Int32(bitPattern: 0x66FFCC00))
        #expect(s2.sizePx == 24.0)
        #expect(s2.toolType == .mouse)
        #expect(s2.strokeUnitLengthCm == 0.02)
        #expect(s2.points.count == 2)

        // Stroke 3: Empty stroke (0 points)
        let s3 = page.strokes[3]
        #expect(s3.brushKind == .pen)
        #expect(s3.points.isEmpty)

        // Texts
        let t0 = page.texts[0]
        #expect(t0.x == 10.0)
        #expect(t0.y == 20.0)
        #expect(t0.sizeWorld == 16.0)
        #expect(t0.colorArgb == Int32(bitPattern: 0xFF333333))
        #expect(t0.widthWorld == 200.0)
        #expect(t0.text == "Catatan Tulis v2 ✍️ 📝")

        let t1 = page.texts[1]
        #expect(t1.x == 50.0)
        #expect(t1.y == 100.0)
        #expect(t1.sizeWorld == 24.0)
        #expect(t1.colorArgb == Int32(bitPattern: 0xFFE91E63))
        #expect(t1.widthWorld == 300.0)
        #expect(t1.text == "E = mc² ≈ 8.98755×10¹⁶ J")
    }

    @Test func decodePagedFixtureValues() throws {
        let data = try loadFixtureData(name: "paged_v2_page_0", ext: "bin")
        let page = try PageCodec.decode(data)

        #expect(page.strokes.count == 4)
        #expect(page.texts.count == 2)
        #expect(page.texts[0].text == "Catatan Tulis v2 ✍️ 📝")
        #expect(page.texts[1].text == "E = mc² ≈ 8.98755×10¹⁶ J")
    }

    @Test func roundTripFixturesByteIdentical() throws {
        for fixtureName in ["infinite_v2_page_0", "paged_v2_page_0"] {
            let originalData = try loadFixtureData(name: fixtureName, ext: "bin")
            let decoded = try PageCodec.decode(originalData)
            let reEncoded = PageCodec.encode(decoded)
            #expect(reEncoded == originalData, "Re-encoded byte mismatch for \(fixtureName)")
        }
    }

    @Test func asymmetricMatrixExactBytes() throws {
        // Matriks non-simetris dengan skew_x != skew_y dan translasi_x != translasi_y
        // file[0]=a (scale_x), file[1]=c (skew_x), file[2]=tx (trans_x),
        // file[3]=b (skew_y), file[4]=d (scale_y), file[5]=ty (trans_y)
        let customTransform = AffineTransform(
            a: 1.25,   // MSCALE_X -> file[0]
            b: 0.75,   // MSKEW_Y  -> file[3]
            c: 0.35,   // MSKEW_X  -> file[1]
            d: 2.50,   // MSCALE_Y -> file[4]
            tx: 15.0,  // MTRANS_X -> file[2]
            ty: 42.0   // MTRANS_Y -> file[5]
        )

        let stroke = Stroke(
            brushKind: .pen,
            colorArgb: 0x12345678,
            sizePx: 2.0,
            strokeToWorld: customTransform,
            toolType: .stylus,
            strokeUnitLengthCm: 0.0,
            points: []
        )

        let page = PageContent(strokes: [stroke], texts: [])
        let encoded = PageCodec.encode(page)

        // Verifikasi byte per byte untuk bagian matriks
        // Header:
        // 0..3: magic (4 bytes)
        // 4: version (1 byte)
        // 5..8: strokeCount = 1 (4 bytes)
        // Per stroke:
        // 9: brushKind = 0 (1 byte)
        // 10..13: colorArgb = 0x12345678 (4 bytes)
        // 14..17: sizePx = 2.0 (4 bytes, 0x40000000)
        // 18..41: 6 matrix floats (24 bytes)
        let matrixSlice = encoded.subdata(in: 18..<42)
        let floats = (0..<6).map { i -> Float in
            let bits = matrixSlice.withUnsafeBytes { ptr in
                ptr.loadUnaligned(fromByteOffset: i * 4, as: UInt32.self).bigEndian
            }
            return Float(bitPattern: bits)
        }

        #expect(floats[0] == 1.25) // MSCALE_X = a
        #expect(floats[1] == 0.35) // MSKEW_X  = c
        #expect(floats[2] == 15.0) // MTRANS_X = tx
        #expect(floats[3] == 0.75) // MSKEW_Y  = b
        #expect(floats[4] == 2.50) // MSCALE_Y = d
        #expect(floats[5] == 42.0) // MTRANS_Y = ty

        let decodedPage = try PageCodec.decode(encoded)
        let decodedTransform = decodedPage.strokes[0].strokeToWorld
        #expect(decodedTransform.a == 1.25)
        #expect(decodedTransform.b == 0.75)
        #expect(decodedTransform.c == 0.35)
        #expect(decodedTransform.d == 2.50)
        #expect(decodedTransform.tx == 15.0)
        #expect(decodedTransform.ty == 42.0)
    }

    @Test func errorHandling() throws {
        let validData = try loadFixtureData(name: "infinite_v2_page_0", ext: "bin")

        // 1. Wrong magic
        var badMagic = validData
        badMagic[0] = 0x00
        #expect(throws: PageCodecError.badMagic(0x004E4B50)) {
            try PageCodec.decode(badMagic)
        }

        // 2. Unsupported version 1
        var v1Data = validData
        v1Data[4] = 1
        #expect(throws: PageCodecError.unsupportedV1) {
            try PageCodec.decode(v1Data)
        }

        // 3. Unsupported version 3
        var v3Data = validData
        v3Data[4] = 3
        #expect(throws: PageCodecError.unsupportedVersion(3)) {
            try PageCodec.decode(v3Data)
        }

        // 4. Truncated header
        let shortHeader = validData.prefix(4)
        #expect(throws: PageCodecError.truncated("Truncated while reading version at offset 4, need 1 bytes, total 4")) {
            try PageCodec.decode(shortHeader)
        }

        // 5. Truncated in the middle of strokes
        let cutMidStroke = validData.prefix(50)
        #expect(throws: PageCodecError.self) {
            try PageCodec.decode(cutMidStroke)
        }

        // 6. Excessive stroke count (limitExceeded)
        var excessiveStrokes = validData
        // offset 5 is strokeCount (Int32 big endian)
        let tooMany: UInt32 = 2_000_000
        var tooManyBig = tooMany.bigEndian
        withUnsafeBytes(of: &tooManyBig) { bytes in
            for i in 0..<4 { excessiveStrokes[5 + i] = bytes[i] }
        }
        #expect(throws: PageCodecError.limitExceeded("strokeCount exceeds max (2000000 > 1000000)")) {
            try PageCodec.decode(excessiveStrokes)
        }

        // 7. Negative stroke count
        var negativeStrokes = validData
        let neg: Int32 = -1
        var negBig = neg.bigEndian
        withUnsafeBytes(of: &negBig) { bytes in
            for i in 0..<4 { negativeStrokes[5 + i] = bytes[i] }
        }
        #expect(throws: PageCodecError.limitExceeded("Negative strokeCount: -1")) {
            try PageCodec.decode(negativeStrokes)
        }
    }
}
