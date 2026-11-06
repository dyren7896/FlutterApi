import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_api/services/auth_service.dart';
import 'package:flutter_api/utils/validators.dart';

void main() {
  group('Validators', () {
    test('email menolak nilai kosong dan format salah', () {
      expect(Validators.email(''), 'Email wajib diisi');
      expect(Validators.email('budi'), isNotNull);
      expect(Validators.email('budi@mail'), isNotNull);
      expect(Validators.email('budi@mail.com'), isNull);
    });

    test('password menolak kurang dari 8 karakter', () {
      expect(Validators.password(''), 'Password wajib diisi');
      expect(Validators.password('1234567'), isNotNull);
      expect(Validators.password('12345678'), isNull);
    });

    test('confirmPassword mendeteksi ketidakcocokan', () {
      expect(Validators.confirmPassword('abcdef12', 'abcdef13'), isNotNull);
      expect(Validators.confirmPassword('abcdef12', 'abcdef12'), isNull);
    });

    test('kekuatan password meningkat bersama variasi karakter', () {
      expect(Validators.strength('abc'), 0);
      expect(Validators.strength('abcdefgh'), 1);
      expect(Validators.strength('Abcdefgh1!'), greaterThan(1));
    });
  });

  group('AuthService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('register lalu login dengan password benar berhasil', () async {
      final auth = AuthService.instance;

      expect(
        await auth.register(
          name: 'Mahasiswa',
          email: 'Mhs@Mail.com',
          password: 'rahasia123',
        ),
        isNull,
      );

      await auth.logout();

      final error = await auth.login(
        email: 'mhs@mail.com',
        password: 'rahasia123',
        rememberMe: true,
      );

      expect(error, isNull);
      expect(auth.currentUserEmail, 'mhs@mail.com');
    });

    test('register tidak membuat sesi login otomatis', () async {
      final auth = AuthService.instance;
      await auth.logout();

      await auth.register(
        name: 'Mahasiswa',
        email: 'belum.login@mail.com',
        password: 'rahasia123',
      );

      expect(auth.currentUserEmail, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_session_email'), isNull);
    });

    test('email yang sama tidak bisa didaftarkan dua kali', () async {
      final auth = AuthService.instance;

      await auth.register(
        name: 'Mahasiswa',
        email: 'duplikat@mail.com',
        password: 'rahasia123',
      );

      final error = await auth.register(
        name: 'Mahasiswa Dua',
        email: 'duplikat@mail.com',
        password: 'rahasia456',
      );

      expect(error, 'Email sudah terdaftar. Silakan login.');
    });

    test('login menolak password salah dan email belum terdaftar', () async {
      final auth = AuthService.instance;

      await auth.register(
        name: 'Mahasiswa',
        email: 'salah@mail.com',
        password: 'rahasia123',
      );

      expect(
        await auth.login(
          email: 'salah@mail.com',
          password: 'rahasia999',
          rememberMe: true,
        ),
        'Password salah.',
      );

      expect(
        await auth.login(
          email: 'tidakada@mail.com',
          password: 'rahasia123',
          rememberMe: true,
        ),
        isNotNull,
      );
    });

    test('reset password membuat password lama tidak berlaku', () async {
      final auth = AuthService.instance;

      await auth.register(
        name: 'Mahasiswa',
        email: 'reset@mail.com',
        password: 'rahasia123',
      );

      expect(
        await auth.resetPassword('reset@mail.com', 'passwordbaru1'),
        isNull,
      );

      expect(
        await auth.login(
          email: 'reset@mail.com',
          password: 'rahasia123',
          rememberMe: true,
        ),
        'Password salah.',
      );

      expect(
        await auth.login(
          email: 'reset@mail.com',
          password: 'passwordbaru1',
          rememberMe: true,
        ),
        isNull,
      );
    });

    test('rememberMe false tidak menyimpan sesi ke penyimpanan', () async {
      final auth = AuthService.instance;

      await auth.register(
        name: 'Mahasiswa',
        email: 'inget@mail.com',
        password: 'rahasia123',
      );
      await auth.logout();

      await auth.login(
        email: 'inget@mail.com',
        password: 'rahasia123',
        rememberMe: false,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_session_email'), isNull);
      expect(auth.currentUserEmail, 'inget@mail.com');
    });
  });
}
