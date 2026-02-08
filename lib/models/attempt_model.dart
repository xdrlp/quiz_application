import 'package:cloud_firestore/cloud_firestore.dart';

class AttemptAnswerModel {
  final String questionId;
  final String selectedChoiceId;
  final int timeTakenSeconds;
  final DateTime? answeredAt;
  final bool isCorrect;
  final bool forceIncorrect;
  final bool manuallyEdited;

  AttemptAnswerModel({
    required this.questionId,
    required this.selectedChoiceId,
    required this.timeTakenSeconds,
    this.answeredAt,
    required this.isCorrect,
    this.forceIncorrect = false,
    this.manuallyEdited = false,
  });

  factory AttemptAnswerModel.fromMap(Map<String, dynamic> map) {
    return AttemptAnswerModel(
      questionId: map['questionId'] ?? '',
      selectedChoiceId: map['selectedChoiceId'] ?? '',
      timeTakenSeconds: map['timeTakenSeconds'] ?? 0,
      answeredAt: map['answeredAt'] != null ? (map['answeredAt'] as Timestamp).toDate() : null,
      isCorrect: map['isCorrect'] ?? false,
      forceIncorrect: map['forceIncorrect'] ?? false,
      manuallyEdited: map['manuallyEdited'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'selectedChoiceId': selectedChoiceId,
      'timeTakenSeconds': timeTakenSeconds,
      'answeredAt': answeredAt != null ? Timestamp.fromDate(answeredAt!) : null,
      'isCorrect': isCorrect,
      'forceIncorrect': forceIncorrect,
      'manuallyEdited': manuallyEdited,
    };
  }

  AttemptAnswerModel copyWith({
    String? questionId,
    String? selectedChoiceId,
    int? timeTakenSeconds,
    DateTime? answeredAt,
    bool? isCorrect,
    bool? forceIncorrect,
    bool? manuallyEdited,
  }) {
    return AttemptAnswerModel(
      questionId: questionId ?? this.questionId,
      selectedChoiceId: selectedChoiceId ?? this.selectedChoiceId,
      timeTakenSeconds: timeTakenSeconds ?? this.timeTakenSeconds,
      answeredAt: answeredAt ?? this.answeredAt,
      isCorrect: isCorrect ?? this.isCorrect,
      forceIncorrect: forceIncorrect ?? this.forceIncorrect,
      manuallyEdited: manuallyEdited ?? this.manuallyEdited,
    );
  }
}

class AttemptModel {
  final String id;
  final String quizId;
  final String userId;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final int score;
  final int totalPoints;
  final List<AttemptAnswerModel> answers;
  final int totalViolations;
  final List<Map<String, dynamic>> openedApps;

  AttemptModel({
    required this.id,
    required this.quizId,
    required this.userId,
    required this.startedAt,
    this.submittedAt,
    required this.score,
    required this.totalPoints,
    this.answers = const [],
    this.totalViolations = 0,
    this.openedApps = const [],
  });

  double get scorePercentage {
    if (totalPoints == 0) return 0;
    return (score / totalPoints) * 100;
  }

  factory AttemptModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final answersList = (data['answers'] as List<dynamic>? ?? [])
        .map((a) => AttemptAnswerModel.fromMap(a as Map<String, dynamic>))
        .toList();

    return AttemptModel(
      id: doc.id,
      quizId: data['quizId'] ?? '',
      userId: data['userId'] ?? '',
      startedAt: (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      score: data['score'] ?? 0,
      totalPoints: data['totalPoints'] ?? 0,
      answers: answersList,
      totalViolations: data['totalViolations'] ?? 0,
      openedApps: (data['openedApps'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'quizId': quizId,
      'userId': userId,
      'startedAt': Timestamp.fromDate(startedAt),
      'submittedAt':
          submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
      'score': score,
      'totalPoints': totalPoints,
      'answers': answers.map((a) => a.toMap()).toList(),
      'totalViolations': totalViolations,
      'openedApps': openedApps,
    };
  }

  AttemptModel copyWith({
    String? id,
    String? quizId,
    String? userId,
    DateTime? startedAt,
    DateTime? submittedAt,
    int? score,
    int? totalPoints,
    List<AttemptAnswerModel>? answers,
    int? totalViolations,
    List<Map<String, dynamic>>? openedApps,
  }) {
    return AttemptModel(
      id: id ?? this.id,
      quizId: quizId ?? this.quizId,
      userId: userId ?? this.userId,
      startedAt: startedAt ?? this.startedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      score: score ?? this.score,
      totalPoints: totalPoints ?? this.totalPoints,
      answers: answers ?? this.answers,
      totalViolations: totalViolations ?? this.totalViolations,
      openedApps: openedApps ?? this.openedApps,
    );
  }
}
