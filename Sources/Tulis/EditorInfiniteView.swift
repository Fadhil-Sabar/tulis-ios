#if canImport(UIKit)
import SwiftUI
import TulisCore

public struct EditorInfiniteView: View {
    @ObservedObject var viewModel: EditorViewModel
    @Environment(\.scenePhase) private var scenePhase

    public init(viewModel: EditorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            CanvasRepresentable(editorState: viewModel)
                .ignoresSafeArea()
                .allowsHitTesting(viewModel.loadError == nil)

            if let message = viewModel.loadError {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Color(TulisPalette.uiInk))
                    .padding(12)
                    .background(Color(TulisPalette.uiCard))
                    .frame(maxWidth: 360)
                    .padding(.top, 64)
                    .frame(maxHeight: .infinity, alignment: .top)
            }

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                HStack {
                    centerButton
                    Spacer()
                    zoomIndicator
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()

                if viewModel.showToolOptions {
                    toolOptionsPopover
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                bottomToolbar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background || newPhase == .inactive {
                viewModel.saveNow()
                viewModel.saveThumbnail()
            }
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "book.closed")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(uiColor: TulisPalette.uiInk))

                Text(viewModel.notebookMeta.title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(uiColor: TulisPalette.uiInk))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Color(uiColor: TulisPalette.uiCard))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(uiColor: TulisPalette.uiInk), lineWidth: 2)
            )

            Spacer()

            HStack(spacing: 2) {
                Button {
                    viewModel.performUndo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(uiColor: TulisPalette.uiInk))
                        .frame(width: 44, height: 44)
                }
                .disabled(!viewModel.canUndo)
                .opacity(viewModel.canUndo ? 1.0 : 0.35)

                Button {
                    viewModel.performRedo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(uiColor: TulisPalette.uiInk))
                        .frame(width: 44, height: 44)
                }
                .disabled(!viewModel.canRedo)
                .opacity(viewModel.canRedo ? 1.0 : 0.35)
            }
            .padding(.horizontal, 4)
            .frame(height: 44)
            .background(Color(uiColor: TulisPalette.uiCard))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(uiColor: TulisPalette.uiInk), lineWidth: 2)
            )
        }
    }

    private var centerButton: some View {
        Button {
            viewModel.resetCenter()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "scope")
                    .font(.system(size: 16, weight: .bold))
                Text("Pusatkan")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
            }
            .foregroundColor(Color(uiColor: TulisPalette.uiInk))
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Color(uiColor: TulisPalette.uiCard))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(uiColor: TulisPalette.uiInk), lineWidth: 2)
            )
        }
    }

    private var zoomIndicator: some View {
        Button {
            viewModel.resetCenter()
        } label: {
            Text("\(viewModel.zoomPercentage)%")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(Color(uiColor: TulisPalette.uiInk))
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(Color(uiColor: TulisPalette.uiCard))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(uiColor: TulisPalette.uiInk), lineWidth: 2)
                )
        }
    }

    private var bottomToolbar: some View {
        HStack(spacing: 6) {
            toolButton(title: "Pena", systemImage: "pencil.tip", tool: .pen)
            toolButton(title: "Spidol", systemImage: "paintbrush.pointed", tool: .marker)
            toolButton(title: "Stabilo", systemImage: "highlighter", tool: .highlighter)
            toolButton(title: "Hapus", systemImage: "eraser", tool: .eraser)
            toolButton(title: "Geser", systemImage: "hand.draw", tool: .pan)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(uiColor: TulisPalette.uiCard))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(uiColor: TulisPalette.uiInk), lineWidth: 2)
        )
    }

    private func toolButton(title: String, systemImage: String, tool: Tool) -> some View {
        let isSelected = viewModel.activeTool == tool
        return Button {
            viewModel.selectTool(tool)
        } label: {
            VStack(spacing: 2) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(uiColor: TulisPalette.uiInk))
                        .frame(width: 28, height: 28)

                    if (tool == .pen || tool == .marker || tool == .highlighter) {
                        Circle()
                            .fill(Color(uiColor: StrokeConversion.uiColor(fromArgb: ToolPreferences.color(for: tool))))
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color(uiColor: TulisPalette.uiInk), lineWidth: 1))
                            .offset(x: 4, y: -2)
                    }
                }

                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(uiColor: TulisPalette.uiInk))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(isSelected ? Color(uiColor: TulisPalette.uiYellow) : Color.clear)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(uiColor: TulisPalette.uiInk) : Color.clear, lineWidth: isSelected ? 2 : 0)
            )
        }
    }

    private var toolOptionsPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Warna")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(Color(uiColor: TulisPalette.uiInkSoft))

            HStack(spacing: 12) {
                ForEach(TulisPalette.colors, id: \.self) { colorArgb in
                    let isChosen = (viewModel.currentColor == colorArgb)
                    Button {
                        viewModel.setColor(colorArgb)
                    } label: {
                        Circle()
                            .fill(Color(uiColor: StrokeConversion.uiColor(fromArgb: colorArgb)))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(Color(uiColor: TulisPalette.uiInk), lineWidth: isChosen ? 3 : 1)
                            )
                            .overlay(
                                isChosen ?
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .padding(2) : nil
                            )
                    }
                }
            }

            Text("Ketebalan")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(Color(uiColor: TulisPalette.uiInkSoft))
                .padding(.top, 4)

            HStack(spacing: 12) {
                Slider(
                    value: Binding(
                        get: { Double(viewModel.currentWidth) },
                        set: { viewModel.setWidth(Float($0)) }
                    ),
                    in: Double(ToolPreferences.widthRange(for: viewModel.activeTool).lowerBound)...Double(ToolPreferences.widthRange(for: viewModel.activeTool).upperBound)
                )
                .tint(Color(uiColor: TulisPalette.uiInk))

                Text(String(format: "%.1f", viewModel.currentWidth))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(uiColor: TulisPalette.uiInk))
                    .frame(width: 38, alignment: .trailing)
            }

            Divider()
                .padding(.vertical, 2)

            Toggle(isOn: $viewModel.fingerDraws) {
                Text("Jari bisa menggambar")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(Color(uiColor: TulisPalette.uiInk))
            }
            .tint(Color(uiColor: TulisPalette.uiYellow))
        }
        .padding(14)
        .background(Color(uiColor: TulisPalette.uiCard))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(uiColor: TulisPalette.uiInk), lineWidth: 2)
        )
    }
}
#endif
