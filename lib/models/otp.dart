// mobile/lib/models/otp.dart

class OtpCode {
  final String id;
  final String userId;
  final String code;
  final OtpType type;
  final String? phone;
  final String? email;
  final bool isUsed;
  final DateTime expiresAt;
  final DateTime createdAt;
  final int attempts;

  OtpCode({
    required this.id,
    required this.userId,
    required this.code,
    required this.type,
    this.phone,
    this.email,
    this.isUsed = false,
    required this.expiresAt,
    required this.createdAt,
    this.attempts = 0,
  });

  /// Nombre maximum de tentatives historique, utilisé comme repli quand la
  /// configuration publique (`auth.otpMaxAttempts`) n'a pas encore été chargée.
  /// Préférer `isValidWith(maxAttempts)` dès que la config est disponible.
  static const int defaultMaxAttempts = 5;

  /// Valide avec un plafond de tentatives configurable. Les écrans qui ont
  /// accès à `PublicConfigProvider` doivent passer `config.otpMaxAttempts`.
  bool isValidWith(int maxAttempts) =>
      !isUsed &&
      expiresAt.isAfter(DateTime.now()) &&
      attempts < (maxAttempts > 0 ? maxAttempts : defaultMaxAttempts);

  /// Compat : conserve le comportement historique (`attempts < 5`) pour les
  /// appelants qui n'ont pas encore été migrés vers la config publique.
  bool get isValid => isValidWith(defaultMaxAttempts);

  factory OtpCode.fromJson(Map<String, dynamic> json) {
    return OtpCode(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      type: OtpType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => OtpType.login,
      ),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      isUsed: json['isUsed'] ?? false,
      expiresAt: DateTime.parse(json['expiresAt'].toString()),
      createdAt: DateTime.parse(json['createdAt'].toString()),
      attempts: json['attempts'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'code': code,
    'type': type.name,
    'phone': phone,
    'email': email,
    'isUsed': isUsed,
    'expiresAt': expiresAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'attempts': attempts,
  };
}

enum OtpType {
  login('login'),
  verification('verification'),
  passwordReset('password_reset');

  final String name;
  const OtpType(this.name);
}