import 'package:cloud_firestore/cloud_firestore.dart';

enum ViolationType {
  screenshot,
  appSwitch,
  splitScreen,
  screenResize,
  rapidResponse,
  copyPaste,
  other,
}

class ViolationModel {
  final String id;
  final String attemptId;
  final String userId;
  final ViolationType type;
  final String? details;
  final DateTime detectedAt;

  ViolationModel({
    required this.id,
    required this.attemptId,
    required this.userId,
    required this.type,
    this.details,
    required this.detectedAt,
  });

  factory ViolationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ViolationModel(
      id: doc.id,
      attemptId: data['attemptId'] ?? '',
      userId: data['userId'] ?? '',
      type: ViolationType.values[(data['type'] as int?) ?? 6], // default 'other'
      details: data['details'],
      detectedAt:
          (data['detectedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'attemptId': attemptId,
      'userId': userId,
      'type': type.index,
      'details': details,
      'detectedAt': Timestamp.fromDate(detectedAt),
    };
  }
}
