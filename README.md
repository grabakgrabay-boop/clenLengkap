# Cleaner Pro

Aplikasi pembersih Android (Flutter): PencariMayat, Pembersih Cache, File Sementara,
File Tidak Berguna, Deduplikator, dan Pengendali Aplikasi.

## Build APK otomatis
Setiap push ke branch `main` menjalankan GitHub Actions yang membuat APK.
Unduh dari tab **Actions** → run terbaru → **Artifacts** → `CleanerPro-APK`.

## Struktur
- `lib/` : kode Dart (UI + logika pembersih)
- `android/MainActivity.kt` : kode native (RAM, daftar aplikasi)
- `android/AndroidManifest_tambahan.xml` : izin yang ditambahkan otomatis
- `.github/workflows/build.yml` : otomatisasi build
