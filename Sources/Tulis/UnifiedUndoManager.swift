#if canImport(UIKit)
import CoreGraphics
import Foundation
import PencilKit
import SwiftUI
import TulisCore
import UIKit

public struct UndoHistoryItem {
    public let inkDrawing: PKDrawing
    public let highlighterDrawing: PKDrawing

    public init(inkDrawing: PKDrawing, highlighterDrawing: PKDrawing) {
        self.inkDrawing = inkDrawing
        self.highlighterDrawing = highlighterDrawing
    }
}

@MainActor
public final class UnifiedUndoManager {
    private var undoStack: [UndoHistoryItem] = []
    private var redoStack: [UndoHistoryItem] = []
    public var lastSnapshot: UndoHistoryItem?

    public let maxHistoryDepth: Int = 100

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public var onChange: (() -> Void)?

    public init() {}

    public func setInitialSnapshot(ink: PKDrawing, highlighter: PKDrawing) {
        lastSnapshot = UndoHistoryItem(inkDrawing: ink, highlighterDrawing: highlighter)
        undoStack.removeAll()
        redoStack.removeAll()
        onChange?()
    }

    /// Dipanggil saat canvasViewDrawingDidChange:
    /// push lastSnapshot ke undo stack, update lastSnapshot = state sekarang, kosongkan redo stack.
    public func recordDrawingChange(currentInk: PKDrawing, currentHighlighter: PKDrawing) {
        if let prev = lastSnapshot {
            undoStack.append(prev)
            if undoStack.count > maxHistoryDepth {
                undoStack.removeFirst()
            }
        }
        lastSnapshot = UndoHistoryItem(inkDrawing: currentInk, highlighterDrawing: currentHighlighter)
        redoStack.removeAll()
        onChange?()
    }

    public func undo(currentInk: PKDrawing, currentHighlighter: PKDrawing) -> UndoHistoryItem? {
        guard let target = undoStack.popLast() else { return nil }
        redoStack.append(UndoHistoryItem(inkDrawing: currentInk, highlighterDrawing: currentHighlighter))
        if redoStack.count > maxHistoryDepth {
            redoStack.removeFirst()
        }
        lastSnapshot = target
        onChange?()
        return target
    }

    public func redo(currentInk: PKDrawing, currentHighlighter: PKDrawing) -> UndoHistoryItem? {
        guard let target = redoStack.popLast() else { return nil }
        undoStack.append(UndoHistoryItem(inkDrawing: currentInk, highlighterDrawing: currentHighlighter))
        if undoStack.count > maxHistoryDepth {
            undoStack.removeFirst()
        }
        lastSnapshot = target
        onChange?()
        return target
    }

    public func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        lastSnapshot = nil
        onChange?()
    }
}
#endif
