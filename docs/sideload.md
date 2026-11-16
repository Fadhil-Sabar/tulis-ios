# Memasang Tulis lewat SideStore

Setiap push ke `main` dan setiap pull request menghasilkan `Tulis.ipa` tanpa signing sebagai artifact CI. SideStore men-sign ulang IPA itu dengan Apple ID kamu di iPhone, jadi pemasangan dan perpanjangan 7 hari bisa dilakukan tanpa kabel.

## Cara CI membuat IPA

Dua job di `.github/workflows/ci.yml`:

1. `xcodeproj` (Linux, container `swift:6.1`): mengunduh AppImage xtool (versi di `XTOOL_VERSION`) lalu menjalankan `xtool dev generate-xcode-project`. Langkah ini tidak butuh SDK iOS. Hasilnya folder `xtool/` diunggah sebagai artifact.
2. `ipa` (macOS): menjalankan `xcodebuild` tanpa signing dari project itu, lalu mengemas `Payload/<app>.app` jadi `Tulis.ipa`.

Alasan pembagiannya: paket ini berupa SwiftPM dengan library product, jadi `xcodebuild` langsung tidak menghasilkan `.app`, dan xtool yang menyusun target aplikasinya. xtool versi macOS macet tanpa output di runner GitHub, sedangkan versi Linux jalan normal. Build di Linux saja juga tidak bisa karena butuh `Xcode.xip` yang tidak boleh disebarkan.

## Prasyarat

- SideStore sudah terpasang dan aktif di iPhone, termasuk pairing file dan VPN/LocalDevVPN-nya. Ikuti panduan resmi di [docs.sidestore.io](https://docs.sidestore.io).
- Apple ID yang dipakai SideStore. Akun gratis cukup, tetapi maksimal 3 aplikasi aktif dan signing berlaku 7 hari.

## Langkah

1. Buka tab Actions di GitHub, pilih run CI terbaru yang lulus di `main`.
2. Unduh artifact `Tulis.ipa`. GitHub membungkus artifact dalam zip, jadi ekstrak dulu sampai dapat `Tulis.ipa`.
3. Simpan `Tulis.ipa` ke aplikasi Files di iPhone, misalnya dengan mengunduh artifact langsung dari Safari di iPhone atau lewat iCloud Drive.
4. Di SideStore, buka tab My Apps, ketuk tombol `+`, lalu pilih `Tulis.ipa`.
5. Tunggu sampai SideStore selesai men-sign dan memasang. Ikon Tulis muncul di home screen.

## Perpanjangan

Buka SideStore lalu ketuk Refresh All sebelum 7 hari habis. Data catatan tetap aman selama aplikasinya tidak dihapus.

## Catatan

- Bundle ID di IPA adalah `io.github.fadhil-sabar.tulis`. SideStore bisa menambahkan akhiran Team ID secara otomatis.
- Kalau Tulis juga pernah dipasang lewat `xtool dev`, hapus salah satunya dulu supaya tidak bentrok signing.
- Langkah SideStore di atas belum diverifikasi di iPhone.
