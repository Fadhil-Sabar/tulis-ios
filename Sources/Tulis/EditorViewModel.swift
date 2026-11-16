#if canImport(UIKit)
import Combine
import CoreGraphics
import Foundation
import os.log
import PencilKit
import SwiftUI
import TulisCore
import UIKit

private let logger = Logger(subsystem: "io.github.fadhil-sabar.tulis", category: "Editor")

@MainActor
public final class EditorViewModel: ObservableObject {
    public let repository: NotebookRepository
    public let pageStore: PageStore

    @Published public var notebookMeta: NotebookMeta
    @Published public var activeTool: Tool = .pen
    @Published public var currentWidth: Float = 4.0
    @Published public var currentColor: Int32 = TulisPalette.ink
    @Published public var fingerDraws: Bool = true
    @Published public var showToolOptions: Bool = false
    @Published public var canUndo: Bool = false
    @Published public var canRedo: Bool = false
    @Published public var zoomPercentage: Int = 100
    @Published public private(set) var loadError: String?
    private var loadedTexts: [TextItem] = []

    public weak var canvasContainerView: InfiniteCanvasContainerView?
    public let undoManager = UnifiedUndoManager()

    // Serial queue untuk operasi simpan ke disk (save berurutan, tidak paralel)
    private let saveQueue = DispatchQueue(label: "io.github.fadhil-sabar.tulis.saveQueue", qos: .utility)

    private var autoSaveTask: Task<Void, Never>?
    private var isContentDirty: Bool = false
    private var isMetaDirty: Bool = false
    private var isInitialLoaded: Bool = false
    private var lastSavedStrokes: [Stroke] = []

    public init(repository: NotebookRepository, pageStore: PageStore, meta: NotebookMeta) {
        self.repository = repository
        self.pageStore = pageStore
        self.notebookMeta = meta

        self.currentWidth = ToolPreferences.width(for: .pen)
        self.currentColor = ToolPreferences.color(for: .pen)
        self.zoomPercentage = Int((meta.vpScale * 100.0).rounded())

        self.undoManager.onChange = { [weak self] in
            guard let self = self else { return }
            self.canUndo = self.undoManager.canUndo
            self.canRedo = self.undoManager.canRedo
        }
    }

    public func selectTool(_ tool: Tool) {
        if activeTool == tool && (tool == .pen || tool == .marker || tool == .highlighter) {
            showToolOptions.toggle()
        } else {
            activeTool = tool
            showToolOptions = false
            currentWidth = ToolPreferences.width(for: tool)
            currentColor = ToolPreferences.color(for: tool)
        }
    }

    public func setColor(_ color: Int32) {
        currentColor = color
        ToolPreferences.setColor(color, for: activeTool)
    }

    public func setWidth(_ width: Float) {
        currentWidth = width
        ToolPreferences.setWidth(width, for: activeTool)
    }

    public func loadInitialContent(into view: InfiniteCanvasContainerView) {
        guard !isInitialLoaded else { return }
        isInitialLoaded = true

        let pageContent: PageContent?
        do {
            pageContent = try pageStore.load(notebookId: notebookMeta.id, pageIndex: 0)
        } catch {
            pageContent = nil
            loadError = "Halaman ini tidak bisa dibuka di versi iOS. Catatan dibuka hanya baca supaya isinya tidak tertimpa."
            logger.error("Gagal membuka halaman \(self.notebookMeta.id, privacy: .public): \(String(describing: error), privacy: .public)")
        }
        let strokes = pageContent?.strokes ?? []
        loadedTexts = pageContent?.texts ?? []
        lastSavedStrokes = strokes

        view.loadStrokes(
            strokes,
            vpScale: notebookMeta.vpScale,
            vpTx: notebookMeta.vpTx,
            vpTy: notebookMeta.vpTy
        )

        view.applyTool(
            tool: activeTool,
            color: currentColor,
            width: currentWidth,
            fingerDraws: fingerDraws
        )

        undoManager.setInitialSnapshot(ink: view.inkCanvas.drawing, highlighter: view.highlighterCanvas.drawing)
    }

    public func handleDrawingChanged(from view: InfiniteCanvasContainerView) {
        isContentDirty = true
        isMetaDirty = true
        undoManager.recordDrawingChange(currentInk: view.inkCanvas.drawing, currentHighlighter: view.highlighterCanvas.drawing)
        scheduleAutosave()
    }

    public func handleViewportChanged(scale: Float, tx: Float, ty: Float) {
        let percentage = Int((scale * 100.0).rounded())
        if percentage != zoomPercentage {
            zoomPercentage = percentage
        }
        isMetaDirty = true
        scheduleAutosave()
    }

    public func scheduleAutosave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 detik debounce
            guard !Task.isCancelled else { return }
            self.saveNow()
        }
    }

    public func saveNow() {
        guard let view = canvasContainerView, loadError == nil else { return }

        let vp = view.currentViewport()
        notebookMeta.vpScale = vp.scale
        notebookMeta.vpTx = vp.tx
        notebookMeta.vpTy = vp.ty

        let shouldSaveContent = isContentDirty
        var contentToSave: PageContent? = nil

        if shouldSaveContent {
            let currentStrokes = view.extractStrokes()
            if currentStrokes != lastSavedStrokes {
                contentToSave = PageContent(strokes: currentStrokes, texts: loadedTexts)
                lastSavedStrokes = currentStrokes
                let now = Int64(Date().timeIntervalSince1970 * 1000)
                notebookMeta.updatedAt = now
            }
            isContentDirty = false
        }

        let meta = self.notebookMeta
        let finalContentToSave = contentToSave
        isMetaDirty = false

        saveQueue.async { [pageStore = self.pageStore, repository = self.repository] in
            do {
                if let content = finalContentToSave {
                    try pageStore.save(notebookId: meta.id, pageIndex: 0, content: content)
                }
                try repository.writeMeta(meta: meta)
            } catch {
                logger.error("Gagal menyimpan notebook \(meta.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                print("Gagal menyimpan notebook \(meta.id): \(error)")
            }
        }
    }

    public func saveThumbnail() {
        guard let view = canvasContainerView, loadError == nil else { return }
        let thumbImg = view.renderThumbnail()
        guard let thumbData = thumbImg.pngData() else { return }

        let metaId = notebookMeta.id
        saveQueue.async { [repository = self.repository] in
            do {
                try repository.writeThumb(id: metaId, data: thumbData)
            } catch {
                logger.error("Gagal menyimpan thumbnail \(metaId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                print("Gagal menyimpan thumbnail \(metaId): \(error)")
            }
        }
    }

    public func performUndo() {
        guard let view = canvasContainerView else { return }
        if let target = undoManager.undo(
            currentInk: view.inkCanvas.drawing,
            currentHighlighter: view.highlighterCanvas.drawing
        ) {
            view.isUpdatingInternally = true
            view.inkCanvas.drawing = target.inkDrawing
            view.highlighterCanvas.drawing = target.highlighterDrawing
            view.isUpdatingInternally = false

            isContentDirty = true
            isMetaDirty = true
            scheduleAutosave()
        }
    }

    public func performRedo() {
        guard let view = canvasContainerView else { return }
        if let target = undoManager.redo(
            currentInk: view.inkCanvas.drawing,
            currentHighlighter: view.highlighterCanvas.drawing
        ) {
            view.isUpdatingInternally = true
            view.inkCanvas.drawing = target.inkDrawing
            view.highlighterCanvas.drawing = target.highlighterDrawing
            view.isUpdatingInternally = false

            isContentDirty = true
            isMetaDirty = true
            scheduleAutosave()
        }
    }

    public func resetCenter() {
        canvasContainerView?.resetCenter()
    }
}
#endif
