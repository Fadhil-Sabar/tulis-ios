/// Padanan enum di `model/Models.kt` versi Android.
/// Urutan case harus sama karena nilainya ditulis sebagai ordinal ke file.

public enum NoteMode: Int, CaseIterable, Sendable {
    case infinite, paged
}

public enum PaperStyle: Int, CaseIterable, Sendable {
    case plain, dots, grid, lines
}

public enum BrushKind: Int, CaseIterable, Sendable {
    case pen, marker, highlighter
}

public enum PageOrientation: Int, CaseIterable, Sendable {
    case portrait, landscape
}
