#if canImport(UIKit)
import CoreGraphics
import Foundation
import PencilKit
import SwiftUI
import TulisCore
import UIKit
import UIKit.UIGestureRecognizerSubclass

public final class InfiniteCanvasContainerView: UIView, UIScrollViewDelegate, PKCanvasViewDelegate {
    public static let worldOrigin = CGPoint(x: 100_000.0, y: 100_000.0)
    public static let canvasContentSize = CGSize(width: 200_000.0, height: 200_000.0)

    public let patternView = InfinitePaperPatternView()
    public let highlighterCanvas = PKCanvasView()
    public let inkCanvas = PKCanvasView()

    public var onDrawingChanged: (() -> Void)?
    public var onViewportChanged: ((Float, Float, Float) -> Void)?

    private var loadedStrokeMap: [PKStrokeKey: Stroke] = [:]
    public var isUpdatingInternally = false
    private var isSyncingViewport = false
    private var isInitializingViewport = false

    private var activeTool: Tool = .pen
    public private(set) var isErasing = false
    private lazy var eraserGesture = ImmediateDragGestureRecognizer(target: self, action: #selector(handleErase(_:)))
    private var lastErasePoint: CGPoint?
    private var toolConfig: ToolConfig?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        backgroundColor = TulisPalette.uiCanvas

        patternView.translatesAutoresizingMaskIntoConstraints = false
        patternView.isUserInteractionEnabled = false
        addSubview(patternView)

        configureCanvas(highlighterCanvas)
        configureCanvas(inkCanvas)

        addSubview(highlighterCanvas)
        addSubview(inkCanvas)

        NSLayoutConstraint.activate([
            patternView.leadingAnchor.constraint(equalTo: leadingAnchor),
            patternView.trailingAnchor.constraint(equalTo: trailingAnchor),
            patternView.topAnchor.constraint(equalTo: topAnchor),
            patternView.bottomAnchor.constraint(equalTo: bottomAnchor),

            highlighterCanvas.leadingAnchor.constraint(equalTo: leadingAnchor),
            highlighterCanvas.trailingAnchor.constraint(equalTo: trailingAnchor),
            highlighterCanvas.topAnchor.constraint(equalTo: topAnchor),
            highlighterCanvas.bottomAnchor.constraint(equalTo: bottomAnchor),

            inkCanvas.leadingAnchor.constraint(equalTo: leadingAnchor),
            inkCanvas.trailingAnchor.constraint(equalTo: trailingAnchor),
            inkCanvas.topAnchor.constraint(equalTo: topAnchor),
            inkCanvas.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        highlighterCanvas.delegate = self
        inkCanvas.delegate = self

        eraserGesture.isEnabled = false
        inkCanvas.addGestureRecognizer(eraserGesture)
    }

    @objc private func handleErase(_ gesture: ImmediateDragGestureRecognizer) {
        let location = gesture.location(in: inkCanvas)
        let scale = max(inkCanvas.zoomScale, 0.01)
        let point = CGPoint(x: location.x / scale, y: location.y / scale)
        switch gesture.state {
        case .began:
            isErasing = true
            lastErasePoint = point
            erase(from: point, to: point, radius: 18 / scale)
        case .changed:
            erase(from: lastErasePoint ?? point, to: point, radius: 18 / scale)
            lastErasePoint = point
        case .ended, .cancelled, .failed:
            isErasing = false
            lastErasePoint = nil
            onDrawingChanged?()
        default:
            break
        }
    }

    private func erase(from start: CGPoint, to end: CGPoint, radius: CGFloat) {
        if let ink = Self.drawing(inkCanvas.drawing, erasingFrom: start, to: end, radius: radius) {
            inkCanvas.drawing = ink
        }
        if let highlighter = Self.drawing(highlighterCanvas.drawing, erasingFrom: start, to: end, radius: radius) {
            highlighterCanvas.drawing = highlighter
        }
    }

    private static func drawing(_ drawing: PKDrawing, erasingFrom start: CGPoint, to end: CGPoint, radius: CGFloat) -> PKDrawing? {
        let sweep = CGRect(
            x: min(start.x, end.x), y: min(start.y, end.y),
            width: abs(end.x - start.x), height: abs(end.y - start.y)
        ).insetBy(dx: -radius, dy: -radius)
        let kept = drawing.strokes.filter { stroke in
            guard stroke.renderBounds.intersects(sweep) else { return true }
            return !stroke.path.interpolatedPoints(by: .distance(2)).contains { sample in
                let p = sample.location.applying(stroke.transform)
                let reach = radius + max(sample.size.width, sample.size.height) / 2
                return distance(from: p, toSegment: start, end) <= reach
            }
        }
        return kept.count == drawing.strokes.count ? nil : PKDrawing(strokes: kept)
    }

    private static func distance(from p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }

    private func configureCanvas(_ canvas: PKCanvasView) {
        canvas.translatesAutoresizingMaskIntoConstraints = false
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.contentSize = Self.canvasContentSize
        canvas.minimumZoomScale = 0.08
        canvas.maximumZoomScale = 16.0
        canvas.bouncesZoom = true
        canvas.showsHorizontalScrollIndicator = false
        canvas.showsVerticalScrollIndicator = false
        canvas.contentInsetAdjustmentBehavior = .never
        canvas.drawingPolicy = .anyInput
    }

    public func setPaper(style: PaperStyle, spacing: Float) {
        patternView.paperStyle = style
        patternView.paperSpacing = spacing
        updatePatternViewport()
    }

    public func loadStrokes(_ strokes: [Stroke], vpScale: Float, vpTx: Float, vpTy: Float) {
        isUpdatingInternally = true
        defer { isUpdatingInternally = false }

        loadedStrokeMap.removeAll()
        var inkPKStrokes: [PKStroke] = []
        var highlighterPKStrokes: [PKStroke] = []

        let originTransform = CGAffineTransform(translationX: Self.worldOrigin.x, y: Self.worldOrigin.y)

        for stroke in strokes {
            var pk = stroke.toPKStroke()
            // PKStroke.transform = strokeToWorld translated by +worldOrigin
            let fullTransform = pk.transform.concatenating(originTransform)
            pk = PKStroke(ink: pk.ink, path: pk.path, transform: fullTransform)

            let key = PKStrokeKey(pkStroke: pk)
            loadedStrokeMap[key] = stroke

            if stroke.brushKind == .highlighter {
                highlighterPKStrokes.append(pk)
            } else {
                inkPKStrokes.append(pk)
            }
        }

        inkCanvas.drawing = PKDrawing(strokes: inkPKStrokes)
        highlighterCanvas.drawing = PKDrawing(strokes: highlighterPKStrokes)

        applyViewport(scale: vpScale, tx: vpTx, ty: vpTy)
    }

    public func applyViewport(scale: Float, tx: Float, ty: Float) {
        let clampedScale = CGFloat(min(max(scale, 0.08), 16.0))
        let offset = ViewportMapping.contentOffset(
            scale: Float(clampedScale),
            tx: tx,
            ty: ty,
            originX: Double(Self.worldOrigin.x),
            originY: Double(Self.worldOrigin.y)
        )
        let pt = CGPoint(x: offset.offsetX, y: offset.offsetY)

        isInitializingViewport = true
        isSyncingViewport = true
        defer {
            isInitializingViewport = false
            isSyncingViewport = false
        }

        inkCanvas.zoomScale = clampedScale
        inkCanvas.contentOffset = pt

        highlighterCanvas.zoomScale = clampedScale
        highlighterCanvas.contentOffset = pt

        updatePatternViewport()
    }

    public func currentViewport() -> (scale: Float, tx: Float, ty: Float) {
        let activeCanvas = (activeTool == .highlighter) ? highlighterCanvas : inkCanvas
        let s = Float(activeCanvas.zoomScale)
        let off = activeCanvas.contentOffset
        let vp = ViewportMapping.viewportTranslation(
            scale: s,
            offsetX: Double(off.x),
            offsetY: Double(off.y),
            originX: Double(Self.worldOrigin.x),
            originY: Double(Self.worldOrigin.y)
        )
        return (scale: s, tx: vp.tx, ty: vp.ty)
    }

    public func resetCenter() {
        let boundsW = bounds.width > 0 ? bounds.width : 400
        let boundsH = bounds.height > 0 ? bounds.height : 800
        let tx = Float(boundsW * 0.5)
        let ty = Float(boundsH * 0.5)
        applyViewport(scale: 1.0, tx: tx, ty: ty)
        onViewportChanged?(1.0, tx, ty)
    }

    public func applyTool(tool: Tool, color: Int32, width: Float, fingerDraws: Bool) {
        let config = ToolConfig(tool: tool, color: color, width: width, fingerDraws: fingerDraws)
        guard config != toolConfig else { return }
        toolConfig = config
        self.activeTool = tool

        let uiCol = StrokeConversion.uiColor(fromArgb: color)
        let drawPolicy: PKCanvasViewDrawingPolicy = fingerDraws ? .anyInput : .pencilOnly

        highlighterCanvas.drawingPolicy = drawPolicy
        inkCanvas.drawingPolicy = drawPolicy

        inkCanvas.drawingGestureRecognizer.isEnabled = true
        highlighterCanvas.drawingGestureRecognizer.isEnabled = true
        eraserGesture.isEnabled = tool == .eraser
        let panTouches = fingerDraws ? 2 : 1
        inkCanvas.panGestureRecognizer.minimumNumberOfTouches = panTouches
        highlighterCanvas.panGestureRecognizer.minimumNumberOfTouches = panTouches

        switch tool {
        case .pen:
            highlighterCanvas.isUserInteractionEnabled = false
            inkCanvas.isUserInteractionEnabled = true
            inkCanvas.tool = PKInkingTool(.pen, color: uiCol, width: CGFloat(width))

        case .marker:
            highlighterCanvas.isUserInteractionEnabled = false
            inkCanvas.isUserInteractionEnabled = true
            inkCanvas.tool = PKInkingTool(.marker, color: uiCol, width: CGFloat(width))

        case .highlighter:
            inkCanvas.isUserInteractionEnabled = false
            highlighterCanvas.isUserInteractionEnabled = true
            let (r, g, b, _) = StrokeMath.rgbaComponents(fromArgb: color)
            let highColor = UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 0.4)
            highlighterCanvas.tool = PKInkingTool(.marker, color: highColor, width: CGFloat(width))

        case .eraser:
            highlighterCanvas.isUserInteractionEnabled = false
            inkCanvas.isUserInteractionEnabled = true
            inkCanvas.drawingGestureRecognizer.isEnabled = false
            eraserGesture.allowedTouchTypes = fingerDraws
                ? [NSNumber(value: UITouch.TouchType.direct.rawValue), NSNumber(value: UITouch.TouchType.pencil.rawValue)]
                : [NSNumber(value: UITouch.TouchType.pencil.rawValue)]

        case .pan:
            highlighterCanvas.isUserInteractionEnabled = false
            inkCanvas.isUserInteractionEnabled = true
            inkCanvas.drawingGestureRecognizer.isEnabled = false
            inkCanvas.panGestureRecognizer.minimumNumberOfTouches = 1

        default:
            highlighterCanvas.isUserInteractionEnabled = false
            inkCanvas.isUserInteractionEnabled = true
            inkCanvas.tool = PKInkingTool(.pen, color: uiCol, width: CGFloat(width))
        }
    }

    public func extractStrokes() -> [Stroke] {
        var result: [Stroke] = []
        let backTransform = CGAffineTransform(translationX: -Self.worldOrigin.x, y: -Self.worldOrigin.y)

        // Highlighter layer first (DrawOrder: highlighters underneath)
        for pkStroke in highlighterCanvas.drawing.strokes {
            let key = PKStrokeKey(pkStroke: pkStroke)
            if let existing = loadedStrokeMap[key] {
                result.append(existing)
            } else {
                let strokeWorldTransform = pkStroke.transform.concatenating(backTransform)
                let adjustedPK = PKStroke(ink: pkStroke.ink, path: pkStroke.path, transform: strokeWorldTransform)
                result.append(adjustedPK.toStroke(brushKind: .highlighter))
            }
        }

        // Ink layer
        for pkStroke in inkCanvas.drawing.strokes {
            let key = PKStrokeKey(pkStroke: pkStroke)
            if let existing = loadedStrokeMap[key] {
                result.append(existing)
            } else {
                let strokeWorldTransform = pkStroke.transform.concatenating(backTransform)
                let adjustedPK = PKStroke(ink: pkStroke.ink, path: pkStroke.path, transform: strokeWorldTransform)
                result.append(adjustedPK.toStroke(brushKind: nil))
            }
        }

        return result
    }

    public func renderThumbnail(size: CGSize = CGSize(width: 256, height: 256)) -> UIImage {
        let inkBounds = inkCanvas.drawing.bounds
        let highBounds = highlighterCanvas.drawing.bounds
        let combined = inkBounds.union(highBounds)

        let targetRect: CGRect
        if combined.isEmpty || combined.width <= 0 || combined.height <= 0 {
            let center = Self.worldOrigin
            let w: CGFloat = 800
            let h: CGFloat = 800
            targetRect = CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
        } else {
            targetRect = combined.insetBy(dx: -20, dy: -20)
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            TulisPalette.uiCanvas.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))

            let highImg = highlighterCanvas.drawing.image(from: targetRect, scale: 1.0)
            highImg.draw(in: CGRect(origin: .zero, size: size))

            let inkImg = inkCanvas.drawing.image(from: targetRect, scale: 1.0)
            inkImg.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func updatePatternViewport() {
        let vp = currentViewport()
        patternView.scale = vp.scale
        patternView.tx = vp.tx
        patternView.ty = vp.ty
        patternView.setNeedsDisplay()
    }

    // UIScrollViewDelegate
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !isSyncingViewport else { return }
        isSyncingViewport = true
        defer { isSyncingViewport = false }

        if scrollView === inkCanvas {
            highlighterCanvas.contentOffset = inkCanvas.contentOffset
        } else if scrollView === highlighterCanvas {
            inkCanvas.contentOffset = highlighterCanvas.contentOffset
        }

        updatePatternViewport()
        guard !isInitializingViewport else { return }
        let vp = currentViewport()
        onViewportChanged?(vp.scale, vp.tx, vp.ty)
    }

    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        guard !isSyncingViewport else { return }
        isSyncingViewport = true
        defer { isSyncingViewport = false }

        if scrollView === inkCanvas {
            highlighterCanvas.zoomScale = inkCanvas.zoomScale
            highlighterCanvas.contentOffset = inkCanvas.contentOffset
        } else if scrollView === highlighterCanvas {
            inkCanvas.zoomScale = highlighterCanvas.zoomScale
            inkCanvas.contentOffset = highlighterCanvas.contentOffset
        }

        updatePatternViewport()
        guard !isInitializingViewport else { return }
        let vp = currentViewport()
        onViewportChanged?(vp.scale, vp.tx, vp.ty)
    }

    // PKCanvasViewDelegate
    public func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard !isUpdatingInternally, !isErasing else { return }
        onDrawingChanged?()
    }
}

private struct ToolConfig: Equatable {
    let tool: Tool
    let color: Int32
    let width: Float
    let fingerDraws: Bool
}

public final class ImmediateDragGestureRecognizer: UIGestureRecognizer {
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard touches.count == 1, numberOfTouches <= 1 else {
            state = state == .possible ? .failed : .cancelled
            return
        }
        state = .began
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .changed
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .ended
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .cancelled
    }
}

public final class InfinitePaperPatternView: UIView {
    public var paperStyle: PaperStyle = .dots
    public var paperSpacing: Float = 28.0
    public var scale: Float = 1.0
    public var tx: Float = 0.0
    public var ty: Float = 0.0

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        isOpaque = false
    }

    public override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        guard paperStyle != .plain else { return }

        let s = CGFloat(scale)
        let stepScreen = CGFloat(max(paperSpacing, 12.0)) * s
        // Lewati gambar jika jarak di layar < 4 px
        guard stepScreen >= 4.0 else { return }

        let dotColor = UIColor(red: 43/255, green: 39/255, blue: 36/255, alpha: 0.18)
        let lineColor = UIColor(red: 43/255, green: 39/255, blue: 36/255, alpha: 0.12)

        let originScreen = ViewportMapping.worldToScreen(worldX: 10.0, worldY: 14.0, scale: scale, tx: tx, ty: ty)

        let startScreenX = originScreen.screenX.truncatingRemainder(dividingBy: Double(stepScreen))
        let firstX = startScreenX < 0 ? startScreenX + Double(stepScreen) : startScreenX

        let startScreenY = originScreen.screenY.truncatingRemainder(dividingBy: Double(stepScreen))
        let firstY = startScreenY < 0 ? startScreenY + Double(stepScreen) : startScreenY

        switch paperStyle {
        case .plain:
            break
        case .dots:
            ctx.setFillColor(dotColor.cgColor)
            var y = CGFloat(firstY)
            while y <= rect.maxY {
                var x = CGFloat(firstX)
                while x <= rect.maxX {
                    ctx.fillEllipse(in: CGRect(x: x - 1.0, y: y - 1.0, width: 2.0, height: 2.0))
                    x += stepScreen
                }
                y += stepScreen
            }
        case .grid:
            ctx.setStrokeColor(lineColor.cgColor)
            ctx.setLineWidth(1.0)
            var x = CGFloat(firstX)
            while x <= rect.maxX {
                ctx.move(to: CGPoint(x: x, y: rect.minY))
                ctx.addLine(to: CGPoint(x: x, y: rect.maxY))
                x += stepScreen
            }
            var y = CGFloat(firstY)
            while y <= rect.maxY {
                ctx.move(to: CGPoint(x: rect.minX, y: y))
                ctx.addLine(to: CGPoint(x: rect.maxX, y: y))
                y += stepScreen
            }
            ctx.strokePath()
        case .lines:
            ctx.setStrokeColor(lineColor.cgColor)
            ctx.setLineWidth(1.0)
            var y = CGFloat(firstY)
            while y <= rect.maxY {
                ctx.move(to: CGPoint(x: rect.minX, y: y))
                ctx.addLine(to: CGPoint(x: rect.maxX, y: y))
                y += stepScreen
            }
            ctx.strokePath()
        }
    }
}

public struct PKStrokeKey: Hashable, Sendable {
    public let count: Int
    public let firstX: Int
    public let firstY: Int
    public let lastX: Int
    public let lastY: Int

    public init(pkStroke: PKStroke) {
        let path = pkStroke.path
        self.count = path.count
        if let first = path.first {
            self.firstX = Int((first.location.x * 10).rounded())
            self.firstY = Int((first.location.y * 10).rounded())
        } else {
            self.firstX = 0
            self.firstY = 0
        }
        if let last = path.last {
            self.lastX = Int((last.location.x * 10).rounded())
            self.lastY = Int((last.location.y * 10).rounded())
        } else {
            self.lastX = 0
            self.lastY = 0
        }
    }
}
#endif
