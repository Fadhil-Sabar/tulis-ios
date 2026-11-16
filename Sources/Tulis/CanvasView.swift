#if canImport(UIKit)
import PencilKit
import SwiftUI

/// Kanvas PencilKit sementara untuk uji alur build dan instal.
/// Jari tetap bisa menggambar supaya bisa dicoba di iPhone.
struct CanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .label, width: 3)
        canvas.backgroundColor = .systemBackground
        canvas.delegate = context.coordinator
        canvas.drawing = drawing

        let picker = context.coordinator.toolPicker
        picker.setVisible(true, forFirstResponder: canvas)
        picker.addObserver(canvas)
        DispatchQueue.main.async { canvas.becomeFirstResponder() }
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: CanvasView
        let toolPicker = PKToolPicker()

        init(_ parent: CanvasView) { self.parent = parent }

        func canvasViewDrawingDidChange(_ canvas: PKCanvasView) {
            parent.drawing = canvas.drawing
        }
    }
}
#endif
