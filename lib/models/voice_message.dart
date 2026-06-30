// lib/models/voice_message.dart

import 'dart:io';

class VoiceMessage {
  final String path;
  final int duration;
  final DateTime createdAt;

  VoiceMessage({
    required this.path,
    required this.duration,
    required this.createdAt,
  });

  factory VoiceMessage.fromJson(Map<String, dynamic> json) {
    return VoiceMessage(
      path: json['path']?.toString() ?? '',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'].toString()) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'duration': duration,
    'createdAt': createdAt.toIso8601String(),
  };

  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedTime {
    return '${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> delete() async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignorer les erreurs de suppression
    }
  }

  bool get exists {
    try {
      return File(path).existsSync();
    } catch (e) {
      return false;
    }
  }
}