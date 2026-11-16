import Foundation
import Testing
@testable import TulisCore

@Test func toolTypeNilaiDanJsonName() {
    #expect(ToolType.unknown.rawValue == 0)
    #expect(ToolType.mouse.rawValue == 1)
    #expect(ToolType.touch.rawValue == 2)
    #expect(ToolType.stylus.rawValue == 3)
    #expect(ToolType.allCases.count == 4)

    #expect(ToolType.unknown.jsonName == "UNKNOWN")
    #expect(ToolType.mouse.jsonName == "MOUSE")
    #expect(ToolType.touch.jsonName == "TOUCH")
    #expect(ToolType.stylus.jsonName == "STYLUS")
}

@Test func konversiSudutTiltAltitude() {
    let piOver2 = Float.pi / 2.0

    // Tilt 0 = tegak -> altitude pi/2 = tegak
    #expect(abs(StrokeMath.altitude(fromTiltRadians: 0.0) - piOver2) < 1e-5)
    #expect(abs(StrokeMath.tiltRadians(fromAltitude: piOver2) - 0.0) < 1e-5)

    // Tilt pi/2 = tidur/flat -> altitude 0 = tidur/flat
    #expect(abs(StrokeMath.altitude(fromTiltRadians: piOver2) - 0.0) < 1e-5)
    #expect(abs(StrokeMath.tiltRadians(fromAltitude: 0.0) - piOver2) < 1e-5)

    // Sudut 45 derajat (pi/4)
    let piOver4 = Float.pi / 4.0
    #expect(abs(StrokeMath.altitude(fromTiltRadians: piOver4) - piOver4) < 1e-5)
    #expect(abs(StrokeMath.tiltRadians(fromAltitude: piOver4) - piOver4) < 1e-5)

    // Round-trip sudut acak dalam rentang 0..pi/2
    for angleDeg in [5.0, 15.0, 30.0, 60.0, 75.0, 85.0] {
        let tilt = Float(angleDeg * .pi / 180.0)
        let altitude = StrokeMath.altitude(fromTiltRadians: tilt)
        let backTilt = StrokeMath.tiltRadians(fromAltitude: altitude)
        #expect(abs(backTilt - tilt) < 1e-5)
    }

    // Sentinel dipertahankan
    #expect(StrokeMath.altitude(fromTiltRadians: StrokeConstants.noTilt) == StrokeConstants.noTilt)
    #expect(StrokeMath.tiltRadians(fromAltitude: StrokeConstants.noTilt) == StrokeConstants.noTilt)
    #expect(StrokeMath.altitude(fromTiltRadians: -1.0) == -1.0)
    #expect(StrokeMath.tiltRadians(fromAltitude: -1.0) == -1.0)
}

@Test func konversiSudutOrientationAzimuth() {
    // 0 radian = sumbu +x
    #expect(abs(StrokeMath.azimuth(fromOrientationRadians: 0.0) - 0.0) < 1e-5)
    #expect(abs(StrokeMath.orientationRadians(fromAzimuth: 0.0) - 0.0) < 1e-5)

    // pi/2 radian = searah jarum jam (sumbu +y)
    let piOver2 = Float.pi / 2.0
    #expect(abs(StrokeMath.azimuth(fromOrientationRadians: piOver2) - piOver2) < 1e-5)
    #expect(abs(StrokeMath.orientationRadians(fromAzimuth: piOver2) - piOver2) < 1e-5)

    // pi radian = sumbu -x
    #expect(abs(StrokeMath.azimuth(fromOrientationRadians: Float.pi) - Float.pi) < 1e-5)
    #expect(abs(StrokeMath.orientationRadians(fromAzimuth: Float.pi) - Float.pi) < 1e-5)

    // 1.5 * pi radian di Android (sumbu -y, 270 derajat) -> -pi/2 di iOS azimuth
    let threePiOver2 = 1.5 * Float.pi
    #expect(abs(StrokeMath.azimuth(fromOrientationRadians: threePiOver2) - (-piOver2)) < 1e-5)
    #expect(abs(StrokeMath.orientationRadians(fromAzimuth: -piOver2) - threePiOver2) < 1e-5)

    // Round-trip berbagai sudut
    for angle in [0.2, 0.7, 1.5, 2.5, 3.1, 4.0, 5.2, 6.0] {
        let ori = Float(angle)
        let azi = StrokeMath.azimuth(fromOrientationRadians: ori)
        let backOri = StrokeMath.orientationRadians(fromAzimuth: azi)
        #expect(abs(backOri - ori) < 1e-5)
    }

    // Sentinel dipertahankan
    #expect(StrokeMath.azimuth(fromOrientationRadians: StrokeConstants.noOrientation) == StrokeConstants.noOrientation)
    #expect(StrokeMath.orientationRadians(fromAzimuth: StrokeConstants.noOrientation) == StrokeConstants.noOrientation)
    #expect(StrokeMath.azimuth(fromOrientationRadians: -1.0) == -1.0)
    #expect(StrokeMath.orientationRadians(fromAzimuth: -1.0) == -1.0)
}

@Test func konversiWaktuMillisDetik() {
    #expect(StrokeMath.timeOffsetSeconds(fromElapsedMillis: 0) == 0.0)
    #expect(StrokeMath.elapsedMillis(fromTimeOffsetSeconds: 0.0) == 0)

    #expect(StrokeMath.timeOffsetSeconds(fromElapsedMillis: 1234) == 1.234)
    #expect(StrokeMath.elapsedMillis(fromTimeOffsetSeconds: 1.234) == 1234)

    #expect(StrokeMath.timeOffsetSeconds(fromElapsedMillis: 16) == 0.016)
    #expect(StrokeMath.elapsedMillis(fromTimeOffsetSeconds: 0.016) == 16)

    #expect(StrokeMath.timeOffsetSeconds(fromElapsedMillis: 60000) == 60.0)
    #expect(StrokeMath.elapsedMillis(fromTimeOffsetSeconds: 60.0) == 60000)
}

@Test func konversiArgbRgbaRoundTrip() {
    let testColors: [Int32] = [
        -16777216,                         // 0xFF000000 (Hitam pekat, negatif)
        -1,                                 // 0xFFFFFFFF (Putih pekat, negatif)
        -65536,                             // 0xFFFF0000 (Merah pekat, negatif)
        -16711936,                          // 0xFF00FF00 (Hijau pekat, negatif)
        -16776961,                          // 0xFF0000FF (Biru pekat, negatif)
        Int32(bitPattern: 0x80123456),      // Alpha 0x80, nilai negatif Int32
        Int32(bitPattern: 0x80000000),      // Alpha 0x80 murni, Int32.min
        Int32(bitPattern: 0x80FFCC00),      // Kuning stabilo alpha 0x80
        Int32(bitPattern: 0x66FFFF00),      // Kuning stabilo 0x66 seperti Android
        0x7F112233,                         // Alpha 0x7F, nilai positif Int32
        0x00000000,                         // Transparan total
        0x01020304                          // Nilai kecil
    ]

    for original in testColors {
        let (r, g, b, a) = StrokeMath.rgbaComponents(fromArgb: original)
        let roundTrip = StrokeMath.argb(fromRgba: r, g: g, b: b, a: a)
        #expect(roundTrip == original, "Gagal round-trip untuk color: \(String(format: "0x%08X", original))")
    }
}

@Test func sentinelDipertahankanPadaStrokePoint() {
    let defaultPoint = StrokePoint(x: 10.0, y: 20.0)
    #expect(defaultPoint.x == 10.0)
    #expect(defaultPoint.y == 20.0)
    #expect(defaultPoint.elapsedTimeMillis == 0)
    #expect(defaultPoint.pressure == -1.0)
    #expect(defaultPoint.tiltRadians == -1.0)
    #expect(defaultPoint.orientationRadians == -1.0)
    #expect(!defaultPoint.hasPressure)
    #expect(!defaultPoint.hasTilt)
    #expect(!defaultPoint.hasOrientation)

    let pointWithData = StrokePoint(
        x: 15.0,
        y: 25.0,
        elapsedTimeMillis: 32,
        pressure: 0.6,
        tiltRadians: 0.2,
        orientationRadians: 1.0
    )
    #expect(pointWithData.hasPressure)
    #expect(pointWithData.hasTilt)
    #expect(pointWithData.hasOrientation)

    #expect(StrokeMath.force(fromPressure: StrokeConstants.noPressure) == StrokeConstants.noPressure)
    #expect(StrokeMath.pressure(fromForce: StrokeConstants.noPressure) == StrokeConstants.noPressure)
}

@Test func boundsGoresanDenganTransform() {
    // 1. Kosong -> nil
    let emptyStroke = Stroke(points: [])
    #expect(emptyStroke.worldBounds == nil)

    // 2. Identity transform tanpa stroke width
    let stroke1 = Stroke(
        sizePx: 4.0,
        strokeToWorld: .identity,
        points: [
            StrokePoint(x: 10.0, y: 20.0),
            StrokePoint(x: 110.0, y: 70.0)
        ]
    )
    let rawBounds = stroke1.worldBounds(includingStrokeWidth: false)
    #expect(rawBounds != nil)
    #expect(rawBounds?.left == 10.0)
    #expect(rawBounds?.top == 20.0)
    #expect(rawBounds?.right == 110.0)
    #expect(rawBounds?.bottom == 70.0)

    // Dengan stroke width (radius = sizePx / 2 = 2.0)
    let boundsWithWidth = stroke1.worldBounds(includingStrokeWidth: true)
    #expect(boundsWithWidth != nil)
    #expect(boundsWithWidth?.left == 8.0)
    #expect(boundsWithWidth?.top == 18.0)
    #expect(boundsWithWidth?.right == 112.0)
    #expect(boundsWithWidth?.bottom == 72.0)

    // 3. Transform dengan translasi tx = 50, ty = 30
    let transformTrans = AffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 50.0, ty: 30.0)
    let strokeTrans = Stroke(
        sizePx: 4.0,
        strokeToWorld: transformTrans,
        points: [
            StrokePoint(x: 10.0, y: 20.0),
            StrokePoint(x: 110.0, y: 70.0)
        ]
    )
    let transBounds = strokeTrans.worldBounds(includingStrokeWidth: false)
    #expect(transBounds?.left == 60.0)
    #expect(transBounds?.top == 50.0)
    #expect(transBounds?.right == 160.0)
    #expect(transBounds?.bottom == 100.0)

    // 4. Transform dengan skala a = 2.0, d = 3.0
    let transformScale = AffineTransform(a: 2.0, b: 0.0, c: 0.0, d: 3.0, tx: 0.0, ty: 0.0)
    let strokeScale = Stroke(
        sizePx: 4.0,
        strokeToWorld: transformScale,
        points: [
            StrokePoint(x: 10.0, y: 20.0),
            StrokePoint(x: 50.0, y: 30.0)
        ]
    )
    let scaleBoundsRaw = strokeScale.worldBounds(includingStrokeWidth: false)
    #expect(scaleBoundsRaw?.left == 20.0)
    #expect(scaleBoundsRaw?.top == 60.0)
    #expect(scaleBoundsRaw?.right == 100.0)
    #expect(scaleBoundsRaw?.bottom == 90.0)

    // maxScale = 3.0, radius = 2.0 * 3.0 = 6.0
    let scaleBoundsWithWidth = strokeScale.worldBounds(includingStrokeWidth: true)
    #expect(scaleBoundsWithWidth?.left == 14.0)
    #expect(scaleBoundsWithWidth?.top == 54.0)
    #expect(scaleBoundsWithWidth?.right == 106.0)
    #expect(scaleBoundsWithWidth?.bottom == 96.0)
}

@Test func drawOrderHighlighterDiBawah() {
    let pen1 = Stroke(brushKind: .pen)
    let high1 = Stroke(brushKind: .highlighter)
    let marker1 = Stroke(brushKind: .marker)
    let high2 = Stroke(brushKind: .highlighter)
    let pen2 = Stroke(brushKind: .pen)

    let sorted = StrokeMath.sortedInDrawOrder([pen1, high1, marker1, high2, pen2])
    #expect(sorted.count == 5)
    #expect(sorted[0].brushKind == .highlighter)
    #expect(sorted[1].brushKind == .highlighter)
    #expect(sorted[2].brushKind == .pen)
    #expect(sorted[3].brushKind == .marker)
    #expect(sorted[4].brushKind == .pen)
}

@Test func pageContentCodableRoundTrip() throws {
    let content = PageContent(
        strokes: [
            Stroke(
                brushKind: .pen,
                colorArgb: -16777216,
                sizePx: 3.0,
                strokeToWorld: AffineTransform(tx: 10, ty: 20),
                toolType: .stylus,
                strokeUnitLengthCm: 0.0,
                points: [
                    StrokePoint(x: 1, y: 2, elapsedTimeMillis: 0, pressure: 0.5, tiltRadians: 0.1, orientationRadians: 1.0)
                ]
            )
        ],
        texts: [
            TextItem(x: 10, y: 20, sizeWorld: 16, colorArgb: -16777216, widthWorld: 100, text: "Halo")
        ]
    )

    let data = try JSONEncoder().encode(content)
    let decoded = try JSONDecoder().decode(PageContent.self, from: data)
    #expect(decoded == content)
}
