import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String? id;
  final String uid;
  final String title;
  final String description;
  final String addiction;
  final bool completed;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final String? proofImageUrl;
  final int treeGrowthPoints;
  final DateTime? updatedAt;

  TaskModel({
    this.id,
    required this.uid,
    required this.title,
    this.description = '',
    this.addiction = 'General',
    this.completed = false,
    this.createdAt,
    this.completedAt,
    this.proofImageUrl,
    this.treeGrowthPoints = 0,
    this.updatedAt,
  });

  factory TaskModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final Timestamp? createdTs = map['createdAt'] as Timestamp?;
    final Timestamp? completedTs = map['completedAt'] as Timestamp?;
    final Timestamp? updatedTs = map['updatedAt'] as Timestamp?;

    return TaskModel(
      id: id,
      uid: map['uid'] ?? map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      addiction: map['addiction'] ?? 'General',
      completed: map['completed'] ?? false,
      createdAt: createdTs?.toDate(),
      completedAt: completedTs?.toDate(),
      proofImageUrl: map['proofImageUrl'] as String?,
      treeGrowthPoints: (map['treeGrowthPoints'] is int)
          ? map['treeGrowthPoints'] as int
          : (map['treeGrowthPoints'] is double ? (map['treeGrowthPoints'] as double).toInt() : 0),
      updatedAt: updatedTs?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'title': title,
      'description': description,
      'addiction': addiction,
      'completed': completed,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'completedAt': completed && completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'proofImageUrl': proofImageUrl,
      'treeGrowthPoints': treeGrowthPoints,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    }..removeWhere((k, v) => v == null);
  }
}