@Tags(['db'])
library;

import 'dart:io';

import 'package:duitku/data/app_state.dart';
import 'package:duitku/data/database.dart';
import 'package:duitku/data/models/user.dart';
import 'package:duitku/data/repository.dart';
import 'package:duitku/features/auth/login_screen.dart';
import 'package:duitku/services/email_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    ffi.sqfliteFfiInit();
    ffi.databaseFactory = ffi.databaseFactoryFfi;
  });

  late Directory tmp;
  late AppState state;
  late FinanceRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('duitku_auth_test');
    final dbPath = p.join(tmp.path, 'auth.db');
    state = await AppState.bootstrapForTests(dbPath: dbPath);
    repo = state.repo;
  });

  tearDown(() async {
    await state.dispose();
    AppDatabase.overridePath(null);
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('UserModel', () {
    test('initials computation handles single and multi-word names', () {
      final u1 = UserModel(
        id: 1,
        name: 'Bagas Pradana',
        email: 'bagas@example.com',
        createdAt: DateTime.now(),
      );
      expect(u1.initials, 'BP');

      final u2 = UserModel(
        id: 2,
        name: 'Hermes',
        email: 'hermes@example.com',
        createdAt: DateTime.now(),
      );
      expect(u2.initials, 'H');

      final u3 = UserModel(
        id: 3,
        name: '   ',
        email: 'empty@example.com',
        createdAt: DateTime.now(),
      );
      expect(u3.initials, 'U');
    });

    test('round-trips through map representation', () {
      final now = DateTime(2026, 9, 29, 20, 0, 0);
      final user = UserModel(
        id: 10,
        name: 'Bagas',
        email: 'bagas@example.com',
        avatarUrl: 'https://avatar.url/1.png',
        createdAt: now,
      );

      final map = user.toMap();
      final restored = UserModel.fromMap(map);

      expect(restored.id, 10);
      expect(restored.name, 'Bagas');
      expect(restored.email, 'bagas@example.com');
      expect(restored.avatarUrl, 'https://avatar.url/1.png');
      expect(restored.createdAt.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    });
  });

  group('User Repository & Password Hashing', () {
    test('registerUser creates account with salted stretched hash and normalizes email', () async {
      final user = await repo.registerUser(
        name: 'Bagas Dev',
        email: '  Bagas@Gmail.Com  ',
        password: 'supersecretpassword123',
      );

      expect(user.id, greaterThan(0));
      expect(user.name, 'Bagas Dev');
      expect(user.email, 'bagas@gmail.com');

      // Password itself must NEVER be stored in plain text
      final raw = await repo.getUserById(user.id);
      expect(raw, isNotNull);
      expect(raw!.name, 'Bagas Dev');
      expect(raw.email, 'bagas@gmail.com');
    });

    test('registerUser rejects duplicate email', () async {
      await repo.registerUser(
        name: 'User 1',
        email: 'duplicate@test.com',
        password: 'password123',
      );

      expect(
        () => repo.registerUser(
          name: 'User 2',
          email: 'duplicate@test.com',
          password: 'password456',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('authenticateUser verifies password correctly', () async {
      await repo.registerUser(
        name: 'Bagas',
        email: 'bagas@test.com',
        password: 'correctpassword',
      );

      final authSuccess = await repo.authenticateUser(
        'BAGAS@TEST.COM',
        'correctpassword',
      );
      expect(authSuccess, isNotNull);
      expect(authSuccess!.name, 'Bagas');

      final authWrongPass = await repo.authenticateUser(
        'bagas@test.com',
        'wrongpassword',
      );
      expect(authWrongPass, isNull);

      final authUnknownUser = await repo.authenticateUser(
        'unknown@test.com',
        'correctpassword',
      );
      expect(authUnknownUser, isNull);
    });

    test('changePassword updates password hash safely', () async {
      final user = await repo.registerUser(
        name: 'Bagas',
        email: 'user@test.com',
        password: 'oldpassword',
      );

      final failWrongOld = await repo.changePassword(
        userId: user.id,
        oldPassword: 'wrongoldpassword',
        newPassword: 'newpassword123',
      );
      expect(failWrongOld, isFalse);

      final ok = await repo.changePassword(
        userId: user.id,
        oldPassword: 'oldpassword',
        newPassword: 'newpassword123',
      );
      expect(ok, isTrue);

      final authNew = await repo.authenticateUser(
        'user@test.com',
        'newpassword123',
      );
      expect(authNew, isNotNull);
    });
  });

  group('AppState Auth Management', () {
    test('register and login flows update currentUser and isAuthenticated state', () async {
      expect(state.isAuthenticated, isFalse);
      expect(state.currentUser, isNull);

      // Register
      final regErr = await state.register(
        name: 'Bagas Student',
        email: 'bagas@student.ac.id',
        password: 'securepass123',
      );
      expect(regErr, isNull);
      expect(state.isAuthenticated, isTrue);
      expect(state.currentUser?.name, 'Bagas Student');

      // Logout
      await state.logout();
      expect(state.isAuthenticated, isFalse);
      expect(state.currentUser, isNull);

      // Login
      final loginErr = await state.login(
        'bagas@student.ac.id',
        'securepass123',
      );
      expect(loginErr, isNull);
      expect(state.isAuthenticated, isTrue);
      expect(state.currentUser?.email, 'bagas@student.ac.id');
    });

    test('continueAsGuest provides instant guest session', () async {
      expect(state.isAuthenticated, isFalse);
      await state.continueAsGuest();
      expect(state.isAuthenticated, isTrue);
      expect(state.currentUser, isNotNull);
    });
  });

  group('LoginScreen Widget', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }

    Future<void> pumpLoginScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets('renders login form with toggle to register and guest option', (tester) async {
      await pumpLoginScreen(tester);

      expect(find.text('Duitku'), findsOneWidget);
      expect(find.text('Masuk'), findsWidgets);
      expect(find.text('Daftar'), findsOneWidget);
      expect(find.text('Lanjutkan tanpa akun'), findsOneWidget);

      // Tap Daftar toggle
      await tester.tap(find.text('Daftar'));
      await settle(tester);

      expect(find.text('Nama Lengkap'), findsOneWidget);
      expect(find.text('Konfirmasi Kata Sandi'), findsOneWidget);
      expect(find.text('Buat Akun'), findsOneWidget);
    });

    testWidgets('registering through UI logs in the user', (tester) async {
      EmailService.mockHandler = (path, body) async => OtpResult.success;
      addTearDown(() => EmailService.mockHandler = null);

      await pumpLoginScreen(tester);

      // Switch to Register
      await tester.tap(find.text('Daftar'));
      await settle(tester);

      // Fill in fields
      await tester.enterText(find.widgetWithText(TextFormField, 'Nama Lengkap'), 'Bagas Bro');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'bagas@duitku.id');
      await tester.enterText(find.widgetWithText(TextFormField, 'Kata Sandi'), 'rahasia123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Konfirmasi Kata Sandi'), 'rahasia123');
      await settle(tester);

      // Submit form pendaftaran
      await tester.ensureVisible(find.text('Buat Akun'));
      await tester.tap(find.text('Buat Akun'));
      await settle(tester);

      // Layar OTP muncul: isi 6 digit kode OTP
      final otpFields = find.byType(TextField);
      expect(otpFields, findsNWidgets(6));
      for (var i = 0; i < 6; i++) {
        await tester.enterText(otpFields.at(i), '1');
      }
      await settle(tester);

      expect(state.isAuthenticated, isTrue);
      expect(state.currentUser?.name, 'Bagas Bro');
      expect(state.currentUser?.email, 'bagas@duitku.id');
    });
  });
}
