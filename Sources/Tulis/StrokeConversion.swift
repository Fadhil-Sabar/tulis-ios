#if canImport(UIKit)
import CoreGraphics
import PencilKit
import TulisCore
import UIKit

public enum StrokeConversion {
    public static func uiColor(fromArgb argb: Int32) -> UIColor {
        let (r, g, b, a) = StrokeMath.rgbaComponents(fromArgb: argb)
        return UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }

    public static func argb(fromUiColor color: UIColor) -> Int32 {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        if color.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return StrokeMath.argb(fromRgba: Float(r), g: Float(g), b: Float(b), a: Float(a))
        }
        var white: CGFloat = 0
        if color.getWhite(&white, alpha: &a) {
            return StrokeMath.argb(fromRgba: Float(white), g: Float(white), b: Float(white), a: Float(a))
        }
        return -16777216
    }

    public static func cgAffineTransform(from transform: AffineTransform) -> CGAffineTransform {
        CGAffineTransform(
            a: CGFloat(transform.a),
            b: CGFloat(transform.b),
            c: CGFloat(transform.c),
            d: CGFloat(transform.d),
            tx: CGFloat(transform.tx),
            ty: CGFloat(transform.ty)
        )
    }

    public static func affineTransform(from cgTransform: CGAffineTransform) -> AffineTransform {
        AffineTransform(
            a: Float(cgTransform.a),
            b: Float(cgTransform.b),
            c: Float(cgTransform.c),
            d: Float(cgTransform.d),
            tx: Float(cgTransform.tx),
            ty: Float(cgTransform.ty)
        )
    }

    public static func pkStrokePoint(from point: StrokePoint, sizePx: Float) -> PKStrokePoint {
        PKStrokePoint(
            location: CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)),
            timeOffset: StrokeMath.timeOffsetSeconds(fromElapsedMillis: point.elapsedTimeMillis),
            size: CGSize(width: CGFloat(sizePx), height: CGFloat(sizePx)),
            opacity: 1,
            force: point.hasPressure ? CGFloat(point.pressure) : 1,
            azimuth: point.hasOrientation ? CGFloat(StrokeMath.azimuth(fromOrientationRadians: point.orientationRadians)) : 0,
            altitude: point.hasTilt ? CGFloat(StrokeMath.altitude(fromTiltRadians: point.tiltRadians)) : .pi / 2
        )
    }

    public static func strokePoint(from pkPoint: PKStrokePoint) -> StrokePoint {
        StrokePoint(
            x: Float(pkPoint.location.x),
            y: Float(pkPoint.location.y),
            elapsedTimeMillis: StrokeMath.elapsedMillis(fromTimeOffsetSeconds: pkPoint.timeOffset),
            pressure: StrokeMath.pressure(fromForce: Float(pkPoint.force)),
            tiltRadians: StrokeMath.tiltRadians(fromAltitude: Float(pkPoint.altitude)),
            orientationRadians: StrokeMath.orientationRadians(fromAzimuth: Float(pkPoint.azimuth))
        )
    }

    public static func pkStroke(from stroke: Stroke) -> PKStroke {
        let inkType: PKInkingTool.InkType
        let color: UIColor

        switch stroke.brushKind {
        case .pen:
            inkType = .pen
            color = uiColor(fromArgb: stroke.colorArgb)
        case .marker:
            inkType = .marker
            color = uiColor(fromArgb: stroke.colorArgb)
        case .highlighter:
            inkType = .marker
            let (r, g, b, a) = StrokeMath.rgbaComponents(fromArgb: stroke.colorArgb)
            let highAlpha: Float = (a >= 0.99 || a <= 0.01) ? (Float(0x66) / 255.0) : a
            color = UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(highAlpha))
        }

        let points = stroke.points.map { pkStrokePoint(from: $0, sizePx: stroke.sizePx) }

        let path = PKStrokePath(controlPoints: points, creationDate: Date())
        let transform = cgAffineTransform(from: stroke.strokeToWorld)
        return PKStroke(ink: PKInk(inkType, color: color), path: path, transform: transform)
    }

    public static func stroke(from pkStroke: PKStroke) -> Stroke {
        let (_, _, _, a) = StrokeMath.rgbaComponents(fromArgb: argb(fromUiColor: pkStroke.ink.color))
        let brushKind: BrushKind

        switch pkStroke.ink.inkType {
        case .pen:
            brushKind = .pen
        case .marker:
            if a <= 0.5 {
                brushKind = .highlighter
            } else {
                brushKind = .marker
            }
        default:
            brushKind = .pen
        }

        let points = pkStroke.path.map { strokePoint(from: $0) }
        let sizePx = Float(pkStroke.path.first?.size.width ?? 3.0)
        let transform = affineTransform(from: pkStroke.transform)
        let colorArgb = argb(fromUiColor: pkStroke.ink.color)

        return Stroke(
            brushKind: brushKind,
            colorArgb: colorArgb,
            sizePx: sizePx,
            strokeToWorld: transform,
            toolType: .stylus,
            strokeUnitLengthCm: StrokeConstants.noStrokeUnitLength,
            points: points
        )
    }
}

extension Stroke {
    public func toPKStroke() -> PKStroke {
        StrokeConversion.pkStroke(from: self)
    }
}

extension PKStroke {
    public func toStroke() -> Stroke {
        StrokeConversion.stroke(from: self)
    }
}

extension PKDrawing {
    public init(strokes: [Stroke], sortForDrawing: Bool = true) {
        let ordered = sortForDrawing ? StrokeMath.sortedInDrawOrder(strokes) : strokes
        self.init(strokes: ordered.map { $0.toPKStroke() })
    }

    public var tulisStrokes: [Stroke] {
        strokes.map { $0.toStroke() }
    }
}
#endif
