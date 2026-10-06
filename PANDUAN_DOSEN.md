# DuitKu — Aplikasi Manajemen Keuangan Pribadi Mahasiswa

Aplikasi Flutter pelacak keuangan pribadi, pencatatan transaksi harian, perencana anggaran bulanan, dan tabungan impian dengan penyimpanan lokal SQLite terenkripsi.

Dibuat sebagai proyek tugas akhir mahasiswa Teknik Informatika.

---

## Ringkasan Proyek

- **Bahasa & Kerangka Kerja:** Dart 3.13 / Flutter 3.47.5
- **Arsitektur:** Clean separation — `lib/data/` (SQLite + Repository + AppState Provider), `lib/features/` (UI per fitur), `lib/core/` (token desain, tema, pemformat, lokalisasi)
- **Basis Data:** SQLite via `sqflite` (dengan mode WAL, foreign key cascade, dan transaksi atomik)
- **Status:** **148 dari 148 tes unit/widget lulus** (`flutter test`), **0 error & 0 warning** (`flutter analyze`)
- **Lokalisasi:** Bahasa Indonesia penuh (dukungan mata uang IDR format `Rp 10.000` dan penanggalan `id_ID`)

---

## Struktur Folder

```
D:/coding/duitku/
├── lib/
│   ├── main.dart                      # Titik masuk aplikasi, inisialisasi tema & penyedia status
│   ├── core/                          # Token desain & utilitas global
│   │   ├── app_icons.dart             # Pemetaan ikon Material ramah linter
│   │   ├── formatters.dart            # Pemformat mata uang Rupiah & tanggal Indonesia
│   │   ├── strings.dart               # Kamus lokalisasi Bahasa Indonesia lengkap
│   │   └── theme.dart                 # Skema warna Material 3 (gelap & terang, non-slop)
│   ├── data/                          # Lapisan data
│   │   ├── database.dart              # Skema SQLite, migrasi v2, seed data bawaan
│   │   ├── repository.dart            # Kueri basis data dengan transaksi atomik
│   │   ├── app_state.dart             # Manajemen status ChangeNotifier + penjaga balapan
│   │   └── models/                    # Model entitas (Transaction, Wallet, Category, Goal, dsb.)
│   └── features/                      # Tampilan antarmuka per modul
│       ├── auth/                      # Masuk, daftar, dan sesi pengguna
│       ├── dashboard/                 # Ringkasan saldo, pengeluaran bulanan, grafik
│       ├── transactions/              # Riwayat, tambah pemasukan/pengeluaran/transfer
│       ├── budget/                    # Batas anggaran per kategori bulanan
│       ├── goals/                     # Target tabungan impian + pendanaan dari dompet
│       ├── recurring/                 # Transaksi berulang otomatis
│       ├── analytics/                 # Analisis pengeluaran per kategori & tren waktu
│       └── settings/                  # Ekspor/impor cadangan SQLite, PIN, ganti tema
├── test/                              # 18 berkas pengujian otomatis (148 tes)
│   ├── bug_fixes_pass2_test.dart      # 9 tes regresi untuk perbaikan audit v1.6.1
│   ├── backup_security_test.dart      # Tes integritas berkas cadangan SQLite
│   └── ...                            # Tes unit repositori, model, dan widget
└── build/app/outputs/flutter-apk/     # Berkas instalasi APK rilis
```

---

## Cara Menjalankan untuk Dosen / Penguji

### 1. Prasyarat
- Flutter SDK (tersedia di `D:\tools\flutter`)
- Java JDK 17 atau 21
- Perangkat Android fisik dengan USB Debugging atau emulator Android

### 2. Memeriksa Kualitas Kode
```bash
# Analisis statis (harus 0 error, 0 warning)
flutter analyze

# Jalankan seluruh rangkaian tes otomatis (148 tes)
flutter test
```

### 3. Menjalankan Aplikasi
```bash
# Pasang dependensi
flutter pub get

# Jalankan di perangkat yang terhubung (mode debug)
flutter run

# Atau buat berkas APK siap pasang (mode rilis)
# Dua flag tambahan diperlukan pada mesin ini:
#   --no-tree-shake-icons  : ikon kategori disimpan sebagai kode di SQLite,
#                            sehingga glif-nya tidak bisa dibuang saat build
#   --android-skip-build-dependency-validation : Gradle wrapper bawaan proyek
#                            (8.12) di bawah minimum Flutter 3.47 (8.14);
#                            naikkan gradle-wrapper.properties bila ingin
#                            membangun tanpa flag ini
flutter build apk --release --no-tree-shake-icons --android-skip-build-dependency-validation
```
Berkas APK rilis akan dihasilkan di:
`build/app/outputs/flutter-apk/app-release.apk` (terbukti terbangun: 88,5 MB)

> Catatan waktu build: kompilasi rilis penuh memakan sekitar 10 menit pada mesin
> ini (Kotlin + R8). Peringatan cache inkremental Kotlin yang muncul di stderr
> bersifat tidak fatal — build tetap selesai dengan kode keluar 0.

---

## Log Audit & Perbaikan Kode (v1.6.1)

Audit dilakukan secara silang menggunakan model penalaran Claude 3.7 Sonnet (`combo-coding`) dan OpenAI Codex CLI melalui jembatan 9router lokal, dengan verifikasi langsung pada lingkungan Flutter SDK mesin ini.

### Perbaikan Kritis & Stabilitas (Pass 2)
1. **Pencegahan Saldo Mengembang saat Hapus Dompet:**
   Transaksi transfer masuk sebelumnya meninggalkan entri tanpa dompet tujuan karena kolom `transfer_wallet_id` tidak memiliki `FOREIGN KEY CASCADE`. Repositori kini menghapus riwayat dua arah secara atomik dalam satu transaksi SQLite.
2. **Atomisitas Pendanaan Tabungan Impian:**
   Pemotongan saldo dompet dan penambahan saldo impian sebelumnya berjalan terpisah. Jika aplikasi ditutup di tengah jalan, uang terpotong tanpa masuk impian. Kini dibungkus `db.transaction()` (semua berhasil atau semua batal).
3. **Penyusutan Data (Wipe) Atomik:**
   Fungsi reset pabrik kini mematikan sementara kendala foreign key, membersihkan seluruh tabel dalam satu transaksi, dan menanamkan data awal bawaan kembali agar aplikasi tidak menggantung jika operasi terputus.
4. **Pemulihan Cadangan Tiga Berkas (WAL / SHM):**
   Rollback saat gagal memulihkan cadangan basis data kini mencadangkan dan mengembalikan ketiga berkas SQLite (`.db`, `-wal`, `-shm`), bukan hanya berkas utama.
5. **Penjaga Balapan `refreshAll()`:**
   Komponen status kini menggunakan sistem dirty-flag: jika pemanggilan pembaruan data masuk saat siklus sebelumnya belum selesai, siklus akan otomatis mengulang satu kali lagi dengan data termutakhir.
6. **Penanganan Pendaftaran Akun Ganda yang Ramah:**
   Pelanggaran kendala unik pada SQLite saat dua akun mendaftar bersamaan kini ditangkap dan menampilkan pesan "Email sudah terdaftar" tanpa memicu pengecualian mentah.

### Pembersihan Antarmuka & Linter (Pass 1)
- Menghilangkan seluruh peringatan `prefer_const_constructors_in_immutables` dan `prefer_const_literals_to_create_immutables`.
- Memperbaiki pemanggilan dinamis `IconData` menjadi konstanta terpusat di `lib/core/app_icons.dart`.
- Menyelaraskan teks antarmuka menjadi Bahasa Indonesia penuh (menghilangkan sisa string Inggris pada tombol dan label).
- Desain antarmuka menggunakan tema Material 3 modern dengan palet warna terkurasi (tanpa gradien mencolok ala AI slop, menggunakan kontras terukur, tipografi terbaca, dan umpan balik haptik).

---

## Catatan Antigravity IDE

Proyek ini telah dibuka dan terkonfigurasi di **Antigravity IDE**:
- Jalur kerja: `D:\coding\duitku`
- Konfigurasi asisten: `.antigravitycli` (konteks proyek dan perintah penting)
- SDK Flutter terkait: `D:\tools\flutter`
