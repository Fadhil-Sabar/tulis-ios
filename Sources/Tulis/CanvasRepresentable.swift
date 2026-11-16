#if canImport(UIKit)
import CoreGraphics
import Foundation
import PencilKit
import SwiftUI
import TulisCore
import UIKit

public struct CanvasRepresentable: UIViewRepresentable {
    @ObservedObject var editorState: EditorViewModel

    public init(editorState: EditorViewModel) {
        self.editorState = editorState
    }

    public func makeUIView(context: Context) -> InfiniteCanvasContainerView {
        let view = InfiniteCanvasContainerView()

        view.setPaper(style: editorState.notebookMeta.paperStyle, spacing: editorState.notebookMeta.paperSpacing)

        view.onDrawingChanged = { [weak view] in
            guard let view = view else { return }
            editorState.handleDrawingChanged(from: view)
        }

        view.onViewportChanged = { scale, tx, ty in
            editorState.handleViewportChanged(scale: scale, tx: tx, ty: ty)
        }

        editorState.canvasContainerView = view
        editorState.loadInitialContent(into: view)

        return view
    }

    public func updateUIView(_ uiView: InfiniteCanvasContainerView, context: Context) {
        uiView.applyTool(
            tool: editorState.activeTool,
            color: editorState.currentColor,
            width: editorState.currentWidth,
            fingerDraws: editorState.fingerDraws
        )
    }
}
#endif
