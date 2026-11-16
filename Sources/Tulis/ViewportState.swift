#if canImport(UIKit)
import CoreGraphics
import Foundation

public struct ViewportState: Equatable, Sendable {
    public var scale: Float = 1.0
    public var tx: Float = 0.0
    public var ty: Float = 0.0

    public init(scale: Float = 1.0, tx: Float = 0.0, ty: Float = 0.0) {
        self.scale = min(max(scale, 0.08), 16.0)
        self.tx = tx
        self.ty = ty
    }

    public mutating func set(scale: Float, tx: Float, ty: Float) {
        self.scale = min(max(scale, 0.08), 16.0)
        self.tx = tx
        self.ty = ty
    }

    public mutating func pan(dx: Float, dy: Float) {
        if dx == 0 && dy == 0 { return }
        self.tx += dx
        self.ty += dy
    }

    public mutating func zoomAt(factor: Float, fx: Float, fy: Float) {
        if factor == 1.0 { return }
        let oldScale = scale
        let targetScale = min(max(oldScale * factor, 0.08), 16.0)
        if targetScale == oldScale { return }
        let effectiveFactor = targetScale / oldScale
        let newTx = fx - (fx - tx) * effectiveFactor
        let newTy = fy - (fy - ty) * effectiveFactor
        self.scale = targetScale
        self.tx = newTx
        self.ty = newTy
    }

    public func worldToScreen(point: CGPoint) -> CGPoint {
        CGPoint(
            x: CGFloat(scale) * point.x + CGFloat(tx),
            y: CGFloat(scale) * point.y + CGFloat(ty)
        )
    }

    public func screenToWorld(point: CGPoint) -> CGPoint {
        let s = CGFloat(scale)
        guard s > 0 else { return point }
        return CGPoint(
            x: (point.x - CGFloat(tx)) / s,
            y: (point.y - CGFloat(ty)) / s
        )
    }

    public mutating func resetCenter(viewW: Float, viewH: Float) {
        self.scale = 1.0
        self.tx = viewW * 0.5
        self.ty = viewH * 0.5
    }
}
#endif
