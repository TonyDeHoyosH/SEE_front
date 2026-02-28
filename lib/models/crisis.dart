class Crisis {
  final String id;
  final DateTime startedAt;
  final String emotion; // fallback
  final List<int> emotionIds;
  final int intensity;
  final String evaluation;
  final bool breathingCompleted;

  Crisis({
    required this.id,
    required this.startedAt,
    required this.emotion,
    this.emotionIds = const [],
    this.intensity = 5,
    required this.evaluation,
    required this.breathingCompleted,
  });

  factory Crisis.fromJson(Map<String, dynamic> json) {
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
    }

    return Crisis(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      emotion: json['emotion'] as String? ?? 'Desconocida',
      emotionIds: parsedEmotions,
      intensity:
          json['intensity'] as int? ?? json['intensity_level'] as int? ?? 5,
      evaluation: json['evaluation'] as String? ?? '',
      breathingCompleted: json['breathing_completed'] == 1 ||
          json['breathing_completed'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'started_at': startedAt.toIso8601String(),
      'emotion': emotion,
      'emotion_ids': emotionIds.join(','),
      'intensity': intensity,
      'evaluation': evaluation,
      'breathing_completed': breathingCompleted,
    };
  }

  Crisis copyWith({
    String? id,
    DateTime? startedAt,
    String? emotion,
    List<int>? emotionIds,
    int? intensity,
    String? evaluation,
    bool? breathingCompleted,
  }) {
    return Crisis(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      emotion: emotion ?? this.emotion,
      emotionIds: emotionIds ?? this.emotionIds,
      intensity: intensity ?? this.intensity,
      evaluation: evaluation ?? this.evaluation,
      breathingCompleted: breathingCompleted ?? this.breathingCompleted,
    );
  }
}
