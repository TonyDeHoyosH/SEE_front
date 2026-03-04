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
    // Parse emotions: supports List<int>, List<Map>, comma-separated String
    List<int> parsedEmotions = [];
    final rawEmotions = json['emotion_ids'] ?? json['emotions'];
    if (rawEmotions is String && rawEmotions.isNotEmpty) {
      parsedEmotions = rawEmotions
          .split(',')
          .where((e) => e.isNotEmpty)
          .map(int.parse)
          .toList();
    } else if (rawEmotions is List) {
      parsedEmotions = rawEmotions.map((e) {
        if (e is int) return e;
        if (e is Map) return (e['id'] ?? e['emotionId'] ?? 0) as int;
        return int.tryParse(e.toString()) ?? 0;
      }).toList();
    } else if (json['emotion_id'] != null) {
      parsedEmotions = [json['emotion_id'] as int];
    }

    // Backend returns camelCase: id, title, contentType, contentText, isActive, s3Key, createdAt
    // Local DB returns snake_case: is_active, content, type, audio_path, created_at
    final rawId = json['id'] ?? json['capsuleId'] ?? '';
    final rawTitle = json['title'] ?? '';
    final rawContent =
        json['content'] ?? json['contentText'] ?? json['s3Key'] ?? '';
    final rawIsActive = json['is_active'] ?? json['isActive'] ?? true;
    final rawType = (json['type'] ?? json['contentType'] ?? 'TEXT').toString();
    final rawAudio = json['audio_path'] ?? json['s3Key'];
    final rawCreatedAt = json['created_at'] ?? json['createdAt'];

    return Capsule(
      id: rawId.toString(),
      title: rawTitle.toString(),
      content: rawContent.toString(),
      emotionIds: parsedEmotions,
      isActive: rawIsActive == true || rawIsActive == 1,
      type: rawType,
      audioPath: rawAudio?.toString(),
      createdAt: rawCreatedAt != null
          ? DateTime.tryParse(rawCreatedAt.toString())
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
