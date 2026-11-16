import Foundation

public enum ToolType: UInt8, CaseIterable, Codable, Sendable {
    case unknown = 0
    case mouse = 1
    case touch = 2
    case stylus = 3

    public var jsonName: String {
        String(describing: self).uppercased()
    }
}

public enum StrokeConstants {
    public static let noPressure: Float = -1.0
    public static let noTilt: Float = -1.0
    public static let noOrientation: Float = -1.0
    public static let noStrokeUnitLength: Float = 0.0
}

public struct StrokePoint: Equatable, Sendable, Codable {
    public static let noPressure: Float = StrokeConstants.noPressure
    public static let noTilt: Float = StrokeConstants.noTilt
    public static let noOrientation: Float = StrokeConstants.noOrientation

    public var x: Float
    public var y: Float
    public var elapsedTimeMillis: Int64
    public var pressure: Float
    public var tiltRadians: Float
    public var orientationRadians: Float

    public var hasPressure: Bool { pressure >= 0 }
    public var hasTilt: Bool { tiltRadians >= 0 }
    public var hasOrientation: Bool { orientationRadians >= 0 }

    public init(
        x: Float,
        y: Float,
        elapsedTimeMillis: Int64 = 0,
        pressure: Float = StrokeConstants.noPressure,
        tiltRadians: Float = StrokeConstants.noTilt,
        orientationRadians: Float = StrokeConstants.noOrientation
    ) {
        self.x = x
        self.y = y
        self.elapsedTimeMillis = elapsedTimeMillis
        self.pressure = pressure
        self.tiltRadians = tiltRadians
        self.orientationRadians = orientationRadians
    }
}

public struct AffineTransform: Equatable, Sendable, Codable {
    public var a: Float
    public var b: Float
    public var c: Float
    public var d: Float
    public var tx: Float
    public var ty: Float

    public static let identity = AffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)

    public init(
        a: Float = 1,
        b: Float = 0,
        c: Float = 0,
        d: Float = 1,
        tx: Float = 0,
        ty: Float = 0
    ) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        self.tx = tx
        self.ty = ty
    }

    public init(values: [Float]) {
        if values.count >= 6 {
            self.a = values[0]
            self.b = values[1]
            self.c = values[2]
            self.d = values[3]
            self.tx = values[4]
            self.ty = values[5]
        } else {
            self = .identity
        }
    }

    public var values: [Float] {
        [a, b, c, d, tx, ty]
    }

    public func apply(x: Float, y: Float) -> (x: Float, y: Float) {
        (
            x: a * x + c * y + tx,
            y: b * x + d * y + ty
        )
    }

    public func apply(point: StrokePoint) -> (x: Float, y: Float) {
        apply(x: point.x, y: point.y)
    }

    public func concatenating(_ other: AffineTransform) -> AffineTransform {
        AffineTransform(
            a: other.a * a + other.c * b,
            b: other.b * a + other.d * b,
            c: other.a * c + other.c * d,
            d: other.b * c + other.d * d,
            tx: other.a * tx + other.c * ty + other.tx,
            ty: other.b * tx + other.d * ty + other.ty
        )
    }

    public var maxScale: Float {
        max(sqrt(a * a + b * b), sqrt(c * c + d * d))
    }
}

public struct Stroke: Equatable, Sendable, Codable {
    public var brushKind: BrushKind
    public var colorArgb: Int32
    public var sizePx: Float
    public var strokeToWorld: AffineTransform
    public var toolType: ToolType
    public var strokeUnitLengthCm: Float
    public var points: [StrokePoint]

    public init(
        brushKind: BrushKind = .pen,
        colorArgb: Int32 = -16777216,
        sizePx: Float = 3.0,
        strokeToWorld: AffineTransform = .identity,
        toolType: ToolType = .stylus,
        strokeUnitLengthCm: Float = StrokeConstants.noStrokeUnitLength,
        points: [StrokePoint] = []
    ) {
        self.brushKind = brushKind
        self.colorArgb = colorArgb
        self.sizePx = sizePx
        self.strokeToWorld = strokeToWorld
        self.toolType = toolType
        self.strokeUnitLengthCm = strokeUnitLengthCm
        self.points = points
    }

    public var worldBounds: (left: Float, top: Float, right: Float, bottom: Float)? {
        worldBounds(includingStrokeWidth: true)
    }

    public func worldBounds(includingStrokeWidth: Bool = true) -> (left: Float, top: Float, right: Float, bottom: Float)? {
        guard let first = points.first else { return nil }
        let (firstX, firstY) = strokeToWorld.apply(x: first.x, y: first.y)
        var minX = firstX
        var maxX = firstX
        var minY = firstY
        var maxY = firstY

        for pt in points.dropFirst() {
            let (wx, wy) = strokeToWorld.apply(x: pt.x, y: pt.y)
            if wx < minX { minX = wx }
            if wx > maxX { maxX = wx }
            if wy < minY { minY = wy }
            if wy > maxY { maxY = wy }
        }

        if includingStrokeWidth {
            let radius = (sizePx / 2.0) * strokeToWorld.maxScale
            return (
                left: minX - radius,
                top: minY - radius,
                right: maxX + radius,
                bottom: maxY + radius
            )
        } else {
            return (left: minX, top: minY, right: maxX, bottom: maxY)
        }
    }
}

public struct PageContent: Equatable, Sendable, Codable {
    public var strokes: [Stroke]
    public var texts: [TextItem]

    public init(strokes: [Stroke] = [], texts: [TextItem] = []) {
        self.strokes = strokes
        self.texts = texts
    }
}

public enum StrokeMath {
    public static func timeOffsetSeconds(fromElapsedMillis millis: Int64) -> Double {
        Double(millis) / 1000.0
    }

    public static func elapsedMillis(fromTimeOffsetSeconds seconds: Double) -> Int64 {
        Int64((seconds * 1000.0).rounded())
    }

    public static func rgbaComponents(fromArgb argb: Int32) -> (r: Float, g: Float, b: Float, a: Float) {
        let u = UInt32(bitPattern: argb)
        let a = Float((u >> 24) & 0xFF) / 255.0
        let r = Float((u >> 16) & 0xFF) / 255.0
        let g = Float((u >> 8) & 0xFF) / 255.0
        let b = Float(u & 0xFF) / 255.0
        return (r, g, b, a)
    }

    public static func argb(fromRgba r: Float, g: Float, b: Float, a: Float) -> Int32 {
        let ai = UInt32(max(0, min(255, (a * 255.0).rounded())))
        let ri = UInt32(max(0, min(255, (r * 255.0).rounded())))
        let gi = UInt32(max(0, min(255, (g * 255.0).rounded())))
        let bi = UInt32(max(0, min(255, (b * 255.0).rounded())))
        let u = (ai << 24) | (ri << 16) | (gi << 8) | bi
        return Int32(bitPattern: u)
    }

    public static func altitude(fromTiltRadians tilt: Float) -> Float {
        if tilt < 0 {
            return StrokeConstants.noTilt
        }
        return max(0, min(Float.pi / 2, Float.pi / 2 - tilt))
    }

    public static func tiltRadians(fromAltitude altitude: Float) -> Float {
        if altitude < 0 {
            return StrokeConstants.noTilt
        }
        return max(0, min(Float.pi / 2, Float.pi / 2 - altitude))
    }

    public static func azimuth(fromOrientationRadians orientation: Float) -> Float {
        if orientation < 0 {
            return StrokeConstants.noOrientation
        }
        let twoPi = 2 * Float.pi
        var norm = orientation.truncatingRemainder(dividingBy: twoPi)
        if norm < 0 { norm += twoPi }
        if norm > Float.pi {
            return norm - twoPi
        } else {
            return norm
        }
    }

    public static func orientationRadians(fromAzimuth azimuth: Float) -> Float {
        if azimuth == StrokeConstants.noOrientation || azimuth < -Float.pi {
            return StrokeConstants.noOrientation
        }
        let twoPi = 2 * Float.pi
        var norm = azimuth.truncatingRemainder(dividingBy: twoPi)
        if norm < 0 { norm += twoPi }
        return norm
    }

    public static func force(fromPressure pressure: Float) -> Float {
        if pressure < 0 {
            return StrokeConstants.noPressure
        }
        return pressure
    }

    public static func pressure(fromForce force: Float) -> Float {
        if force < 0 {
            return StrokeConstants.noPressure
        }
        return force
    }

    public static func sortedInDrawOrder(_ strokes: [Stroke]) -> [Stroke] {
        var highlighters: [Stroke] = []
        var others: [Stroke] = []
        for s in strokes {
            if s.brushKind == .highlighter {
                highlighters.append(s)
            } else {
                others.append(s)
            }
        }
        return highlighters + others
    }

    public static func penWidthFactor(pressure: Float) -> Float {
        guard pressure >= 0 else { return 1 }
        return 0.5 + min(pressure, 1) * 0.75
    }

    public static func syntheticPressures(
        points: [(x: Float, y: Float, elapsedTimeMillis: Int64)],
        fastSpeed: Float = 1800
    ) -> [Float] {
        var result: [Float] = []
        result.reserveCapacity(points.count)
        var smoothed: Float = 0.6
        for i in points.indices {
            if i > 0 {
                let a = points[i - 1]
                let b = points[i]
                let dt = max(Float(b.elapsedTimeMillis - a.elapsedTimeMillis), 1) / 1000
                let speed = hypot(b.x - a.x, b.y - a.y) / dt
                let target = max(0.2, min(1, 1 - speed / fastSpeed))
                smoothed += (target - smoothed) * 0.3
            }
            result.append(smoothed)
        }
        return result
    }
}
