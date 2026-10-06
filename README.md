# Duitku — Pelacak Finansial Pribadi & Perencanaan Budget Bulanan

Aplikasi Android untuk mencatat pemasukan/pengeluaran, menyusun budget bulanan,
dan memantau target tabungan. Semua data tersimpan lokal di perangkat
(SQLite) — tidak ada server, tidak ada akun, tidak ada data yang keluar dari HP.

---

## 1. Cara Menjalankan

### Prasyarat
- Flutter SDK 3.35+ (`flutter --version`)
- Android SDK + JDK 17 (biasanya sudah ikut Android Studio)
- Perangkat Android (min. Android 6.0 / API 23) atau emulator

### Langkah
```bash
flutter pub get          # unduh dependency
flutter run              # jalan di HP/emulator yang terhubung
```

### Build APK
```bash
flutter build apk --release --no-tree-shake-icons --android-skip-build-dependency-validation
# hasil: build/app/outputs/flutter-apk/app-release.apk
```

> **Wajib pakai `--no-tree-shake-icons`.** Ikon kategori disimpan sebagai code
> point di database, jadi glyph-nya baru diketahui saat runtime. Tanpa flag ini
> build gagal dengan `Avoid non-constant invocations of IconData`.

Atau langsung pakai script yang sudah menyiapkan semuanya (analyze → test →
build → zip):

```bash
./tool/build_release.sh            # build + zip source ke dist/
./tool/build_release.sh --no-zip   # build APK saja
```

Upload `app-release.apk` ke HP → izinkan "Install from unknown sources" → install.

### Regenerate Ikon (opsional)
```bash
pip install Pillow
python3 tool/make_icons.py
```

---

## 2. Fitur

| # | Fitur | Keterangan |
|---|-------|-----------|
| 1 | **Catat transaksi** | Pemasukan, pengeluaran, transfer antar dompet. Input nominal pakai pemisah ribuan otomatis. |
| 2 | **Kategori custom** | Tambah kategori sendiri, pilih ikon + warna, pisah jalur masuk/keluar. |
| 3 | **Budget bulanan** | Batas per kategori per bulan. Progress bar berubah warna: hijau → kuning (80%) → merah (100%+). |
| 4 | **Multi-dompet** | Kas, rekening bank, e-wallet. Saldo dihitung dari saldo awal + seluruh transaksi. |
| 5 | **Grafik** | Donut per kategori, bar chart pemasukan vs pengeluaran, line chart arus harian, top-5 hari boros. |
| 6 | **Target tabungan** | Target + deadline; app menghitung berapa yang perlu disisihkan per bulan. |
| 7 | **Transaksi berulang** | Aturan mingguan/bulanan yang otomatis membuat transaksi saat jatuh tempo. |
| 8 | **Cari & filter** | Filter per tipe/kategori/dompet + pencarian teks, dikelompokkan per hari. |
| 9 | **Export** | Backup database (`.db`) dan export CSV untuk Excel/Sheets, dibagikan lewat share sheet. |
| 10 | **PIN + biometrik** | Kunci 4 digit + fingerprint. App otomatis terkunci saat masuk background. |

---

## 3. Struktur Project

```
lib/
├── main.dart                     # entry point, theme, lock gate
├── core/
│   ├── theme.dart                # palet warna, spacing, radius, ThemeData
│   └── formatters.dart           # format Rupiah/tanggal/persentase
├── data/
│   ├── database.dart             # buka SQLite, schema, migrasi, seed data
│   ├── repository.dart           # semua query SQL
│   ├── app_state.dart            # state aplikasi (ChangeNotifier)
│   └── models/                   # Wallet, Category, Transaction, Budget, SavingsGoal, RecurringRule
└── features/
    ├── auth/         lock_screen.dart              # gerbang PIN + fingerprint
    ├── shell/        home_shell.dart               # bottom nav + tombol Add
    ├── dashboard/    dashboard_page.dart           # ringkasan + donut + budget
    ├── transactions/ transactions_page.dart        # list + filter + pencarian
    │                 transaction_editor.dart       # form tambah/edit
    ├── budget/       budget_page.dart              # daftar budget + progress
    │                 budget_editor.dart            # form set limit
    ├── goals/        goals_page.dart               # progress ring + top-up
    │                 goal_editor.dart
    ├── charts/       charts_page.dart              # semua grafik
    ├── settings/     settings_page.dart            # tema, bahasa, keamanan, data
    │                 passcode_setup.dart
    │                 wallet_manager.dart
    │                 category_manager.dart
    └── widgets/      balance_hero.dart             # kartu saldo utama
                      transaction_tile.dart         # satu baris transaksi
                      budget_bar.dart               # progress bar budget
                      charts.dart                   # donut + legend
```

---

## 4. Struktur Database (untuk ERD)

6 tabel, relasi lewat foreign key.

```
wallets                          categories
├── id (PK)                      ├── id (PK)
├── name                         ├── name
├── opening_balance              ├── icon_code
├── color_index                  ├── color_index
└── archived                     ├── is_income
                                 └── archived
        │                                │
        │                                │
        └──────────┬─────────────────────┘
                   ▼
             transactions
             ├── id (PK)
             ├── type              (income | expense | transfer)
             ├── amount
             ├── category_id  (FK → categories.id, ON DELETE SET NULL)
             ├── wallet_id    (FK → wallets.id,    ON DELETE CASCADE)
             ├── transfer_wallet_id (FK → wallets.id)
             ├── occurred_at
             ├── note
             ├── recurring_id (FK → recurring_rules.id)
             └── created_at

budgets                          savings_goals        recurring_rules
├── id (PK)                      ├── id (PK)          ├── id (PK)
├── category_id (FK)             ├── name             ├── type
├── limit_amount                 ├── target_amount    ├── amount
└── month_key  (yyyy-MM)         ├── saved_amount     ├── category_id (FK)
                                 ├── color_index      ├── wallet_id (FK)
                                 └── deadline         ├── frequency
                                                      ├── next_run_at
                                                      ├── day_of_month
                                                      ├── weekday
                                                      ├── note
                                                      └── active
```

**Index** yang dibuat: `occurred_at`, `(category_id, occurred_at)`, `wallet_id`,
`month_key`.

**Catatan desain:**
- `type` disimpan sebagai teks (`income`/`expense`/`transfer`), bukan angka —
  aman kalau urutan enum berubah dan tetap terbaca saat buka DB mentah.
- `icon_code` menyimpan codepoint ikon Material, jadi tabel tetap polos
  (tidak ada objek UI yang diserialisasi).
- `transfer` sengaja **tidak** dihitung sebagai pemasukan atau pengeluaran —
  memindahkan uang antar dompet bukan transaksi ekonomi.
- Saldo dompet **tidak disimpan**, tapi dihitung dari `opening_balance` + semua
  transaksi. Ini mencegah saldo basi kalau ada edit/hapus.

---

## 5. Alur Navigasi (untuk flowchart)

```
                    ┌──────────────┐
                    │   Splash     │
                    │ (bootstrap)  │
                    └──────┬───────┘
                           ▼
                  ┌─────────────────┐
                  │ PIN aktif?      │
                  └────┬───────┬────┘
                    ya │       │ tidak
                       ▼       │
            ┌──────────────┐   │
            │ Lock Screen  │   │
            │ PIN / sidik  │   │
            └──────┬───────┘   │
                   └─────┬─────┘
                         ▼
              ┌────────────────────┐
              │    Home Shell      │
              │ (bottom nav + FAB) │
              └─┬──┬──┬──┬────┬────┘
                │  │  │  │    │
      ┌─────────┘  │  │  │    └──────────┐
      ▼            ▼  ▼  ▼               ▼
  ┌────────┐ ┌──────────┐ ┌────────┐ ┌──────────┐
  │Dashboard│ │History   │ │Budget  │ │Goals     │
  │saldo +  │ │cari +    │ │progress│ │progress  │
  │donut +  │ │filter    │ │bar     │ │ring +    │
  │budget   │ │          │ │        │ │top up    │
  └────┬────┘ └────┬─────┘ └───┬────┘ └────┬─────┘
       │           │           │           │
       └───────────┴───────────┴───────────┘
                   │
                   ▼
            ┌──────────────┐      ┌──────────────┐
            │  Insights    │      │  Settings    │
            │  (grafik)    │      │ tema/bahasa/ │
            └──────────────┘      │ PIN/backup   │
                                  └──────┬───────┘
                                         ▼
                        ┌────────────────────────────┐
                        │ Wallet / Category /        │
                        │ Recurring manager          │
                        └────────────────────────────┘

  FAB "Add" (semua tab) ──▶ TransactionEditor ──▶ simpan ──▶ refresh semua tab
```

---

## 6. Keputusan Desain

**Kenapa SQLite, bukan cloud?**
Aplikasi keuangan pribadi tidak butuh server. Data lokal berarti: tidak ada
biaya, tidak ada login, dan tidak ada risiko data keuangan bocor ke pihak
ketiga. Backup manual (fitur 9) menutup risiko kehilangan HP.

**Kenapa saldo dihitung, bukan disimpan?**
Menyimpan saldo artinya harus memperbarui dua tempat setiap kali ada
transaksi. Kalau satu update gagal, saldo jadi bohong. Menghitung dari
`opening_balance` + transaksi selalu konsisten, dan query-nya tetap cepat
karena ada index.

**Kenapa `transfer` punya tipe sendiri?**
Kalau transfer dicatat sebagai "pengeluaran di dompet A" + "pemasukan di
dompet B", laporan bulanan akan terlihat seperti ada pengeluaran besar padahal
uangnya cuma pindah tempat. Tipe terpisah membuat laporan tetap jujur.

**Kenapa warna progress bar berubah?**
Hijau biasa saja tidak memberi sinyal. Ambang 80% (kuning) memberi peringatan
sebelum terlambat, dan 100% (merah) menandai overspend — informasi yang bisa
ditindaklanjuti, bukan sekadar hiasan.

---

## 7. Automated Tests

```bash
flutter test          # 46 test
flutter analyze       # harus: No issues found!
```

| File | Cakupan |
|---|---|
| `test/models_test.dart` | Format angka/tanggal, `signedAmount`, `copyWith`, `toMap` |
| `test/repository_test.dart` | SQLite asli: batas bulan, saldo dompet, budget, undo, recurring, reset |
| `test/pin_hasher_test.dart` | PIN tidak pernah tersimpan mentah, salt unik, verifikasi gagal-tertutup |
| `test/csv_test.dart` | Escaping RFC 4180 (koma & kutip di nama kategori) |
| `test/widget_test.dart` | Render tanggal Indonesia setelah locale dimuat |

Test repository jalan di atas SQLite sungguhan lewat `sqflite_common_ffi`, jadi
memeriksa constraint & query yang tidak bisa dijangkau unit test biasa. Di Linux
butuh `libsqlite3-dev`; di Windows/macOS `sqlite3.dll`/bawaan sudah cukup.

## 8. Testing Manual (untuk laporan)

Checklist yang bisa dipakai saat demo/sidang:

- [ ] Buat dompet baru → saldo muncul di Dashboard
- [ ] Catat pengeluaran → saldo turun, muncul di Recent
- [ ] Catat pemasukan → saldo naik, warna hijau
- [ ] Set budget Rp500.000 di kategori → progress bar muncul
- [ ] Catat pengeluaran sampai >80% → bar berubah kuning
- [ ] Lampaui limit → bar merah + label "over"
- [ ] Buat target tabungan → progress ring terisi saat top-up
- [ ] Filter transaksi per kategori → list tersaring
- [ ] Cari teks di kolom search → hasil sesuai
- [ ] Ganti bulan → data ikut berubah
- [ ] Set PIN → keluar app, buka lagi → diminta PIN
- [ ] Export backup → file terkirim lewat share sheet
- [ ] Export CSV → buka di Excel, kolom rapi
- [ ] Ganti tema Light/Dark → tampilan ikut berubah

---

## 8. Troubleshooting

| Masalah | Solusi |
|---------|--------|
| `flutter pub get` gagal | Pastikan Flutter 3.35+, jalankan `flutter doctor` |
| Gradle build gagal | `cd android && ./gradlew clean`, lalu build ulang |
| APK tidak bisa diinstall | Hapus versi lama dulu; cek "Install unknown apps" |
| Font beda di HP lain | Normal — Inter sudah di-bundle, jadi seharusnya sama; kalau beda cek `pubspec.yaml` bagian `fonts` |
| Data hilang setelah reinstall | Export backup dulu sebelum uninstall |
