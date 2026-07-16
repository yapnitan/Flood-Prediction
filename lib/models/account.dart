class Account {
  String id;
  String name;
  String email;
  String role;

  Account({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: json['role'],
    );
  }
}
