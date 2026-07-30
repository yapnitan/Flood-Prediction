class Account {
  String id;
  String name;
  String email;
  String role;

  /// Whether an admin has enabled this account. Disabled accounts should
  /// be blocked at login by the UI/AuthController.
  bool isActive;

  /// Notification preferences, editable from the Profile > Notification
  /// Settings screen.
  bool notifyEmail;
  bool notifyPush;

  Account({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isActive = true,
    this.notifyEmail = true,
    this.notifyPush = true,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: json['role'],
      isActive: json['is_active'] as bool? ?? true,
      notifyEmail: json['notify_email'] as bool? ?? true,
      notifyPush: json['notify_push'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'is_active': isActive,
      'notify_email': notifyEmail,
      'notify_push': notifyPush,
    };
  }

  Account copyWith({
    String? name,
    String? email,
    String? role,
    bool? isActive,
    bool? notifyEmail,
    bool? notifyPush,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      notifyEmail: notifyEmail ?? this.notifyEmail,
      notifyPush: notifyPush ?? this.notifyPush,
    );
  }
}
