import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String firstName;
  final String lastName;
  final String? classSection;
  final String? yearLevel;
  final String? photoUrl;
  final List<String> classes; // classIds
  final bool notifySubmission;
  final bool notifyResultUpdate;
  final String? fcmToken;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.firstName = '',
    this.lastName = '',
    this.classSection,
    this.yearLevel,
    this.photoUrl,
    this.classes = const [],
    this.notifySubmission = true,
    this.notifyResultUpdate = true,
    this.fcmToken,
    required this.createdAt,
    this.updatedAt,
  });

  // Convert Firestore document to UserModel
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      classSection: data['classSection'] as String?,
      yearLevel: data['yearLevel'] as String?,
      photoUrl: data['photoUrl'] as String?,
      classes: List<String>.from(data['classes'] ?? []),
      notifySubmission: data['notifySubmission'] ?? true,
      notifyResultUpdate: data['notifyResultUpdate'] ?? true,
      fcmToken: data['fcmToken'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // Convert UserModel to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'firstName': firstName,
      'lastName': lastName,
      'classSection': classSection,
      'yearLevel': yearLevel,
      'photoUrl': photoUrl,
      'classes': classes,
      'notifySubmission': notifySubmission,
      'notifyResultUpdate': notifyResultUpdate,
      'fcmToken': fcmToken,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? firstName,
    String? lastName,
    String? classSection,
    String? yearLevel,
    String? photoUrl,
    List<String>? classes,
    bool? notifySubmission,
    bool? notifyResultUpdate,
    String? fcmToken,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      classSection: classSection ?? this.classSection,
      yearLevel: yearLevel ?? this.yearLevel,
      photoUrl: photoUrl ?? this.photoUrl,
      classes: classes ?? this.classes,
      notifySubmission: notifySubmission ?? this.notifySubmission,
      notifyResultUpdate: notifyResultUpdate ?? this.notifyResultUpdate,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
