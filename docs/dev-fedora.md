# Panduan Pengembangan di Fedora dengan xtool

Panduan ini mendokumentasikan langkah penyiapan lingkungan pengembangan aplikasi iOS di Fedora Linux (diuji pada Fedora 44 x86_64) menggunakan `xtool` dan Swift toolchain tanpa membutuhkan komputer macOS.

## 1. Prasyarat

Sebelum memulai, pastikan hal-hal berikut telah tersedia:

1. **Distribusi Linux**: Fedora 44 (x86_64 atau aarch64).
2. **Swift Toolchain**: versinya harus sama dengan Swift di Xcode yang dipakai. Xcode 27.1 memakai Swift 6.4, jadi pasang Swift 6.4.x via `swiftly` ke `$HOME` dan jadikan default global (`swiftly use -g 6.4.2`). Lihat bagian 10 kalau versinya tidak cocok.
3. **xtool**: Utilitas CLI pengganti Xcode untuk Linux (terpasang di `~/.local/bin/xtool`).
4. **Xcode.xip**: Berkas arsip Xcode resmi (disarankan Xcode 27.1) yang diunduh langsung lewat browser dari [Apple Developer Downloads](https://developer.apple.com/download/all/?q=Xcode) setelah masuk dengan Apple ID.
5. **Akun Apple ID**: Akun standar/gratis sudah mencukupi untuk pengembangan pribadi dan instalasi ke iPhone sendiri (sertifikat berlaku 7 hari sebelum perlu di-sign ulang).
6. **Perangkat iOS**: iPhone fisik dengan iOS 17 atau lebih baru, kabel USB, dan Developer Mode aktif.

## 2. Kebutuhan Paket Sistem (DNF)

Komunikasi antara Linux dan iPhone memerlukan daemon `usbmuxd` serta perkakas pembantu dari proyek `libimobiledevice`.

### Status paket saat ini di Fedora:
- `usbmuxd`: **Sudah terpasang** di `/usr/bin/usbmuxd` (menyertakan aturan udev dan berkas unit systemd).
- `fuse` / `fuse-libs`: **Sudah terpasang** di Fedora untuk eksekusi berkas AppImage.
- `libimobiledevice-utils`: **Belum terpasang** (diperlukan untuk perintah `ideviceinfo`, `idevice_id`, `idevicepair`, dan `idevicedevmodectl`).

### Perintah instalasi paket dnf:
Jalankan perintah berikut di terminal (memerlukan hak akses `sudo`):

```bash
sudo dnf install -y libimobiledevice-utils
```

## 3. Pemasangan xtool

`xtool` dapat dipasang di direktori pengguna tanpa hak akses `sudo` (`~/.local/bin/xtool`).

### Langkah pemasangan yang telah diterapkan:
1. Mengunduh rilis biner resmi `xtool-x86_64.AppImage` (versi 1.24.0) dari repositori GitHub `xtool-org/xtool`.
2. Menyimpan AppImage di `~/.local/lib/xtool/` dan mengekstrak isinya ke `~/.local/lib/xtool/squashfs-root` agar eksekusi berlangsung instan dan tidak bergantung pada mount FUSE `/dev/fuse` (menghindari kendala izin `fusermount: Operation not permitted` di beberapa konfigurasi permission sandboxing).
3. Menyediakan skrip peluncur executable di `~/.local/bin/xtool`:
   ```bash
   #!/usr/bin/env bash
   if [ -x "$HOME/.local/lib/xtool/squashfs-root/usr/bin/xtool" ]; then
       exec "$HOME/.local/lib/xtool/squashfs-root/usr/bin/xtool" "$@"
   fi
   export APPIMAGE_EXTRACT_AND_RUN=1
   exec "$HOME/.local/lib/xtool/xtool-x86_64.AppImage" "$@"
   ```
4. Memastikan izin eksekusi aktif (`chmod +x ~/.local/bin/xtool`).
5. Memverifikasi dengan perintah:
   ```bash
   xtool --version
   # Output: xtool 1.24.0
   ```

## 4. Aturan udev dan usbmuxd Service

Paket `usbmuxd` di Fedora secara default telah menyediakan:
- Berkas udev rules di `/usr/lib/udev/rules.d/39-usbmuxd.rules`
- Berkas unit systemd di `/usr/lib/systemd/system/usbmuxd.service`

Aturan udev tersebut bertugas memicu `usbmuxd.service` secara otomatis saat iPhone dicolokkan ke port USB (`ENV{SYSTEMD_WANTS}="usbmuxd.service"`).

### Pengelolaan Service usbmuxd:
Jika saat perangkat dicolokkan `usbmuxd` tidak otomatis aktif, jalankan perintah berikut:

```bash
sudo systemctl enable --now usbmuxd
sudo systemctl status usbmuxd
```

Untuk memuat ulang aturan udev setelah instalasi paket:
```bash
sudo udevadm control --reload-rules && sudo udevadm trigger
```

## 5. Konfigurasi SELinux

Fedora 44 berjalan dengan SELinux aktif dalam mode `Enforcing` (kebijakan `targeted`).

- Daemon `usbmuxd` bawaan paket RPM Fedora sudah memiliki konteks keamanan yang valid (`usbmuxd_exec_t` dan `usbmuxd_t`).
- Akses perangkat USB dan socket domain `/var/run/usbmuxd` umumnya diizinkan untuk pengguna lokal.
- Jika terjadi kegagalan akses perangkat atau socket saat menjalankan `xtool dev` atau `ideviceinfo`, periksa apakah ada penolakan SELinux:
  ```bash
  sudo ausearch -m avc -ts recent
  ```
- Jika ditemukan penolakan AVC yang relevan, Anda dapat membuat modul izin menggunakan `audit2allow` atau menguji sementara dengan `sudo setenforce 0` untuk memastikan apakah kendala disebabkan oleh kebijakan SELinux.

## 6. Konfigurasi Awal (xtool setup)

Langkah ini dilakukan sekali secara interaktif oleh pengguna setelah berkas `Xcode.xip` selesai diunduh.

> Catatan: Jangan menjalankan `xtool setup` secara non-interaktif atau tanpa input pengguna karena perintah ini meminta interaksi terminal untuk otentikasi akun Apple dan penentuan lokasi file SDK.

Jalankan perintah:
```bash
xtool setup
```

### Tahapan dalam setup:
1. **Pilihan Login Apple ID**:
   - Pilih `1` (Password) untuk akun Apple ID biasa/gratis.
   - Masukkan alamat email Apple ID, kata sandi, dan kode Two-Factor Authentication (2FA) yang dikirim ke perangkat Apple Anda. Kredensial ini dikirim langsung ke server otentikasi Apple untuk membuat sertifikat penandatanganan aplikasi.
   - (Pilih `0` hanya jika Anda memiliki langganan berbayar Apple Developer Program dan menggunakan App Store Connect API Key).
2. **Ekstraksi SDK iOS**:
   - Saat diminta `Path to Xcode.xip:`, masukkan path absolut tempat berkas `Xcode.xip` berada, misalnya:
     `~/Downloads/Xcode_27.1.xip`
   - `xtool` akan memproses berkas tersebut untuk membuat Darwin Swift SDK dan memasangnya ke `~/.swiftpm/swift-sdks/darwin.artifactbundle`.

### Verifikasi status SDK dan Autentikasi:
Setelah `xtool setup` selesai, verifikasi hasilnya dengan:
```bash
xtool sdk status
swift sdk list
xtool auth status
```
Pastikan `Darwin SDK is installed` dan status autentikasi menunjukkan akun Anda telah masuk.

## 7. Mengaktifkan Developer Mode di iPhone

iOS 16 ke atas mewajibkan Developer Mode aktif agar aplikasi hasil build lokal dapat dijalankan.

### Langkah di iPhone:
1. Buka aplikasi **Settings** (Pengaturan) di iPhone.
2. Masuk ke menu **Privacy & Security** (Privasi & Keamanan).
3. Gulir ke bagian paling bawah dan pilih **Developer Mode** (Mode Pengembang).
4. Geser sakelar ke posisi aktif (ON).
5. iPhone akan meminta konfirmasi untuk melakukan restart. Tekan tombol **Restart**.
6. Setelah iPhone menyala kembali, buka kunci layar, tekan tombol **Turn On** pada dialog konfirmasi, dan masukkan passcode iPhone Anda.

Alternatif via terminal setelah `libimobiledevice-utils` terpasang:
```bash
idevicedevmodectl arm
```

## 8. Menjalankan Alur Pengembangan (xtool dev)

Setelah setup selesai dan Developer Mode aktif, alur kerja pengembangan harian adalah sebagai berikut:

1. Hubungkan iPhone ke komputer Fedora menggunakan kabel USB.
2. Buka kunci layar iPhone. Saat dialog "Trust This Computer?" (Percayai Komputer Ini?) muncul, ketuk **Trust** dan masukkan passcode iPhone.
3. Masuk ke direktori repositori:
   ```bash
   cd tulis-ios
   ```
4. Jalankan perintah:
   ```bash
   xtool dev
   ```
5. `xtool` akan melakukan:
   - Kompilasi modul Swift untuk arsitektur target iOS (`arm64-apple-ios`). Catatan: kompilasi pertama kali membutuhkan waktu beberapa menit karena sistem mengompilasi antarmuka modul SDK iOS ke cache global. Kompilasi berikutnya akan berjalan jauh lebih singkat.
   - Mengambil sertifikat pengembang gratis dan provisioning profile dari Apple.
   - Menandatangani (codesign) bundel aplikasi `.app`.
   - Menginstal aplikasi ke iPhone melalui koneksi `usbmuxd`.
   - Membuka aplikasi secara otomatis di layar iPhone.

### Mengatasi dialog "Untrusted Developer" di iPhone:
Saat pertama kali membuka aplikasi yang di-sign menggunakan Apple ID gratis, iOS akan menampilkan peringatan bahwa pengembang belum dipercayai:
1. Buka **Settings** > **General** > **VPN & Device Management**.
2. Di bagian "Developer App", pilih alamat email Apple ID Anda.
3. Ketuk **Trust "[Email Anda]"**, lalu konfirmasi dengan memilih **Trust**.
4. Kembali ke layar utama dan buka aplikasi **Tulis**.

## 9. Catatan Bundle ID (xtool.yml)

Konfigurasi pengemasan aplikasi disimpan dalam berkas `xtool.yml` pada root repositori:

```yaml
version: 1
bundleID: io.github.fadhil-sabar.tulis
```

### Mengapa Bundle ID penting pada Apple ID gratis:
- Pada akun Apple Developer gratis (personal team), setiap App ID terdaftar secara global di sistem Apple dan tidak dapat menggunakan wildcard profile.
- Secara default, `xtool` mencoba menambahkan prefiks unik saat berkomunikasi dengan Apple Developer Services untuk menghindari konflik penamaan antarpengguna.
- Jika Apple Developer Services menolak pendaftaran App ID (misalnya muncul pesan error bahwa Bundle Identifier tidak tersedia atau telah digunakan oleh akun lain), ganti nilai `bundleID` di `xtool.yml` dengan identifier unik milik Anda sendiri.
- Contoh penggantian:
  ```yaml
  version: 1
  bundleID: com.namapengguna.tulis
  ```
- Nilai ini dapat disesuaikan kembali tanpa memengaruhi logika kode Swift di dalam `Sources/`.

## 10. Pemecahan Masalah (Troubleshooting)

### Build macet atau gagal setelah `xtool sdk install`

Dua masalah ini muncul dengan Xcode 27.1 dan xtool 1.24.0 di Fedora 44:

1. **Build macet lama di kompilasi pertama** (`swift-frontend` memakai CPU penuh di `Models.swift`). Penyebabnya versi Swift lokal lebih lama dari Swift di Xcode. Cek versi compiler SDK:
   ```bash
   head -2 ~/.swiftpm/swift-sdks/darwin.artifactbundle/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/usr/lib/swift/Swift.swiftmodule/arm64e-apple-ios.swiftinterface
   ```
   Pasang Swift dengan versi yang sama (`swiftly install 6.4.2 && swiftly use -g 6.4.2`), hapus `.build`, lalu build ulang.
2. **Error `module '_c_standard_library_obsolete' requires feature 'found_incompatible_headers__check_search_paths'`**. Header bawaan clang di bundle SDK masih versi lama (`float.h` melakukan `include_next` untuk `__APPLE__`) sehingga bentrok dengan modulemap SDK iOS 27. Ganti dengan header clang dari toolchain Swift yang dipakai:
   ```bash
   cd ~/.swiftpm/swift-sdks/darwin.artifactbundle/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/clang/21
   mv include include.xcode-orig
   cp -r ~/.local/share/swiftly/toolchains/6.4.2/usr/lib/clang/21/include include
   ```
   Perbaikan ini hilang kalau SDK dipasang ulang, jadi ulangi setelah `xtool sdk install`.

Setelah dua langkah ini, `xtool dev build` berhasil dan menghasilkan `xtool/Tulis.app` (arm64).

### Perangkat tidak terdeteksi:
1. Pastikan kabel USB berfungsi baik untuk transfer data (bukan hanya kabel pengisi daya).
2. Periksa apakah perangkat dikenali oleh subsistem USB Linux:
   ```bash
   lsusb | grep -i apple
   ```
3. Periksa status socket daemon `usbmuxd`:
   ```bash
   systemctl status usbmuxd
   ```
4. Jalankan `idevice_id -l` untuk memastikan UUID perangkat terbaca.

### Masalah Pairing dan Dialog Kepercayaan (Trust Loop):
1. Jika iPhone tidak memunculkan dialog kepercayaan atau status pairing tidak valid:
   ```bash
   idevicepair pair
   ```
   Buka kunci layar iPhone dan pilih **Trust** saat diminta.
2. Periksa validitas pasangan:
   ```bash
   idevicepair validate
   ```
   Respon yang diharapkan: `SUCCESS: Validated pairing with device <UUID>`.
3. Jika pairing macet atau korup, reset data pairing:
   ```bash
   idevicepair unpair
   idevicepair pair
   ```

### Masa berlaku sertifikat penandatanganan (7 hari):
Akun Apple ID gratis memiliki batasan masa aktif sertifikat penandatanganan selama 7 hari. Jika aplikasi tidak dapat dibuka setelah 7 hari:
- Hubungkan kembali iPhone ke komputer.
- Jalankan ulang `xtool dev`. Aplikasi akan di-sign ulang dan diperbarui tanpa menghapus data catatan lokal yang sudah tersimpan di dalam aplikasi.

---

## 11. Status Verifikasi

Untuk transparansi kesiapan lingkungan pada sistem saat ini:

- **Terverifikasi**:
  - Instalasi Swift 6.4.2 via `swiftly` di `~/.local/bin/swift` dan verifikasi `swift test` (10 test TulisCore lulus).
  - Pemasangan `xtool` 1.24.0 di `~/.local/bin/xtool` dan verifikasi `xtool --version`.
  - Keberadaan daemon dan aturan udev bawaan `usbmuxd` di Fedora 44.
  - Kompatibilitas arsitektur x86_64 dan dukungan FUSE/squashfs wrapper untuk xtool.
  - `xtool sdk install ~/Downloads/Xcode_27.1.xip` berhasil (iPhoneOS 27.1, iPhoneSimulator 27.1, MacOSX 27.0).
  - `xtool dev build` berhasil setelah perbaikan di bagian 10.

- **Belum Terverifikasi (Menunggu Tindakan Pengguna)**:
  - Instalasi paket `libimobiledevice-utils` via `sudo dnf` (menunggu eksekusi oleh pengguna).
  - Login Apple ID (`xtool auth login`). SDK sudah terpasang lewat `xtool sdk install`, jadi `xtool setup` cukup untuk bagian login.
  - Sambungan fisik USB iPhone, pairing kepercayaan, dan aktivasi Developer Mode pada perangkat nyata.
  - Eksekusi penuh `xtool dev` sampai aplikasi Tulis terpasang dan terbuka di layar iPhone fisik.
