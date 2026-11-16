# Tulis untuk iOS

Versi iPhone dan iPad dari [Tulis](https://github.com/Fadhil-Sabar/tulis), aplikasi catatan tulisan tangan yang offline. Ditulis dengan Swift, SwiftUI, dan PencilKit.

> Masih tahap awal. Isinya sekarang baru kanvas PencilKit untuk menguji alur build dan instal.

## Build di Linux

Proyek ini berupa paket SwiftPM yang dibangun dengan [xtool](https://xtool.sh), jadi tidak perlu Mac.

1. Pasang xtool lalu jalankan `xtool setup`. Langkah ini meminta `Xcode.xip` dari situs developer Apple untuk mengambil SDK iOS, dan login Apple ID (akun gratis cukup).
2. Colok iPhone, aktifkan Developer Mode (Settings → Privacy & Security).
3. Jalankan `xtool dev`.

Dengan Apple ID gratis, signing berlaku 7 hari. Setelah itu aplikasi perlu di-sign ulang. Data tetap aman selama aplikasinya tidak dihapus.

Panduan penyiapan khusus Fedora (paket DNF, udev, SELinux, dan pemecahan masalah) didokumentasikan di [docs/dev-fedora.md](docs/dev-fedora.md).

Simulator iOS hanya ada di macOS. CI membangun aplikasi untuk simulator di runner macOS GitHub Actions.

## Test

```
swift test
```

Menjalankan test untuk `TulisCore` (model dan format file). Bisa di Linux.

## Rencana

1. Format `.tulis` v2 yang netral (titik mentah, tanpa encoding AndroidX Ink), dirancang di repo Android
2. MVP: satu notebook kanvas, pena dan penghapus, simpan dan buka
3. Baca dan tulis `.tulis` v2, diuji dengan file dari Android
4. Mode halaman, folder, vault Obsidian, ekspor PDF/PNG

## Lisensi

[Apache-2.0](LICENSE)
