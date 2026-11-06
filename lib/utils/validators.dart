class Validators {
  static final RegExp _emailPattern =
      RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  static String? email(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Email wajib diisi';
    if (!_emailPattern.hasMatch(input)) {
      return 'Format email tidak valid, contoh: budi@mail.com';
    }
    return null;
  }

  static String? password(String? value) {
    final input = value ?? '';
    if (input.isEmpty) return 'Password wajib diisi';
    if (input.length < 8) return 'Password minimal 8 karakter';
    return null;
  }

  static String? name(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Nama wajib diisi';
    if (input.length < 3) return 'Nama minimal 3 karakter';
    return null;
  }

  static String? confirmPassword(String original, String? value) {
    if (value == null || value.isEmpty) return 'Ulangi password';
    if (value != original) return 'Password tidak cocok';
    return null;
  }

  static String? required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label wajib diisi';
    return null;
  }

  static int strength(String value) {
    int score = 0;
    if (value.length >= 8) score++;
    if (value.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    return score > 4 ? 4 : score;
  }
}
