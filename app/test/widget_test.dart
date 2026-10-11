// Widget and unit tests for the PaperPay Flutter app.
//
// These tests deliberately avoid Firebase, the network and platform plugins so
// that a plain `flutter test` works on a fresh checkout. Hive is initialised
// against a temporary directory instead of the path_provider-based
// `Hive.initFlutter()`.
//
// Every test is bounded by an explicit timeout so that a widget that never
// settles fails fast instead of hanging the whole suite.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:paperpay/core/constants/app_routes.dart';
import 'package:paperpay/core/utils/formatters.dart';
import 'package:paperpay/core/utils/validators.dart';
import 'package:paperpay/features/auth/models/user_model.dart';
import 'package:paperpay/features/auth/screens/phone_login_screen.dart';
import 'package:paperpay/features/auth/screens/splash_screen.dart';
import 'package:paperpay/main.dart';
import 'package:paperpay/shared/widgets/app_loader.dart';

/// Routes used by the splash-screen tests. Real screens would call the backend,
/// so each destination is replaced by a stub we can assert on.
Map<String, WidgetBuilder> _stubRoutes() => {
      AppRoutes.phoneLogin: (_) => const Text('stub:phone-login'),
      AppRoutes.onboarding: (_) => const Text('stub:onboarding'),
      AppRoutes.adminDashboard: (_) => const Text('stub:admin-dashboard'),
      AppRoutes.customerHome: (_) => const Text('stub:customer-home'),
    };

Widget _hostSplash() {
  return ProviderScope(
    child: MaterialApp(
      routes: _stubRoutes(),
      home: const SplashScreen(),
    ),
  );
}

/// Pumps a bounded number of frames. `pumpAndSettle` would wait up to ten
/// minutes on a never-ending animation, which turns a real failure into a
/// timeout, so frames are advanced explicitly instead.
Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 12; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Persists a user the way the app does before the splash screen boots.
///
/// Hive flushes writes through a debounced timer, which never fires inside the
/// fake-async zone a widget test runs in, so the write is executed with
/// `runAsync` against the real event loop.
Future<void> _storeUser(
  Box<dynamic> box,
  WidgetTester tester,
  UserModel user,
) async {
  await tester.runAsync(() => box.put('current_user', user));
}

/// Advances past the splash screen's 2 second bootstrap delay and lets the
/// replacement route build.
Future<void> _pumpPastSplash(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 3));
  await _settle(tester);
}

@Timeout(Duration(seconds: 45))
void main() {
  late Directory tempDir;
  late Box<dynamic> authBox;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('paperpay_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(UserModelAdapter());
    }
    authBox = await Hive.openBox<dynamic>('paperpay_auth');
  });

  tearDown(() async {
    await authBox.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Validators', () {
    test('accepts valid Indian mobile numbers', () {
      expect(Validators.indianPhone('9876543210'), isNull);
      expect(Validators.isValidIndianPhone('6123456789'), isTrue);
    });

    test('tolerates country code and trunk prefixes', () {
      expect(Validators.indianPhone('+91 98765 43210'), isNull);
      expect(Validators.indianPhone('098765 43210'), isNull);
    });

    test('rejects numbers that are too short, too long or start below 6', () {
      expect(Validators.indianPhone('987654321'), isNotNull);
      expect(Validators.indianPhone('98765432100'), isNotNull);
      expect(Validators.indianPhone('1234567890'), isNotNull);
      expect(Validators.indianPhone('+91 12345 67890'), isNotNull);
      expect(Validators.indianPhone(''), isNotNull);
      expect(Validators.indianPhone(null), isNotNull);
      expect(Validators.isValidIndianPhone('0000000000'), isFalse);
    });

    test('requiredField trims whitespace and names the field', () {
      expect(Validators.requiredField('', fieldName: 'Name'), 'Name is required');
      expect(Validators.requiredField('   ', fieldName: 'Area'), 'Area is required');
      expect(Validators.requiredField('Yash'), isNull);
    });
  });

  group('Formatters', () {
    test('formats currency in INR without paise', () {
      final formatted = Formatters.formatCurrency(1250);
      expect(formatted, contains('1,250'));
      expect(formatted, contains('\u20B9'));
    });

    test('formats dates as dd MMM yyyy', () {
      expect(Formatters.formatDate(DateTime(2026, 2, 7)), '07 Feb 2026');
    });

    test('parses loosely typed numeric payloads defensively', () {
      expect(Formatters.parseDouble('120.50'), 120.5);
      expect(Formatters.parseDouble(12), 12.0);
      expect(Formatters.parseDouble(null), 0.0);
      expect(Formatters.parseDouble('not-a-number'), 0.0);
      expect(Formatters.parseInt('42'), 42);
      expect(Formatters.parseInt(null), 0);
    });
  });

  group('AppLoader', () {
    testWidgets('renders a progress indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppLoader())),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('PhoneLoginScreen', () {
    Widget host() => const ProviderScope(
          child: MaterialApp(home: PhoneLoginScreen()),
        );

    testWidgets('shows the login form with a phone field', (tester) async {
      await tester.pumpWidget(host());

      expect(find.text('Login'), findsOneWidget);
      expect(find.text('+91 '), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'OTP Bhejein'), findsOneWidget);
    });

    testWidgets('blocks submission and shows a validation error for empty input',
        (tester) async {
      await tester.pumpWidget(host());

      await tester.tap(find.widgetWithText(ElevatedButton, 'OTP Bhejein'));
      await tester.pump();

      expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);
      // Still on the login screen: no navigation happened.
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('surfaces an error when Firebase auth is unavailable',
        (tester) async {
      await tester.pumpWidget(host());

      await tester.enterText(find.byType(TextFormField), '9876543210');
      await tester.tap(find.widgetWithText(ElevatedButton, 'OTP Bhejein'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Firebase is not initialised in tests, so the notifier reports a
      // failure instead of silently doing nothing.
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });
  });

  group('SplashScreen routing', () {
    testWidgets('renders branding while bootstrapping', (tester) async {
      await tester.pumpWidget(_hostSplash());
      await tester.pump();

      expect(find.text('PaperPay'), findsOneWidget);
      expect(find.text('Aapka Akhbar, Aapka Hisab'), findsOneWidget);

      await _pumpPastSplash(tester);
    });

    testWidgets('sends a signed-out user to phone login', (tester) async {
      await tester.pumpWidget(_hostSplash());
      await _pumpPastSplash(tester);

      expect(find.text('stub:phone-login'), findsOneWidget);
    });

    testWidgets('sends an agency admin without an agency to onboarding',
        (tester) async {
      await _storeUser(
        authBox,
        tester,
        const UserModel(
          id: 'u1',
          name: 'Owner',
          phone: '9876543210',
          role: 'agency_admin',
        ),
      );

      await tester.pumpWidget(_hostSplash());
      await _pumpPastSplash(tester);

      expect(find.text('stub:onboarding'), findsOneWidget);
    });

    testWidgets('sends an agency admin with an agency to the admin dashboard',
        (tester) async {
      await _storeUser(
        authBox,
        tester,
        const UserModel(
          id: 'u2',
          name: 'Owner',
          phone: '9876543211',
          role: 'agency_admin',
          agencyId: 'agency-1',
        ),
      );

      await tester.pumpWidget(_hostSplash());
      await _pumpPastSplash(tester);

      expect(find.text('stub:admin-dashboard'), findsOneWidget);
    });

    testWidgets('sends a customer to the customer home', (tester) async {
      await _storeUser(
        authBox,
        tester,
        const UserModel(
          id: 'u3',
          name: 'Reader',
          phone: '9876543212',
          role: 'customer',
          agencyId: 'agency-1',
        ),
      );

      await tester.pumpWidget(_hostSplash());
      await _pumpPastSplash(tester);

      expect(find.text('stub:customer-home'), findsOneWidget);
    });
  });

  group('PaperPayApp', () {
    testWidgets('boots on the splash screen and reaches login', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: PaperPayApp()));
      await tester.pump();

      expect(find.text('PaperPay'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await _settle(tester);

      expect(find.text('Login'), findsOneWidget);
    });
  });
}
