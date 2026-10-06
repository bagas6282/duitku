import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/pin_hasher.dart';
import '../core/strings.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
// sqflite exports its own `Transaction`; hide it so the model wins.
import 'package:sqflite/sqflite.dart' hide Transaction;

import 'database.dart';
import 'models/budget.dart';
import 'models/category.dart';
import 'models/transaction.dart';
import 'models/user.dart';
import 'models/wallet.dart';
import 'repository.dart';

enum PeriodMode { daily, monthly }

/// App-wide state: the loaded data plus user preferences.
///
/// Widgets read derived values (balances, month summaries) straight off this
/// object rather than re-querying, so one write refreshes every screen.
class AppState extends ChangeNotifier {
  AppState._(this._db, this._repo, this._prefs);

  AppDatabase _db;
  FinanceRepository _repo;
  final SharedPreferences _prefs;

  FinanceRepository get repo => _repo;

  // ----------------------------------------------------------------- boot

  static Future<AppState> bootstrap() async {
    final db = await AppDatabase.open();
    final repo = FinanceRepository(db);
    final prefs = await SharedPreferences.getInstance();
    final state = AppState._(db, repo, prefs);

    final created = await repo.runDueRecurring();
    if (created > 0) {
      debugPrint('Recurring: materialized $created transaction(s).');
    }

    await state.refreshAll();
    await state._loadUserSession();
    state._applyPrefs();
    return state;
  }

  /// Opens a state backed by [dbPath] instead of the platform database.
  ///
  /// Mirror of [bootstrap] for the test suite. Preferences are still resolved
  /// normally so pref-driven behaviour can be exercised too.
  static Future<AppState> bootstrapForTests({required String dbPath}) async {
    final db = await AppDatabase.openForTests(dbPath);
    final repo = FinanceRepository(db);
    final prefs = await SharedPreferences.getInstance();
    final state = AppState._(db, repo, prefs);
    await state.refreshAll();
    await state._loadUserSession();
    state._applyPrefs();
    return state;
  }

  /// Releases the database handle. The app itself never calls this — it lives
  /// as long as the process — but tests must, or the temp file stays locked.
  @override
  @mustCallSuper
  Future<void> dispose() async {
    await _db.close();
    AppDatabase.overridePath(null);
    super.dispose();
  }

  // ---------------------------------------------------------------- auth

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  /// True when the user is logged in with an active account or session.
  bool get isAuthenticated => _currentUser != null;

  Future<void> _loadUserSession() async {
    final userId = _prefs.getInt('current_user_id');
    if (userId != null) {
      _currentUser = await _repo.getUserById(userId);
    }
  }

  /// Attempts to log in with email and password.
  /// Returns null on success, or an error message on failure.
  Future<String?> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return 'Email tidak boleh kosong.';
    if (password.isEmpty) return 'Kata sandi tidak boleh kosong.';

    try {
      final user = await _repo.authenticateUser(cleanEmail, password);
      if (user == null) {
        return 'Email atau kata sandi salah.';
      }
      _currentUser = user;
      await _prefs.setInt('current_user_id', user.id);
      await _prefs.setBool('is_logged_in', true);
      notifyListeners();
      return null;
    } catch (e) {
      return 'Gagal masuk: $e';
    }
  }

  /// Registers a new user account and immediately logs them in.
  /// Returns null on success, or an error message on failure.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    if (cleanName.isEmpty) return 'Nama lengkap tidak boleh kosong.';
    if (cleanEmail.isEmpty) return 'Email tidak boleh kosong.';
    if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      return 'Format email tidak valid.';
    }
    if (password.length < 6) {
      return 'Kata sandi minimal 6 karakter.';
    }

    try {
      final user = await _repo.registerUser(
        name: cleanName,
        email: cleanEmail,
        password: password,
      );
      _currentUser = user;
      await _prefs.setInt('current_user_id', user.id);
      await _prefs.setBool('is_logged_in', true);
      notifyListeners();
      return null;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      return msg;
    }
  }

  /// Guest / Demo mode entry for quick offline access.
  Future<void> continueAsGuest() async {
    try {
      var guest = await _repo.getUserByEmail('guest@duitku.local');
      if (guest == null) {
        guest = await _repo.registerUser(
          name: 'Pengguna Duitku',
          email: 'guest@duitku.local',
          password: 'guest-password-duitku',
        );
      }
      _currentUser = guest;
      await _prefs.setInt('current_user_id', guest.id);
      await _prefs.setBool('is_logged_in', true);
      notifyListeners();
    } catch (e) {
      // Fallback in-memory user
      _currentUser = UserModel(
        id: 1,
        name: 'Pengguna Duitku',
        email: 'user@duitku.local',
        createdAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    await _prefs.remove('current_user_id');
    await _prefs.setBool('is_logged_in', false);
    notifyListeners();
  }

  Future<void> updateProfile({required String name, String? avatarUrl}) async {
    if (_currentUser == null) return;
    final updated = _currentUser!.copyWith(
      name: name.trim(),
      avatarUrl: avatarUrl,
    );
    await _repo.updateUser(updated);
    _currentUser = updated;
    notifyListeners();
  }

  // ---------------------------------------------------------- preferences

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  String _localeCode = 'id';
  String get localeCode => _localeCode;

  bool _locked = false;
  bool get locked => _locked;

  bool _biometricEnabled = false;
  bool get biometricEnabled => _biometricEnabled;

  bool _reminderEnabled = false;
  bool get reminderEnabled => _reminderEnabled;

  /// The stored passcode record (`iterations:salt:hash`) — never the PIN.
  ///
  /// Private on purpose: comparing against this directly is what a stale
  /// plaintext check would do. Use [checkPin] instead.
  String? get _storedPin => _prefs.getString('pin');
  bool get pinEnabled => _prefs.getBool('pin_enabled') ?? false;

  /// True when a passcode or biometric is armed, so the app should gate entry.
  bool get lockArmed => pinEnabled || _biometricEnabled;

  void _applyPrefs() {
    final theme = _prefs.getString('theme_mode') ?? 'system';
    _themeMode = switch (theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _localeCode = _prefs.getString('locale') ?? 'id';
    // The saved language must reach Formatters here as well as in setLocale,
    // or dates would revert to Indonesian on every cold start.
    Formatters.setLanguage(AppLanguage.fromCode(_localeCode));
    _biometricEnabled = _prefs.getBool('biometric') ?? false;
    _reminderEnabled = _prefs.getBool('reminder') ?? false;
    // Start locked whenever a guard is armed.
    _locked = lockArmed;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setString('theme_mode', mode.name);
    notifyListeners();
  }

  /// Switches the UI language and repoints date formatting at it.
  ///
  /// [Formatters] holds the locale in a static because its methods are called
  /// from every screen; without this the language would change but dates would
  /// keep rendering in the previous one.
  Future<void> setLocale(String code) async {
    _localeCode = code;
    Formatters.setLanguage(AppLanguage.fromCode(code));
    await _prefs.setString('locale', code);
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool value) async {
    _biometricEnabled = value;
    await _prefs.setBool('biometric', value);
    notifyListeners();
  }

  /// Sets or clears the app passcode.
  ///
  /// Only a salted, stretched hash reaches disk — the PIN itself is a
  /// 4-digit secret guarding the whole ledger, so storing it verbatim (as
  /// SharedPreferences is world-readable to root/ADB backup) is not an option.
  Future<void> setPin(String? pin) async {
    if (pin == null || pin.isEmpty) {
      await _prefs.remove('pin');
      await _prefs.remove('pin_length');
      await _prefs.setBool('pin_enabled', false);
    } else {
      await _prefs.setString('pin', PinHasher.hashPin(pin));
      await _prefs.setInt('pin_length', pin.length);
      await _prefs.setBool('pin_enabled', true);
    }
    notifyListeners();
  }

  /// Panjang PIN yang tersimpan (4-6 digit).
  int get pinLength => _prefs.getInt('pin_length') ?? 4;

  /// Cek apakah email sudah terdaftar di sistem.
  Future<bool> checkEmailExists(String email) async {
    final trimmed = email.trim().toLowerCase();
    final user = await _repo.getUserByEmail(trimmed);
    return user != null;
  }

  /// Reset PIN dengan verifikasi email (untuk fitur lupa PIN).
  Future<void> resetPinWithEmail({
    required String email,
    required String newPin,
  }) async {
    final trimmed = email.trim().toLowerCase();
    final user = await _repo.getUserByEmail(trimmed);
    
    if (user == null) {
      throw Exception('Email tidak terdaftar');
    }
    
    // Set PIN baru
    await setPin(newPin);
  }

  /// True when [candidate] matches the stored passcode.
  ///
  /// Kept here rather than in the lock screen so the hashing rule lives in one
  /// place; the screen never sees the stored value.
  bool checkPin(String candidate) => PinHasher.verify(candidate, _storedPin);

  Future<void> setReminderEnabled(bool value) async {
    _reminderEnabled = value;
    await _prefs.setBool('reminder', value);
    notifyListeners();
  }

  void unlock() {
    _locked = false;
    notifyListeners();
  }

  void lock() {
    if (lockArmed) {
      _locked = true;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------ data cache

  List<Wallet> wallets = [];
  List<Category> categories = [];
  List<Transaction> transactions = [];
  List<SavingsGoal> goals = [];
  List<RecurringRule> recurring = [];
  Map<int, num> walletBalances = {};
  bool loading = true;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime get month => _month;

  String get monthKey =>
      '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  /// Coalesces overlapping [refreshAll] calls into one pass at a time.
  ///
  /// Every writer refreshes right after it commits, so a call arriving while a
  /// pass is running must NOT be handed the snapshot that is already in flight:
  /// that snapshot may predate the write that triggered the call. Instead the
  /// running pass is marked dirty and repeats once before completing, which
  /// guarantees every caller — and the listeners that repaint on
  /// [notifyListeners] — sees data that includes its own change.
  Future<void>? _refreshing;

  /// Set when a refresh is requested while another pass is running.
  bool _refreshAgain = false;

  /// True while [importBackup] is swapping the database file.
  ///
  /// During that window the old handle is closed and the new one is not open
  /// yet, so any query would throw `database_closed`. Readers are skipped
  /// rather than queued: the import path performs a full refresh of its own
  /// once the new handle is live, so there is nothing to catch up on.
  bool _importing = false;

  Future<void> refreshAll() async {
    // The import path closes the database handle before calling refreshAll, so
    // any pass that started during that window would throw `database_closed`.
    // Skip the refresh: the import performs a full refresh of its own once the
    // new handle is live, so there is nothing to catch up on.
    if (_importing) return;

    final running = _refreshing;
    if (running != null) {
      // A pass is already running. If it started before the write that triggered
      // this call, its snapshot won't include that write, so mark the pass dirty
      // and it will repeat once before completing.
      _refreshAgain = true;
      await running;
      return;
    }

    final pass = _refreshLoop();
    _refreshing = pass;
    await pass;
  }

  Future<void> _refreshLoop() async {
    try {
      while (true) {
        _refreshAgain = false;
        await _doRefresh();
        if (!_refreshAgain) break;
      }
    } finally {
      _refreshing = null;
    }
  }

  Future<void> _doRefresh() async {
    loading = true;
    notifyListeners();

    wallets = await _repo.wallets();
    categories = await _repo.categories();
    goals = await _repo.goals();
    recurring = await _repo.recurringRules();
    walletBalances = await _repo.walletBalances();
    await _loadMonth();

    loading = false;
    notifyListeners();
  }

  /// Convenience alias so widgets can pull-to-refresh without knowing the
  /// internal name.
  Future<void> refresh() => refreshAll();

  /// Window for the visible month as a half-open range: the first instant of
  /// this month up to (but excluding) the first instant of the next.
  ///
  /// An inclusive `23:59:59.999` bound silently drops anything in the last
  /// millisecond of the month, so the end is exclusive instead.
  (DateTime, DateTime) get _monthWindow {
    final from = DateTime(_month.year, _month.month, 1);
    final to = DateTime(_month.year, _month.month + 1, 1);
    return (from, to);
  }

  Future<void> _loadMonth() async {
    final (from, to) = _monthWindow;
    transactions = await _repo.transactions(from: from, to: to);
    // Every read path that caches a Future keys off this: a write can change
    // a value without changing the row count (editing an amount), so a
    // "signature" built from the list length alone would keep serving stale
    // numbers for budgets and the trend chart.
    _dataRevision++;
  }

  /// Bumped whenever the transaction list is reloaded from the database.
  ///
  /// Cheap, monotonically increasing staleness token for widgets that cache a
  /// query result: compare it before reusing the cached future.
  int get dataRevision => _dataRevision;
  int _dataRevision = 0;

  Future<void> setMonth(DateTime value) async {
    _month = DateTime(value.year, value.month);
    await _loadMonth();
    notifyListeners();
  }

  Future<void> shiftMonth(int delta) =>
      setMonth(DateTime(_month.year, _month.month + delta));

  PeriodMode _periodMode = PeriodMode.monthly;
  DateTime _selectedDate = DateTime.now();

  PeriodMode get periodMode => _periodMode;
  bool get isDaily => _periodMode == PeriodMode.daily;
  DateTime get selectedDate => _selectedDate;

  void setPeriodMode(PeriodMode mode) {
    if (_periodMode == mode) return;
    _periodMode = mode;
    notifyListeners();
  }

  void togglePeriodMode() {
    _periodMode = _periodMode == PeriodMode.daily
        ? PeriodMode.monthly
        : PeriodMode.daily;
    notifyListeners();
  }

  Future<void> setSelectedDate(DateTime date) async {
    _selectedDate = DateTime(date.year, date.month, date.day);
    if (_selectedDate.year != _month.year || _selectedDate.month != _month.month) {
      _month = DateTime(_selectedDate.year, _selectedDate.month);
      await _loadMonth();
    }
    notifyListeners();
  }

  Future<void> shiftDate(int deltaDays) async {
    await setSelectedDate(_selectedDate.add(Duration(days: deltaDays)));
  }

  Future<void> shiftPeriod(int delta) async {
    if (_periodMode == PeriodMode.daily) {
      await shiftDate(delta);
    } else {
      await shiftMonth(delta);
    }
  }

  // ------------------------------------------------------------- summaries
  //
  // Derived values are cached instead of recomputed per read: a single
  // dashboard frame reads these getters more than a dozen times, and each
  // uncached read was a full pass over the month's transactions. The cache is
  // keyed on the exact list instance (query results are always a fresh
  // instance, and nothing mutates the list in place), the period mode and the
  // selected day — so it can only serve values derived from the same inputs.
  List<Transaction>? _sumFor;
  PeriodMode? _sumMode;
  DateTime? _sumDay;
  num _sumDailyIncome = 0;
  num _sumDailyExpense = 0;
  num _sumMonthIncome = 0;
  num _sumMonthExpense = 0;
  List<Transaction> _sumPeriodList = const [];

  /// Recomputes the cached summaries in a single pass when any input changed.
  void _ensureSummaries() {
    final txs = transactions;
    if (identical(_sumFor, txs) &&
        _sumMode == _periodMode &&
        _sumDay == _selectedDate) {
      return;
    }

    const sameDay = Formatters.isSameDay;
    num dIn = 0, dEx = 0, mIn = 0, mEx = 0;
    final isDaily = _periodMode == PeriodMode.daily;
    final periodList = isDaily ? <Transaction>[] : txs;

    for (final t in txs) {
      final isDay = sameDay(t.date, _selectedDate);
      if (t.isIncome) {
        mIn += t.amount;
        if (isDay) dIn += t.amount;
      } else if (t.type == TxType.expense) {
        mEx += t.amount;
        if (isDay) dEx += t.amount;
      }
      if (isDaily && isDay) periodList.add(t);
    }

    _sumFor = txs;
    _sumMode = _periodMode;
    _sumDay = _selectedDate;
    _sumDailyIncome = dIn;
    _sumDailyExpense = dEx;
    _sumMonthIncome = mIn;
    _sumMonthExpense = mEx;
    _sumPeriodList = periodList;
  }

  num get dailyIncome {
    _ensureSummaries();
    return _sumDailyIncome;
  }

  num get dailyExpense {
    _ensureSummaries();
    return _sumDailyExpense;
  }

  num get dailyNet => dailyIncome - dailyExpense;

  num get periodIncome => _periodMode == PeriodMode.daily ? dailyIncome : monthIncome;
  num get periodExpense => _periodMode == PeriodMode.daily ? dailyExpense : monthExpense;
  num get periodNet => periodIncome - periodExpense;

  List<Transaction> get periodTransactions {
    _ensureSummaries();
    return _sumPeriodList;
  }

  num get monthIncome {
    _ensureSummaries();
    return _sumMonthIncome;
  }

  num get monthExpense {
    _ensureSummaries();
    return _sumMonthExpense;
  }

  num get monthNet => monthIncome - monthExpense;

  num get totalBalance =>
      walletBalances.values.fold<num>(0, (sum, v) => sum + v);

  List<Transaction> get recent =>
      transactions.take(8).toList(growable: false);

  Category? categoryOf(int? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// The category list the editor should show for a given direction.
  List<Category> categoriesFor(TxType type) => categories
      .where((c) => c.isIncome == (type == TxType.income))
      .toList(growable: false);

  Wallet? walletOf(int id) {
    for (final w in wallets) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// Balance of a single wallet, derived from the opening amount plus every
  /// transaction already folded into [walletBalances].
  num balanceOf(int walletId) => walletBalances[walletId] ?? 0;

  /// Income and expense totals for the last [count] months, oldest first.
  ///
  /// One combined query per month, all months issued together: the previous
  /// version awaited 2 queries sequentially per month, so a 12-month chart
  /// paid for 24 round-trips before it could draw.
  Future<List<MonthlyTotal>> monthlyTotals(int count) async {
    final months = [
      for (var i = count - 1; i >= 0; i--)
        DateTime(_month.year, _month.month - i),
    ];
    final totals = await Future.wait(
      months.map((m) {
        final from = DateTime(m.year, m.month, 1);
        final to = DateTime(m.year, m.month + 1, 1);
        return _repo.incomeExpenseFor(from: from, to: to);
      }),
    );

    return [
      for (var i = 0; i < months.length; i++)
        MonthlyTotal(
          month: months[i],
          income: totals[i].$1,
          expense: totals[i].$2,
        ),
    ];
  }

  /// Budget usage for the visible month, sorted by how close each cap is.
  Future<List<BudgetProgress>> budgetProgress() async {
    final budgets = await _repo.budgetsFor(monthKey);
    if (budgets.isEmpty) return const [];

    final (from, to) = _monthWindow;
    final spent = await _repo.spendByCategory(
      from: from,
      to: to,
      type: TxType.expense,
    );

    final list = budgets.map((b) {
      final used = spent[b.categoryId] ?? 0;
      return BudgetProgress(
        budget: b,
        category: categoryOf(b.categoryId),
        spent: used,
        month: _month,
      );
    }).toList();

    list.sort((a, b) => b.ratio.compareTo(a.ratio));
    return list;
  }

  // ---------------------------------------------------------------- writes

  Future<void> addTransaction(Transaction t) async {
    await _repo.insertTransaction(t);
    await refreshAll();
  }

  Future<void> updateTransaction(Transaction t) async {
    await _repo.updateTransaction(t);
    await refreshAll();
  }

  /// Deletes and returns the row so the caller can offer an undo.
  ///
  /// The row is read back from the database rather than looked up in the
  /// month cache: an undo must work even if the list is filtered or the user
  /// navigated to another month between opening and deleting the record.
  Future<Transaction?> deleteTransaction(int id) async {
    final rows = await _repo.transactionsById(id);
    final removed = rows.isEmpty ? null : rows.first;
    await _repo.deleteTransaction(id);
    await refreshAll();
    return removed;
  }

  Future<void> restoreTransaction(Transaction t) async {
    await _repo.restoreTransaction(t);
    await refreshAll();
  }

  /// Synchronous lookup in the list this state already holds.
  ///
  /// Used by the paths that capture a transaction up front so the same row can
  /// be restored later; a scan of the loaded month is cheaper and more
  /// predictable than another async round trip through the repository.
  Transaction? transactionById(int id) {
    for (final t in transactions) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> addWallet(String name, num opening, int colorIndex) async {
    await _repo.insertWallet(
      Wallet(
        id: 0,
        name: name,
        openingBalance: opening,
        colorIndex: colorIndex,
      ),
    );
    await refreshAll();
  }

  Future<void> updateWallet(Wallet w) async {
    await _repo.updateWallet(w);
    await refreshAll();
  }

  Future<void> deleteWallet(int id) async {
    await _repo.deleteWallet(id);
    await refreshAll();
  }

  Future<void> addCategory(
    String name,
    int iconCode,
    int colorIndex, {
    required bool isIncome,
  }) async {
    await _repo.insertCategory(
      Category(
        id: 0,
        name: name,
        iconCode: iconCode,
        colorIndex: colorIndex,
        isIncome: isIncome,
      ),
    );
    await refreshAll();
  }

  Future<void> archiveCategory(int id) async {
    await _repo.archiveCategory(id);
    await refreshAll();
  }

  // ---------------------------------------------------------------- budgets

  /// Bumped whenever a cap is written.
  ///
  /// [budgetProgress] is asynchronous, so callers cache its Future. Without a
  /// value that changes on write they would have no cheap way to tell that the
  /// cached list is stale.
  int get budgetsRevision => _budgetsRevision;
  int _budgetsRevision = 0;

  /// Creates or updates a budget for its month.
  ///
  /// Budgets are identified by (category, month) in the database, so the
  /// caller's intent — not the row id — decides insert vs update. Editing a
  /// budget onto a category that already has a cap for the same month would
  /// otherwise violate the UNIQUE constraint and throw, so the existing row
  /// is reused and only its limit is written.
  Future<void> saveBudget(Budget budget) async {
    final existing = await _repo.budgetsFor(budget.monthKey);

    Budget? sameCategory;
    Budget? sameId;
    for (final b in existing) {
      if (b.categoryId == budget.categoryId) sameCategory = b;
      if (budget.id != null && b.id == budget.id) sameId = b;
    }

    final target = sameCategory ?? sameId;

    if (target != null) {
      await _repo.updateBudget(
        budget.copyWith(id: target.id),
      );
    } else {
      await _repo.insertBudget(budget);
    }

    _budgetsRevision++;
    notifyListeners();
  }

  /// Sets (or clears) the cap for [categoryId] in the visible month.
  ///
  /// A limit of zero or less means "no budget": storing a zero row would leave
  /// an empty progress bar the user cannot remove from the editor, since the
  /// editor's only other exit is Cancel.
  Future<void> setBudget(int categoryId, num limit) async {
    final existing = await _repo.budgetsFor(monthKey);
    for (final b in existing) {
      if (b.categoryId == categoryId) {
        if (limit <= 0) {
          await _repo.deleteBudget(b.id!);
        } else {
          await _repo.updateBudget(b.copyWith(limitAmount: limit));
        }
        _budgetsRevision++;
        notifyListeners();
        return;
      }
    }
    if (limit <= 0) {
      // Nothing stored and nothing to store: still notify so a UI showing a
      // stale list settles on the empty state.
      _budgetsRevision++;
      notifyListeners();
      return;
    }
    await _repo.insertBudget(
      Budget(
        id: 0,
        categoryId: categoryId,
        monthKey: monthKey,
        limitAmount: limit,
      ),
    );
    _budgetsRevision++;
    notifyListeners();
  }

  Future<void> deleteBudget(int id) async {
    await _repo.deleteBudget(id);
    _budgetsRevision++;
    notifyListeners();
  }

  /// Copies last month's caps into the visible month.
  ///
  /// Refreshes and notifies before returning: the caller shows a snackbar with
  /// the count, and a list that did not repaint would make the copy look like
  /// it silently failed.
  Future<int> copyBudgetsFromPreviousMonth() async {
    final prev = DateTime(_month.year, _month.month - 1);
    final fromKey = '${prev.year}-${prev.month.toString().padLeft(2, '0')}';
    final copied = await _repo.copyBudgetsFrom(fromMonth: fromKey, toMonth: monthKey);
    _budgetsRevision++;
    notifyListeners();
    return copied;
  }

  // ------------------------------------------------------------------ goals

  /// Inserts a new goal or updates the existing one, keyed on [goal].
  Future<void> saveGoal(SavingsGoal goal) async {
    if (goal.id == 0) {
      await _repo.insertGoal(goal);
    } else {
      await _repo.updateGoal(goal);
    }
    await refreshAll();
  }

  Future<void> addGoal(
    String name,
    num target,
    DateTime? deadline,
    int colorIndex,
  ) async {
    await _repo.insertGoal(
      SavingsGoal(
        id: 0,
        name: name,
        targetAmount: target,
        savedAmount: 0,
        colorIndex: colorIndex,
        deadline: deadline,
      ),
    );
    await refreshAll();
  }

  /// Returns the amount actually credited, so callers can tell the user what
  /// happened instead of assuming the whole request landed.
  Future<num> contributeToGoal(int id, num amount) async {
    final added = await _repo.contributeToGoal(id, amount);
    await refreshAll();
    return added;
  }

  /// Fills a goal from a real wallet, recording the money movement as a normal
  /// transaction so the wallet balance stays truthful instead of the goal
  /// growing out of thin air.
  ///
  /// The transaction and goal credit run inside a single database transaction,
  /// so both happen or neither does — no money is lost if the process dies
  /// mid-way.
  ///
  /// Returns the credited amount, or null when there was nothing to do, e.g.
  /// the goal is already complete or no expense category exists to file the
  /// movement under.
  Future<num?> fundGoalFromWallet({
    required int goalId,
    required num amount,
    required int walletId,
    required bool isIncome,
  }) async {
    if (amount <= 0) return null;

    final goal = await _repo.goalByIdAsync(goalId);
    if (goal == null || goal.remaining <= 0) return 0;

    // A top-up is filed as an expense; a payout (money coming back out of the
    // goal) as income. Each needs a category of the matching type, because the
    // schema ties every transaction to one.
    final categories = categoriesFor(
      isIncome ? TxType.income : TxType.expense,
    );
    if (categories.isEmpty) return null;

    final added = await _repo.fundGoalFromWalletAtomic(
      goalId: goalId,
      amount: amount,
      walletId: walletId,
      categoryId: categories.first.id,
      type: isIncome ? TxType.income : TxType.expense,
      note: '${isIncome ? 'Payout' : 'Top-up'}: ${goal.name}',
      date: DateTime.now(),
    );

    await refreshAll();
    return added;
  }

  Future<void> deleteGoal(int id) async {
    await _repo.deleteGoal(id);
    await refreshAll();
  }

  // -------------------------------------------------------------- recurring

  Future<void> addRecurring(RecurringRule rule) async {
    await _repo.insertRecurring(rule);
    await refreshAll();
  }

  Future<void> updateRecurring(RecurringRule rule) async {
    await _repo.updateRecurring(rule);
    await refreshAll();
  }

  Future<void> deleteRecurring(int id) async {
    await _repo.deleteRecurring(id);
    await refreshAll();
  }

  // ----------------------------------------------------------------- backup

  /// Copies the live database to a user-visible path so it can be shared.
  Future<File> exportBackup() async {
    await _db.checkpoint();
    final dir = await getDatabasesPath();
    final src = File(p.join(dir, 'duitku.db'));
    final outDir = Directory(await _documentsDir());
    if (!await outDir.exists()) await outDir.create(recursive: true);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final dest = File(p.join(outDir.path, 'duitku-backup-$stamp.db'));
    await src.copy(dest.path);
    return dest;
  }

  Future<String> getApplicationDocumentsDirectoryPath() => _documentsDir();

  Future<String> _documentsDir() async {
    final dbDir = await getDatabasesPath();
    return Directory(dbDir).parent.path;
  }

  /// Replaces the live database with [file]'s contents.
  ///
  /// The incoming file is validated and the current database is renamed aside
  /// first: an import that fails halfway would otherwise leave the user with
  /// no data at all. If anything goes wrong the backup is restored, so the
  /// worst case is "nothing changed".
  Future<void> importBackup(File file) async {
    _importing = true;
    try {
      await _importBackupUnsafe(file);
    } finally {
      // Clear the flag only after the refresh inside _importBackupUnsafe has
      // finished, so the new database state is visible to callers.
      _importing = false;
    }
  }

  Future<void> _importBackupUnsafe(File file) async {
    // Overwrite the database this state is actually using, not a hard-coded
    // `duitku.db` next to it. The two only coincide in a real install; in a
    // test run, or any future launch that opens a database at another path,
    // restoring to the default file would replace a database nobody is reading
    // and silently leave the live data untouched.
    final dest = File(await AppDatabase.currentPath());
    final stash = File('${dest.path}.pre-import');

    // The destination directory must exist before a rename or copy can land.
    await dest.parent.create(recursive: true);

    await _validateBackup(file);

    await _db.close();

    // Stash the current database and its WAL/SHM companions so rollback can
    // restore all three if the import fails.
    for (final suffix in ['', '-wal', '-shm']) {
      final f = File('${stash.path}$suffix');
      if (await f.exists()) await f.delete();
    }
    for (final suffix in ['', '-wal', '-shm']) {
      final src = File('${dest.path}$suffix');
      if (await src.exists()) {
        await src.rename('${stash.path}$suffix');
      }
    }

    try {
      await file.copy(dest.path);
      _db = await AppDatabase.open();
      _repo = FinanceRepository(_db);

      // Clear the import flag so the refresh can proceed.
      _importing = false;
      await refreshAll();
      // Success: the previous database is no longer needed.
      for (final suffix in ['', '-wal', '-shm']) {
        final f = File('${stash.path}$suffix');
        if (await f.exists()) await f.delete();
      }
    } catch (e) {
      // Put the original back so a bad file cannot destroy real data.
      // Restore all three files (main, WAL, SHM) to keep SQLite consistent.
      for (final suffix in ['', '-wal', '-shm']) {
        final f = File('${dest.path}$suffix');
        if (await f.exists()) await f.delete();
      }
      for (final suffix in ['', '-wal', '-shm']) {
        final src = File('${stash.path}$suffix');
        if (await src.exists()) {
          await src.rename('${dest.path}$suffix');
        }
      }
      _db = await AppDatabase.open();
      _repo = FinanceRepository(_db);
      await refreshAll();
      rethrow;
    }
  }

  /// Rejects files that are not a Duitku database before anything is touched.
  ///
  /// A file is not trusted just because it is valid SQLite, or even because it
  /// has the right table names: a hand-made database with those three tables
  /// but different columns would import cleanly and then crash every screen as
  /// soon as it was queried. The columns and the schema version are checked
  /// too, so a bad file is rejected while the live data is still untouched.
  Future<void> _validateBackup(File file) async {
    if (!await file.exists()) {
      throw const FileSystemException('Backup file no longer exists');
    }

    // Open a throwaway connection and confirm the tables we expect are there.
    // A wrong or corrupt file fails here, while the live database is intact.
    final probe = await openDatabase(
      file.path,
      readOnly: true,
    );
    try {
      // A non-SQLite file does not always throw on open, so prove it reads.
      final integrity = await probe.rawQuery('PRAGMA integrity_check');
      final verdict = integrity.isEmpty
          ? ''
          : (integrity.first.values.first?.toString() ?? '');
      if (verdict != 'ok') {
        throw const FormatException(
          'Not a Duitku backup — the file is not a healthy SQLite database',
        );
      }

      final tables = await probe.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final names = tables
          .map((r) => r['name'])
          .whereType<String>()
          .toSet();

      const required = {'wallets', 'categories', 'transactions'};
      final missing = required.difference(names);
      if (missing.isNotEmpty) {
        throw FormatException(
          'Not a Duitku backup — missing table(s): ${missing.join(', ')}',
        );
      }

      // The column check is what stops a same-named but differently shaped
      // database from being accepted.
      const expectedColumns = {
        'wallets': {'id', 'name', 'opening_balance', 'color_index'},
        'categories': {'id', 'name', 'icon_code', 'color_index', 'is_income'},
        'transactions': {
          'id',
          'type',
          'amount',
          'category_id',
          'wallet_id',
          'occurred_at',
        },
      };

      for (final entry in expectedColumns.entries) {
        final cols = await probe.rawQuery('PRAGMA table_info(${entry.key})');
        final have = cols.map((r) => r['name']).whereType<String>().toSet();
        final lack = entry.value.difference(have);
        if (lack.isNotEmpty) {
          throw FormatException(
            'Not a Duitku backup — table "${entry.key}" is missing '
            'column(s): ${lack.join(', ')}',
          );
        }
      }

      // Refuse a file written by a newer, unknown schema version: importing it
      // would silently corrupt later writes.
      final version = await probe.getVersion();
      if (version > AppDatabase.schemaVersion) {
        throw FormatException(
          'Backup was made by a newer version of Duitku '
          '(schema v$version, this app supports v${AppDatabase.schemaVersion})',
        );
      }
    } finally {
      await probe.close();
    }
  }

  Future<void> wipeEverything() async {
    await _repo.wipe();
    await refreshAll();
  }
}

/// One month of income/expense history, used by the trend chart.
class MonthlyTotal {
  const MonthlyTotal({
    required this.month,
    required this.income,
    required this.expense,
  });

  final DateTime month;
  final num income;
  final num expense;

  num get net => income - expense;
}

/// A budget plus its live consumption, ready for the UI.
class BudgetProgress {
  const BudgetProgress({
    required this.budget,
    required this.category,
    required this.spent,
    this.month,
  });

  final Budget budget;
  final Category? category;
  final num spent;

  /// The month being viewed; drives the "days left" hint.
  final DateTime? month;

  num get limit => budget.limitAmount;
  num get remaining => (limit - spent).clamp(0, limit);
  double get ratio => limit <= 0 ? 0 : (spent / limit).clamp(0.0, 2.0);
  bool get over => spent > limit;

  String get monthKey => budget.monthKey;

  /// Days remaining in the viewed month, or null when the month is unknown.
  int? get daysLeftInMonth {
    final m = month;
    if (m == null) return null;
    final last = DateTime(m.year, m.month + 1, 0).day;
    final now = DateTime.now();
    if (now.year != m.year || now.month != m.month) return null;
    return (last - now.day).clamp(0, last);
  }
}
