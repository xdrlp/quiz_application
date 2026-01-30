import 'package:cloud_firestore/cloud_firestore.dart';

class QuizModel {
  final String id;
  final String title;
  final String description;
  final int timeLimitSeconds;
  final List<String> classIds; // empty means public
  final String? quizCode; // unique code to join
  final bool published;
  final String createdBy; // userId
  final bool randomizeQuestions;
  final bool randomizeOptions;
  final bool singleResponse;
  final String scoringType; // 'auto' | 'manual'
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int totalQuestions;
  final String? password; // Optional password for accessing the quiz

  QuizModel({
    required this.id,
    required this.title,
    required this.description,
    required this.timeLimitSeconds,
    this.classIds = const [],
    this.quizCode,
    required this.published,
    required this.createdBy,
    this.randomizeQuestions = false,
    this.randomizeOptions = false,
    this.singleResponse = false,
    this.scoringType = 'auto',
    required this.createdAt,
    this.updatedAt,
    this.totalQuestions = 0,
    this.password,
  });

  factory QuizModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuizModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      timeLimitSeconds: data['timeLimitSeconds'] ?? 0,
      classIds: List<String>.from(data['classIds'] ?? []),
      quizCode: data['quizCode'],
      published: data['published'] ?? false,
      createdBy: data['createdBy'] ?? '',
      randomizeQuestions: data['randomizeQuestions'] ?? false,
      randomizeOptions: data['randomizeOptions'] ?? false,
      singleResponse: data['singleResponse'] ?? false,
      scoringType: data['scoringType'] ?? 'auto',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      totalQuestions: data['totalQuestions'] ?? 0,
      password: data['password'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'timeLimitSeconds': timeLimitSeconds,
      'classIds': classIds,
      'quizCode': quizCode,
      'published': published,
      'createdBy': createdBy,
      'randomizeQuestions': randomizeQuestions,
      'randomizeOptions': randomizeOptions,
      'singleResponse': singleResponse,
      'scoringType': scoringType,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
      'totalQuestions': totalQuestions,
      'password': password,
    };
  }

  QuizModel copyWith({
    String? id,
    String? title,
    String? description,
    int? timeLimitSeconds,
    List<String>? classIds,
    String? quizCode,
    bool? published,
    String? createdBy,
    bool? randomizeQuestions,
    bool? randomizeOptions,
    bool? singleResponse,
    String? scoringType,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalQuestions,
    String? password,
  }) {
    return QuizModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      timeLimitSeconds: timeLimitSeconds ?? this.timeLimitSeconds,
      classIds: classIds ?? this.classIds,
      quizCode: quizCode ?? this.quizCode,
      published: published ?? this.published,
      createdBy: createdBy ?? this.createdBy,
      randomizeQuestions: randomizeQuestions ?? this.randomizeQuestions,
      randomizeOptions: randomizeOptions ?? this.randomizeOptions,
      singleResponse: singleResponse ?? this.singleResponse,
      scoringType: scoringType ?? this.scoringType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      password: password ?? this.password,
    );
  }
}
