import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_api/main.dart';
import 'package:flutter_api/screens/login_screen.dart';
import 'package:flutter_api/screens/posts_screen.dart';
import 'package:flutter_api/screens/signup_screen.dart';
import 'package:flutter_api/services/auth_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.logout();
    await AuthService.instance.ensureDemoAccount();
  });

  group('Halaman awal aplikasi', () {
    testWidgets('Belum login: yang muncul adalah halaman Login', (tester) async {
      await tester.pumpWidget(const PostsExplorerApp());

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(PostsScreen), findsNothing);
    });

    testWidgets('Sudah login: langsung ke halaman daftar post', (tester) async {
      await AuthService.instance.login(
        email: AuthService.demoEmail,
        password: AuthService.demoPassword,
        rememberMe: true,
      );

      await tester.pumpWidget(const PostsExplorerApp());

      expect(find.byType(PostsScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });
  });

  group('Alur login lewat form', () {
    Future<void> isiForm(
      WidgetTester tester, {
      required String email,
      required String password,
    }) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), email);
      await tester.enterText(fields.at(1), password);
    }

    testWidgets('Klik Login dengan akun demo berpindah ke daftar post', (tester) async {
      await tester.pumpWidget(const PostsExplorerApp());

      await isiForm(
        tester,
        email: AuthService.demoEmail,
        password: AuthService.demoPassword,
      );
      await tester.tap(find.text('Login'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(PostsScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('Password salah tetap di halaman Login dengan pesan error', (tester) async {
      await tester.pumpWidget(const PostsExplorerApp());

      await isiForm(
        tester,
        email: AuthService.demoEmail,
        password: 'passwordsalah1',
      );
      await tester.tap(find.text('Login'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Password salah.'), findsOneWidget);
    });

    testWidgets('Form kosong menampilkan pesan validasi, tidak mengirim apa pun', (tester) async {
      await tester.pumpWidget(const PostsExplorerApp());

      await tester.tap(find.text('Login'));
      await tester.pump();

      expect(find.text('Email wajib diisi'), findsOneWidget);
      expect(find.text('Password wajib diisi'), findsOneWidget);
      expect(find.byType(PostsScreen), findsNothing);
    });

    testWidgets('Email belum terdaftar ditolak', (tester) async {
      await tester.pumpWidget(const PostsExplorerApp());

      await isiForm(
        tester,
        email: 'tidakada@mail.com',
        password: 'rahasia123',
      );
      await tester.tap(find.text('Login'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Email belum terdaftar. Silakan signup terlebih dahulu.'),
        findsOneWidget,
      );
    });
  });

  group('Alur signup', () {
    testWidgets(
      'Setelah daftar, kembali ke halaman Login lalu baru bisa masuk',
      (tester) async {
        await tester.pumpWidget(const PostsExplorerApp());

        await tester.tap(find.text('Signup di sini'));
        await tester.pumpAndSettle();

        final signupFields = find.byType(TextFormField);
        await tester.enterText(signupFields.at(0), 'Mahasiswa Baru');
        await tester.enterText(signupFields.at(1), 'baru@mail.com');
        await tester.enterText(signupFields.at(2), 'rahasia123');
        await tester.enterText(signupFields.at(3), 'rahasia123');
        await tester.tap(
          find.text('Saya menyetujui syarat & ketentuan yang berlaku'),
        );
        await tester.pump();
        await tester.ensureVisible(find.text('Daftar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Daftar'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(PostsScreen), findsNothing);
        expect(
          find.text('Pendaftaran berhasil. Silakan login dengan email kamu.'),
          findsOneWidget,
        );

        final loginFields = find.byType(TextFormField);
        await tester.enterText(loginFields.at(0), 'baru@mail.com');
        await tester.enterText(loginFields.at(1), 'rahasia123');
        await tester.tap(find.text('Login'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(PostsScreen), findsOneWidget);
      },
    );

    testWidgets('Centang syarat & ketentuan wajib sebelum daftar', (tester) async {
      await tester.pumpWidget(const PostsExplorerApp());

      await tester.tap(find.text('Signup di sini'));
      await tester.pumpAndSettle();

      final signupFields = find.byType(TextFormField);
      await tester.enterText(signupFields.at(0), 'Mahasiswa Baru');
      await tester.enterText(signupFields.at(1), 'tanpa.terms@mail.com');
      await tester.enterText(signupFields.at(2), 'rahasia123');
      await tester.enterText(signupFields.at(3), 'rahasia123');
      await tester.ensureVisible(find.text('Daftar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Daftar'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Centang persetujuan syarat & ketentuan terlebih dahulu.'),
        findsOneWidget,
      );
      expect(find.byType(SignupScreen), findsOneWidget);
    });
  });
}
