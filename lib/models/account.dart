class Account {
  String id;
  String name;
  String email;
  String role;

  /// Admin on/off switch — blocks login regardless of [status]. Any role
  /// can be disabled at any time.
  bool isActive;

  /// Approval workflow — separate from [isActive]. Values: 'pending',
  /// 'active', 'rejected'. New helper sign-ups start as 'pending' and
  /// need an admin to approve them before they can log in.
  String status;

  /// Notification preferences, editable from the Profile > Notification
  /// Settings screen.
  bool notifyEmail;
  bool notifyPush;

  /// Public URL of the user's profile picture, or null if they haven't
  /// set one — the Profile screen falls back to a placeholder icon.
  String? avatarUrl;

  Account({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isActive = true,
    this.status = 'active',
    this.notifyEmail = true,
    this.notifyPush = true,
    this.avatarUrl,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: (json['role'] as String?)?.trim().toLowerCase() ?? 'user',
      isActive: json['is_active'] as bool? ?? true,
      status: (json['status'] as String?)?.trim().toLowerCase() ?? 'active',
      notifyEmail: json['notify_email'] as bool? ?? true,
      notifyPush: json['notify_push'] as bool? ?? true,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'is_active': isActive,
      'status': status,
      'notify_email': notifyEmail,
      'notify_push': notifyPush,
      'avatar_url': avatarUrl,
    };
  }

  Account copyWith({
    String? name,
    String? email,
    String? role,
    bool? isActive,
    String? status,
    bool? notifyEmail,
    bool? notifyPush,
    String? avatarUrl,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      notifyEmail: notifyEmail ?? this.notifyEmail,
      notifyPush: notifyPush ?? this.notifyPush,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
