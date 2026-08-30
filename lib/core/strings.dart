import 'package:flutter/material.dart';

/// Language of the UI.
///
/// The app ships two languages and switches at runtime from Settings, so the
/// choice is a value the whole tree reads rather than a compile-time constant.
enum AppLanguage {
  indonesian('id', 'Indonesia'),
  english('en', 'English');

  const AppLanguage(this.code, this.label);

  final String code;

  /// Shown in the language picker, always in the language's own words.
  final String label;

  static AppLanguage fromCode(String? code) => AppLanguage.values.firstWhere(
        (l) => l.code == code,
        orElse: () => AppLanguage.indonesian,
      );
}

/// Translated UI strings.
///
/// A plain map rather than generated `intl` ARB files: the app has one locale
/// pair and no pluralisation or date-format rules to negotiate, so codegen
/// would add a build step and a dependency for nothing. Keys are the English
/// text, which keeps call sites readable and makes a missing entry obvious in
/// review — [t] falls back to the key itself.
class L {
  L._();

  static const Map<String, String> _id = {
    // ---- shell / navigation
    'Home': 'Beranda',
    'Transactions': 'Transaksi',
    'Budgets': 'Anggaran',
    'Goals': 'Target',
    'Insights': 'Wawasan',
    'History': 'Riwayat',
    'Records': 'Catatan',
    'Settings': 'Pengaturan',

    // ---- actions
    'Add': 'Tambah',
    'Add transaction': 'Tambah transaksi',
    'Add budget': 'Tambah anggaran',
    'Add category': 'Tambah kategori',
    'Add wallet': 'Tambah dompet',
    'Add money': 'Tambah dana',
    'Add funds': 'Isi saldo',
    'Add funds manually': 'Isi saldo manual',
    'From wallet': 'Dari dompet',
    'Manual': 'Isi manual',
    'The goal is credited from the chosen wallet, so the balance stays true.':
        'Target diisi dari dompet yang dipilih, supaya saldo tetap benar.',
    'Adds to the goal without touching any wallet balance.':
        'Menambah target tanpa mengubah saldo dompet mana pun.',
    'to reach the target': 'lagi untuk mencapai target',
    'Goal reached': 'Target tercapai',
    'Could not save': 'Gagal menyimpan',
    'Save changes': 'Simpan perubahan',
    'Save rule': 'Simpan aturan',
    'Cancel': 'Batal',
    'Delete': 'Hapus',
    'Delete all': 'Hapus semua',
    'Remove': 'Hapus',
    'Clear': 'Bersihkan',
    'Clear filters': 'Bersihkan filter',
    'Archive': 'Arsipkan',
    'Choose file': 'Pilih berkas',
    'Undo': 'Urungkan',
    'Edit budget': 'Ubah anggaran',
    'Edit goal': 'Ubah target',
    'Edit wallet': 'Ubah dompet',
    'Edit transaction': 'Ubah transaksi',
    'Edit recurring': 'Ubah aturan berulang',
    'New budget': 'Anggaran baru',
    'New category': 'Kategori baru',
    'New goal': 'Target baru',
    'New wallet': 'Dompet baru',
    'New transaction': 'Transaksi baru',
    'New recurring': 'Aturan berulang baru',
    'New rule': 'Aturan baru',
    'Create goal': 'Buat target',
    'Create a goal': 'Buat target',
    'Set a budget': 'Atur anggaran',

    // ---- transaction fields
    'Amount': 'Jumlah',
    'Date': 'Tanggal',
    'Note': 'Catatan',
    'Category': 'Kategori',
    'Wallet': 'Dompet',
    'Transfer': 'Transfer',
    'Income': 'Pemasukan',
    'Expense': 'Pengeluaran',
    'Uncategorized': 'Tanpa kategori',
    'Optional — what was this for?': 'Opsional — untuk apa?',
    'Search notes and categories': 'Cari catatan dan kategori',

    // ---- budget
    'Budget': 'Anggaran',
    'Budgeted': 'Dianggarkan',
    'Spent': 'Terpakai',
    'Net': 'Selisih',
    'MONTHLY LIMIT': 'BATAS BULANAN',
    'CATEGORY': 'KATEGORI',
    'No budgets for this month': 'Belum ada anggaran bulan ini',
    'No budgets set for this month': 'Belum ada anggaran bulan ini',
    'Set a cap per category and Duitku will track it for you.':
        'Tetapkan batas per kategori, Duitku akan memantaunya.',
    'That is about %s a day over a 30-day month.':
        'Sekitar %s per hari untuk bulan 30 hari.',

    // ---- wallets / goals
    'Wallets': 'Dompet',
    'Total balance': 'Saldo total',
    'OPENING BALANCE': 'SALDO AWAL',
    'What the wallet holds today, before Duitku records':
        'Saldo dompet saat ini, sebelum dicatat Duitku',
    'Savings goals': 'Target tabungan',
    'Target amount': 'Jumlah target',
    'Deadline': 'Tenggat',
    'No deadline': 'Tanpa tenggat',
    'No goals yet': 'Belum ada target',
    'Deadline passed': 'Tenggat sudah lewat',
    'That deadline is in the past.': 'Tenggatnya sudah lewat.',
    'The saved amount will be forgotten.':
        'Jumlah yang sudah terkumpul akan hilang.',
    'Add money to this goal any time from the Goals tab.':
        'Tambahkan dana kapan saja dari tab Target.',
    'Fill target': 'Penuhi target',

    // ---- recurring
    'Recurring': 'Berulang',
    'Recurring transactions': 'Transaksi berulang',
    'Repeats': 'Pengulangan',
    'Every week': 'Setiap minggu',
    'Every month': 'Setiap bulan',
    'Day of month': 'Tanggal',
    'Day of week': 'Hari',
    'Next occurrence': 'Jadwal berikutnya',
    'Short months use their last day': 'Bulan pendek memakai hari terakhirnya',
    'No recurring rules': 'Belum ada aturan berulang',
    'Recurring rule deleted': 'Aturan berulang dihapus',
    'Transactions it already created are kept.':
        'Transaksi yang sudah dibuat tetap tersimpan.',
    'Rules are created from a transaction by marking it as repeating.':
        'Aturan dibuat dari sebuah transaksi dengan menandainya berulang.',

    // ---- charts
    'Spending by category': 'Pengeluaran per kategori',
    'Spending': 'Pengeluaran',
    'Category breakdown': 'Rincian kategori',
    'Daily flow': 'Arus harian',
    'Month by month': 'Bulan ke bulan',
    'Top spending days': 'Hari pengeluaran terbesar',
    'No spending yet': 'Belum ada pengeluaran',
    'No spending recorded yet': 'Belum ada pengeluaran tercatat',
    'No data for this month': 'Belum ada data bulan ini',
    'Nothing to chart yet': 'Belum ada yang bisa digambarkan',
    'Not enough history yet': 'Riwayat belum cukup',
    'This month': 'Bulan ini',
    'Today': 'Hari ini',
    'Yesterday': 'Kemarin',
    'Last 8': '8 terakhir',

    // ---- settings
    'Appearance': 'Tampilan',
    'Security': 'Keamanan',
    'Language': 'Bahasa',
    'Theme': 'Tema',
    'System': 'Sistem',
    'Light': 'Terang',
    'Dark': 'Gelap',
    'Passcode lock': 'Kunci sandi',
    'Fingerprint unlock': 'Buka dengan sidik jari',
    'Use biometrics instead of typing the code':
        'Pakai biometrik daripada mengetik sandi',
    'Use fingerprint': 'Pakai sidik jari',
    'Set a passcode first': 'Atur sandi terlebih dahulu',
    'Create passcode': 'Buat sandi',
    'Confirm passcode': 'Konfirmasi sandi',
    'Passcode set': 'Sandi tersimpan',
    'Pick four digits you will remember': 'Pilih empat angka yang Anda ingat',
    'Enter the same four digits again': 'Masukkan empat angka yang sama lagi',
    'Enter passcode': 'Masukkan sandi',
    'Wrong passcode': 'Sandi salah',
    'Unlock Duitku': 'Buka Duitku',
    'Forgot passcode?': 'Lupa sandi?',
    'Confirm your passcode': 'Konfirmasi sandi kamu',
    'Current passcode': 'Sandi saat ini',
    'Confirm it is you': 'Konfirmasi ini kamu',
    'A 4-digit code is required to open Duitku':
        'Kode 4 angka diperlukan untuk membuka Duitku',
    'The passcode cannot be recovered. Removing it unlocks the app, ':
        'Sandi tidak bisa dikembalikan. Menghapusnya akan membuka kunci aplikasi, ',

    // ---- data / backup
    'Export backup': 'Ekspor cadangan',
    'Import backup': 'Impor cadangan',
    'Export CSV': 'Ekspor CSV',
    'Reset all data': 'Atur ulang semua data',
    'Save a copy of the database': 'Simpan salinan basis data',
    'Restore from a .db file': 'Pulihkan dari berkas .db',
    'Spreadsheet of this month': 'Lembar kerja bulan ini',
    'Delete every transaction and start over':
        'Hapus semua transaksi dan mulai ulang',
    'Backup ready to share': 'Cadangan siap dibagikan',
    'Backup restored': 'Cadangan dipulihkan',
    'CSV ready to share': 'CSV siap dibagikan',
    'All data deleted': 'Semua data dihapus',
    'Import backup?': 'Impor cadangan?',
    'Reset everything?': 'Atur ulang semuanya?',
    'Everything currently in Duitku will be replaced by the file ':
        'Semua data di Duitku akan digantikan oleh berkas ',
    'Every transaction, budget and goal will be deleted. Wallets and ':
        'Semua transaksi, anggaran, dan target akan dihapus. Dompet dan ',
    'Spending history is kept.': 'Riwayat pengeluaran tetap tersimpan.',
    'Transactions recorded against this wallet are deleted with it.':
        'Transaksi pada dompet ini ikut terhapus.',
    'Past transactions keep their category. It just stops appearing in ':
        'Transaksi lama tetap memakai kategorinya. Kategori hanya berhenti muncul di ',
    'This cannot be undone.': 'Tindakan ini tidak bisa dibatalkan.',
    'All data stays on this device': 'Semua data tersimpan di perangkat ini',
    'Your data stays on this device': 'Data Anda tersimpan di perangkat ini',

    // ---- confirmations / errors
    'Delete transaction?': 'Hapus transaksi?',
    'Delete budget?': 'Hapus anggaran?',
    'Delete goal?': 'Hapus target?',
    'Delete rule?': 'Hapus aturan?',
    'Delete wallet?': 'Hapus dompet?',
    'Delete category?': 'Hapus kategori?',
    'Transaction deleted': 'Transaksi dihapus',
    'Enter an amount first': 'Isi jumlahnya dulu',
    'Pick a category and a wallet': 'Pilih kategori dan dompet',
    'Scan receipt': 'Pindai struk',
    'Scan a receipt': 'Pindai struk belanja',
    'Scan receipt automatically': 'Pindai struk otomatis',
    'Snap a photo to fill amount & merchant': 'Foto struk, nominal & toko terisi otomatis',
    'Take photo': 'Ambil foto',
    'Choose from gallery': 'Pilih dari galeri',
    'Scanning receipt...': 'Memindai struk...',
    'Receipt scanned successfully': 'Struk berhasil dipindai',
    'No text found on receipt': 'Tidak ada teks yang terdeteksi pada struk',
    'Failed to scan receipt': 'Gagal memindai struk',
    'Camera': 'Kamera',
    'Gallery': 'Galeri',
    'Nothing matches those filters': 'Tidak ada yang cocok dengan filter',
    'No transactions this month': 'Belum ada transaksi bulan ini',
    'No transactions for this date': 'Belum ada transaksi pada tanggal ini',
    'No transactions yet': 'Belum ada transaksi',
    'Daily': 'Harian',
    'Monthly': 'Bulanan',
    'Daily (Per Date)': 'Harian (Per Tanggal)',
    'Monthly (Per Month)': 'Bulanan (Per Bulan)',
    'Pick date': 'Pilih tanggal',
    'Jump to date': 'Lompat ke tanggal',
    'No categories for this type yet.': 'Belum ada kategori untuk tipe ini.',
    'Tap Add to record your first one': 'Tekan Tambah untuk mencatat yang pertama',
    'Jump to month': 'Lompat ke bulan',
    'Color': 'Warna',
    'COLOR': 'WARNA',
    'Not set': 'Belum diatur',
    'Unknown error': 'Galat tidak dikenal',
    'Duitku failed to start': 'Duitku gagal dijalankan',
    'Your data is still on the device. Reopening the app ':
        'Data Anda masih tersimpan di perangkat. Membuka ulang aplikasi ',

    // ---- dates
    'Jan': 'Jan', 'Feb': 'Feb', 'Mar': 'Mar', 'Apr': 'Apr',
    'May': 'Mei', 'Jun': 'Jun', 'Jul': 'Jul', 'Aug': 'Agu',
    'Sep': 'Sep', 'Oct': 'Okt', 'Nov': 'Nov', 'Dec': 'Des',
    'Monday': 'Senin',
    'Tuesday': 'Selasa',
    'Wednesday': 'Rabu',
    'Thursday': 'Kamis',
    'Friday': 'Jumat',
    'Saturday': 'Sabtu',
    'Sunday': 'Minggu',
    "Categories": "Kategori",
    "English": "English",
    "Indonesia": "Indonesia",
    "Recent": "Terbaru",
    "Rules are created from a transaction by marking it as repeating. They post automatically when due.": "Aturan dibuat dari sebuah transaksi dengan menandainya sebagai berulang. Aturan dijalankan otomatis saat jatuh tempo.",
    "Duitku backup": "Cadangan Duitku",
    "Duitku CSV": "CSV Duitku",
    "Duitku 1.0.0": "Duitku 1.0.0",
    "Duitku": "Duitku",
    "MaterialIcons": "MaterialIcons",
    "Cash": "Tunai",
    "Bank Account": "Rekening Bank",
    "E-Wallet": "Dompet Digital",
    "Transport": "Transportasi",
    "Tuition": "Kuliah",
    "Books": "Buku",
    "Entertainment": "Hiburan",
    "Health": "Kesehatan",
    "Rent": "Sewa",
    "Shopping": "Belanja",
    "Other": "Lainnya",
    "Salary": "Gaji",
    "Allowance": "Uang Saku",
    "Freelance": "Freelance",
    "Gift": "Hadiah",
    "Emergency Fund": "Dana Darurat",
    "Food & Drink": "Makan & Minum",

    "Could not load budgets": "Gagal memuat anggaran",
  };

  /// The English-to-Indonesian dictionary.
  ///
  /// Exposed for tests that assert every seeded name is covered; UI code
  /// should call [t] instead so it reads the language in scope.
  static Map<String, String> get indonesian => _id;

  /// Returns [key] in the active language.
  ///
  /// Falls back to the key itself so a forgotten entry shows readable English
  /// instead of an empty box — visible in testing, harmless in production.
  static String t(String key, AppLanguage lang) {
    if (lang == AppLanguage.english) return key;
    return _id[key] ?? key;
  }
}

/// Reads the active language from the widget tree.
extension LContext on BuildContext {
  /// Translates [key] into the language picked in Settings.
  ///
  /// Hangs off BuildContext rather than String so a call site reads as
  /// `context.tr('Goals')` and the reader can see where the language comes
  /// from; a String extension would look like the literal carried its own
  /// translation.
  String tr(String key) => L.t(key, language);

  /// The language picked in Settings.
  ///
  /// Kept on an InheritedWidget rather than read from AppState so this file
  /// stays free of a data-layer import — widgets only need the language, not
  /// the database behind it.
  AppLanguage get language =>
      dependOnInheritedWidgetOfExactType<LanguageScope>()?.language ??
      AppLanguage.indonesian;
}

/// Publishes the selected [AppLanguage] to the subtree.
class LanguageScope extends InheritedWidget {
  const LanguageScope({
    super.key,
    required this.language,
    required super.child,
  });

  final AppLanguage language;

  @override
  bool updateShouldNotify(LanguageScope oldWidget) =>
      oldWidget.language != language;
}
