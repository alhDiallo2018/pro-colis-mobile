class Broadcast {
  final String id;
  final String title;
  final String message;
  final String? imageUrl;
  final bool scroll;
  final List<String> targetRoles;
  final String type;
  final bool active;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime createdAt;

  const Broadcast({
    required this.id,
    required this.title,
    required this.message,
    this.imageUrl,
    this.scroll = true,
    this.targetRoles = const ['client', 'driver'],
    this.type = 'info',
    this.active = true,
    required this.startsAt,
    required this.endsAt,
    required this.createdAt,
  });

  factory Broadcast.fromJson(Map<String, dynamic> json) {
    // Les anciennes versions mettaient en cache des chaînes vides. Le parseur
    // tolérant permet de relire ces caches tout en exposant de vraies dates aux
    // règles d'activation.
    DateTime? parseDate(dynamic value) {
      final raw = value?.toString().trim();
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return Broadcast(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString(),
      scroll: json['scroll'] == true,
      targetRoles: (json['targetRoles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['client', 'driver'],
      type: json['type']?.toString() ?? 'info',
      active: json['active'] == true,
      startsAt: parseDate(json['startsAt']),
      endsAt: parseDate(json['endsAt']),
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'imageUrl': imageUrl,
        'scroll': scroll,
        'targetRoles': targetRoles,
        'type': type,
        'active': active,
        'startsAt': startsAt?.toIso8601String(),
        'endsAt': endsAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  Broadcast copyWith({
    String? id,
    String? title,
    String? message,
    String? imageUrl,
    bool? scroll,
    List<String>? targetRoles,
    String? type,
    bool? active,
    DateTime? startsAt,
    DateTime? endsAt,
    DateTime? createdAt,
  }) {
    return Broadcast(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      imageUrl: imageUrl ?? this.imageUrl,
      scroll: scroll ?? this.scroll,
      targetRoles: targetRoles ?? this.targetRoles,
      type: type ?? this.type,
      active: active ?? this.active,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
