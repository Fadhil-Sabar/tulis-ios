#if canImport(UIKit)
import SwiftUI
import TulisCore

struct ContentView: View {
    @StateObject private var appState = AppBootstrap()

    var body: some View {
        Group {
            if let vm = appState.editorViewModel {
                EditorInfiniteView(viewModel: vm)
            } else {
                ZStack {
                    Color(uiColor: TulisPalette.uiCanvas)
                        .ignoresSafeArea()
                    ProgressView("Memuat catatan...")
                        .tint(Color(uiColor: TulisPalette.uiInk))
                        .foregroundColor(Color(uiColor: TulisPalette.uiInk))
                }
            }
        }
        .onAppear {
            appState.bootstrap()
        }
    }
}

@MainActor
final class AppBootstrap: ObservableObject {
    @Published var editorViewModel: EditorViewModel?

    func bootstrap() {
        guard editorViewModel == nil else { return }

        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dataDir = appSupport.appendingPathComponent("Tulis", isDirectory: true)

        try? fm.createDirectory(at: dataDir, withIntermediateDirectories: true)

        let repo = NotebookRepository(rootURL: dataDir)
        let store = BinaryPageStore(repository: repo)

        let notebooks = repo.list()
        let latestInfinite = notebooks.first { $0.mode == .infinite }

        let meta: NotebookMeta
        if let existing = latestInfinite {
            meta = existing
        } else {
            do {
                meta = try repo.create(mode: .infinite)
            } catch {
                meta = NotebookMeta(
                    id: UUID().uuidString,
                    title: "Catatan Baru",
                    mode: .infinite,
                    pageCount: 1,
                    updatedAt: Int64(Date().timeIntervalSince1970 * 1000)
                )
            }
        }

        self.editorViewModel = EditorViewModel(repository: repo, pageStore: store, meta: meta)
    }
}
#endif
