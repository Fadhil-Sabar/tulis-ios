import Foundation

public enum ViewportMapping {
    public static let defaultWorldOriginX: Double = 100_000.0
    public static let defaultWorldOriginY: Double = 100_000.0

    /// Menghitung contentOffset PKCanvasView dari viewport Android (vpScale, vpTx, vpTy).
    /// Rumus: contentOffset = worldOrigin * scale - t
    public static func contentOffset(
        scale: Float,
        tx: Float,
        ty: Float,
        originX: Double = defaultWorldOriginX,
        originY: Double = defaultWorldOriginY
    ) -> (offsetX: Double, offsetY: Double) {
        let s = Double(scale)
        let ox = originX * s - Double(tx)
        let oy = originY * s - Double(ty)
        return (ox, oy)
    }

    /// Menghitung viewport Android (vpTx, vpTy) dari contentOffset dan zoomScale PKCanvasView.
    /// Rumus: t = worldOrigin * scale - contentOffset
    public static func viewportTranslation(
        scale: Float,
        offsetX: Double,
        offsetY: Double,
        originX: Double = defaultWorldOriginX,
        originY: Double = defaultWorldOriginY
    ) -> (tx: Float, ty: Float) {
        let s = Double(scale)
        let tx = Float(originX * s - offsetX)
        let ty = Float(originY * s - offsetY)
        return (tx, ty)
    }

    /// Titik dunia ke koordinat layar: screen = world * scale + t
    public static func worldToScreen(
        worldX: Double,
        worldY: Double,
        scale: Float,
        tx: Float,
        ty: Float
    ) -> (screenX: Double, screenY: Double) {
        let s = Double(scale)
        let sx = worldX * s + Double(tx)
        let sy = worldY * s + Double(ty)
        return (sx, sy)
    }

    /// Titik layar ke koordinat dunia: world = (screen - t) / scale
    public static func screenToWorld(
        screenX: Double,
        screenY: Double,
        scale: Float,
        tx: Float,
        ty: Float
    ) -> (worldX: Double, worldY: Double) {
        let s = Double(scale)
        guard s > 0 else { return (screenX, screenY) }
        let wx = (screenX - Double(tx)) / s
        let wy = (screenY - Double(ty)) / s
        return (wx, wy)
    }
}
