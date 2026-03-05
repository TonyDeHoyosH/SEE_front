class Emotion {
  final int id;
  final String name;

  Emotion({
    required this.id,
    required this.name,
  });

  factory Emotion.fromJson(Map<String, dynamic> json) {
    return Emotion(
      // backend returns 'emotionId', local DB uses 'id'
      id: ((json['emotionId'] ?? json['id']) as num).toInt(),
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  Emotion copyWith({
    int? id,
    String? name,
  }) {
    return Emotion(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}
