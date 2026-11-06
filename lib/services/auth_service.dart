import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_account.dart';

/// Autentikasi lokal (mock). JSONPlaceholder tidak menyediakan endpoint
/// autentikasi, jadi akun disimpan di perangkat lewat SharedPreferences.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const String _accountsKey = 'registered_accounts';
  static const String _sessionKey = 'active_session_email';
  static const String _demoEmail = 'demo@email.com';
  static const String _demoPassword = 'demo12345';

  String? _currentUserEmail;

  String? get currentUserEmail => _currentUserEmail;

  String hashPassword(String password) =>
      sha256.convert(utf8.encode('flutter_api::$password')).toString();

  Future<List<UserAccount>> _loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_accountsKey);
    if (raw == null) return <UserAccount>[];

    final List<dynamic> decoded = jsonDecode(raw);
    return decoded
        .map((item) => UserAccount.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveAccounts(List<UserAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      accounts.map((account) => account.toJson()).toList(),
    );
    await prefs.setString(_accountsKey, encoded);
  }

  UserAccount? _findByEmail(List<UserAccount> accounts, String email) {
    for (final account in accounts) {
      if (account.email == email) return account;
    }
    return null;
  }

  Future<void> ensureDemoAccount() async {
    final accounts = await _loadAccounts();
    if (_findByEmail(accounts, _demoEmail) != null) return;

    accounts.add(
      UserAccount(
        name: 'Demo User',
        email: _demoEmail,
        passwordHash: hashPassword(_demoPassword),
      ),
    );
    await _saveAccounts(accounts);
  }

  static String get demoEmail => _demoEmail;
  static String get demoPassword => _demoPassword;

  /// Mengembalikan null bila berhasil, atau pesan error bila gagal.
  /// Pendaftaran hanya menyimpan akun; pengguna tetap harus login.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final accounts = await _loadAccounts();
    final normalizedEmail = email.trim().toLowerCase();

    if (_findByEmail(accounts, normalizedEmail) != null) {
      return 'Email sudah terdaftar. Silakan login.';
    }

    accounts.add(
      UserAccount(
        name: name.trim(),
        email: normalizedEmail,
        passwordHash: hashPassword(password),
      ),
    );
    await _saveAccounts(accounts);
    return null;
  }

  /// Mengembalikan null bila berhasil, atau pesan error bila gagal.
  Future<String?> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final accounts = await _loadAccounts();
    final normalizedEmail = email.trim().toLowerCase();
    final account = _findByEmail(accounts, normalizedEmail);

    if (account == null) {
      return 'Email belum terdaftar. Silakan signup terlebih dahulu.';
    }
    if (account.passwordHash != hashPassword(password)) {
      return 'Password salah.';
    }

    await _startSession(normalizedEmail, persist: rememberMe);
    return null;
  }

  Future<void> _startSession(String email, {required bool persist}) async {
    _currentUserEmail = email;
    final prefs = await SharedPreferences.getInstance();

    if (persist) {
      await prefs.setString(_sessionKey, email);
    } else {
      await prefs.remove(_sessionKey);
    }
  }

  /// Memulihkan sesi yang tersimpan, dipanggil sekali sebelum runApp.
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserEmail = prefs.getString(_sessionKey);
  }

  Future<void> logout() async {
    _currentUserEmail = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  Future<bool> emailExists(String email) async {
    final accounts = await _loadAccounts();
    return _findByEmail(accounts, email.trim().toLowerCase()) != null;
  }

  /// Reset password lokal: ganti hash lalu hapus sesi lama.
  Future<String?> resetPassword(String email, String newPassword) async {
    final accounts = await _loadAccounts();
    final normalizedEmail = email.trim().toLowerCase();
    final account = _findByEmail(accounts, normalizedEmail);

    if (account == null) return 'Email tidak ditemukan.';

    final updated = UserAccount(
      name: account.name,
      email: account.email,
      passwordHash: hashPassword(newPassword),
    );

    accounts[accounts.indexOf(account)] = updated;
    await _saveAccounts(accounts);
    await logout();
    return null;
  }
}
