class MoodModel {
  final String? id;
  final String uid;
  final int rating; // 1-5 scale
  final String mood; // happy, sad, stressed, angry, neutral
  final String? note;
  final List<String> triggers;
  final DateTime createdAt;

  MoodModel({
    this.id,
    required this.uid,
    required this.rating,
    required this.mood,
    this.note,
    this.triggers = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'rating': rating,
      'mood': mood,
      'note': note,
      'triggers': triggers,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MoodModel.fromMap(Map<String, dynamic> map, String id) {
    return MoodModel(
      id: id,
      uid: map['uid'] ?? '',
      rating: map['rating'] ?? 3,
      mood: map['mood'] ?? 'neutral',
      note: map['note'],
      triggers: List<String>.from(map['triggers'] ?? []),
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}