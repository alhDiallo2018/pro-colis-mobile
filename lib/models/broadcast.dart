class Broadcast {
  final String id;
  final String title;
  final String message;
  final String? imageUrl;
  final bool scroll;
  final List<String> targetRoles;
  final String type;
  final bool active;
  final String startsAt;
  final String endsAt;
  final String createdAt;

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
      startsAt: json['startsAt']?.toString() ?? '',
      endsAt: json['endsAt']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
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
        'startsAt': startsAt,
        'endsAt': endsAt,
        'createdAt': createdAt,
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
    String? startsAt,
    String? endsAt,
    String? createdAt,
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
