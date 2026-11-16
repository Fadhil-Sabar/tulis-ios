#if canImport(UIKit)
import PencilKit
import SwiftUI
import TulisCore

struct ContentView: View {
    @State private var drawing = PKDrawing()

    var body: some View {
        NavigationStack {
            CanvasView(drawing: $drawing)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Tulis")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Bersihkan", systemImage: "trash") {
                            drawing = PKDrawing()
                        }
                        .disabled(drawing.strokes.isEmpty)
                    }
                }
        }
    }
}
#endif
