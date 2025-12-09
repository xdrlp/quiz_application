import 'package:cloud_firestore/cloud_firestore.dart';

class ClassModel {
  final String id;
  final String name;
  final String teacherUid;
  final List<String> memberUids;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ClassModel({
    required this.id,
    required this.name,
    required this.teacherUid,
    this.memberUids = const [],
    required this.createdAt,
    this.updatedAt,
  });

  factory ClassModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClassModel(
      id: doc.id,
      name: data['name'] ?? '',
      teacherUid: data['teacherUid'] ?? '',
      memberUids: List<String>.from(data['memberUids'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'teacherUid': teacherUid,
      'memberUids': memberUids,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  ClassModel copyWith({
    String? id,
    String? name,
    String? teacherUid,
    List<String>? memberUids,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClassModel(
      id: id ?? this.id,
      name: name ?? this.name,
      teacherUid: teacherUid ?? this.teacherUid,
      memberUids: memberUids ?? this.memberUids,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
