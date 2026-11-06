class UserAccount {
  final String name;
  final String email;
  final String passwordHash;

  const UserAccount({
    required this.name,
    required this.email,
    required this.passwordHash,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'passwordHash': passwordHash,
  };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
    name: json['name'] as String,
    email: json['email'] as String,
    passwordHash: json['passwordHash'] as String,
  );
}
