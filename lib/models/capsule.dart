class Capsule {
  final String id;
  final String title;
  final String content;
  final List<int> emotionIds;
  final bool isActive;
  final String type;
  final String? audioPath;
  final DateTime? createdAt;
  final bool isSynced;

  Capsule({
    required this.id,
    required this.title,
    required this.content,
    required this.emotionIds,
    required this.isActive,
    this.type = 'texto',
    this.audioPath,
    this.createdAt,
    this.isSynced = false,
  });

  factory Capsule.fromJson(Map<String, dynamic> json) {
    List<int> parsedEmotions = [];
    if (json['emotion_ids'] != null) {
      if (json['emotion_ids'] is String) {
        parsedEmotions = (json['emotion_ids'] as String)
            .split(',')
            .where((e) => e.isNotEmpty)
            .map(int.parse)
            .toList();
      } else if (json['emotion_ids'] is List) {
        parsedEmotions = List<int>.from(json['emotion_ids']);
      }
    } else if (json['emotion_id'] != null) {
      // Fallback
      parsedEmotions = [json['emotion_id'] as int];
    }

    return Capsule(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      emotionIds: parsedEmotions,
      isActive: json['is_active'] as bool,
      type: json['type'] as String? ?? 'texto',
      audioPath: json['audio_path'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      isSynced: json['is_synced'] == true || json['is_synced'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'emotion_ids': emotionIds.join(','),
      'is_active': isActive,
      'type': type,
      'audio_path': audioPath,
      'created_at': createdAt?.toIso8601String(),
      'is_synced': isSynced,
    };
  }

  Capsule copyWith({
    String? id,
    String? title,
    String? content,
    List<int>? emotionIds,
    bool? isActive,
    String? type,
    String? audioPath,
    DateTime? createdAt,
    bool? isSynced,
  }) {
    return Capsule(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      emotionIds: emotionIds ?? this.emotionIds,
      isActive: isActive ?? this.isActive,
      type: type ?? this.type,
      audioPath: audioPath ?? this.audioPath,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
