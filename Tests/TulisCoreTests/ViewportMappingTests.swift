import Foundation
import Testing
@testable import TulisCore

@Suite struct ViewportMappingTests {
    @Test func contentOffsetDanViewportTranslationRoundTrip() {
        let scale: Float = 1.5
        let tx: Float = 250.0
        let ty: Float = -120.0

        let offset = ViewportMapping.contentOffset(scale: scale, tx: tx, ty: ty)
        let recovered = ViewportMapping.viewportTranslation(
            scale: scale,
            offsetX: offset.offsetX,
            offsetY: offset.offsetY
        )

        #expect(abs(recovered.tx - tx) < 0.001)
        #expect(abs(recovered.ty - ty) < 0.001)
    }

    @Test func worldScreenMappingConsistency() {
        let scale: Float = 2.0
        let tx: Float = 100.0
        let ty: Float = 50.0

        let worldX = 15.0
        let worldY = 30.0

        let screen = ViewportMapping.worldToScreen(
            worldX: worldX,
            worldY: worldY,
            scale: scale,
            tx: tx,
            ty: ty
        )
        #expect(screen.screenX == 15.0 * 2.0 + 100.0) // 130
        #expect(screen.screenY == 30.0 * 2.0 + 50.0)  // 110

        let worldRecovered = ViewportMapping.screenToWorld(
            screenX: screen.screenX,
            screenY: screen.screenY,
            scale: scale,
            tx: tx,
            ty: ty
        )
        #expect(abs(worldRecovered.worldX - worldX) < 0.001)
        #expect(abs(worldRecovered.worldY - worldY) < 0.001)

        // Verifikasi bahwa screen mapping konsisten dengan contentOffset pada PKCanvasView
        // Di PKCanvasView: titik konten = world + worldOrigin
        // screen = (contentPt * scale) - contentOffset
        let offset = ViewportMapping.contentOffset(scale: scale, tx: tx, ty: ty)
        let contentX = worldX + ViewportMapping.defaultWorldOriginX
        let contentY = worldY + ViewportMapping.defaultWorldOriginY
        let pkScreenX = contentX * Double(scale) - offset.offsetX
        let pkScreenY = contentY * Double(scale) - offset.offsetY

        #expect(abs(pkScreenX - screen.screenX) < 0.001)
        #expect(abs(pkScreenY - screen.screenY) < 0.001)
    }
}
