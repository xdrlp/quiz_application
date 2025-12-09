import 'package:cloud_firestore/cloud_firestore.dart';

enum QuestionType {
  multipleChoice,
  checkbox,
  dropdown,
  shortAnswer,
  paragraph,
  // removed: linearScale, grid
}

class Choice {
  final String id;
  final String text;
  final double? points; // optional per-choice points

  Choice({required this.id, required this.text, this.points});

  factory Choice.fromMap(Map<String, dynamic> m) {
    return Choice(
      id: m['id'] as String? ?? '',
      text: m['text'] as String? ?? '',
      points: (m['points'] as num?)?.toDouble(),
    );
  }

  Choice copyWith({String? id, String? text, double? points}) {
    return Choice(
      id: id ?? this.id,
      text: text ?? this.text,
      points: points ?? this.points,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        if (points != null) 'points': points,
      };
}

class QuestionModel {
  final String id;
  final QuestionType type;
  final String prompt;
  final int order;
  final List<Choice> choices; // for choice-like questions
  final List<String> correctAnswers; // ids or text values depending on type
  final int points;
  final Map<String, dynamic>? metadata; // optional metadata for question types
  final bool required;
  final DateTime createdAt;
  final DateTime? updatedAt;

  QuestionModel({
    required this.id,
    required this.type,
    required this.prompt,
    this.order = 0,
    this.choices = const [],
    this.correctAnswers = const [],
    this.points = 1,
    this.metadata,
    this.required = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory QuestionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuestionModel(
      id: doc.id,
      type: _typeFromString(data['type'] as String? ?? 'shortAnswer'),
      prompt: data['prompt'] ?? '',
      order: (data['order'] as int?) ?? 0,
      choices: (data['choices'] as List<dynamic>?)
              ?.map((e) => Choice.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      correctAnswers:
          (data['correctAnswers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      points: (data['points'] as num?)?.toInt() ?? 1,
      metadata: data['metadata'] != null ? Map<String, dynamic>.from(data['metadata']) : null,
      required: data['required'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': _typeToString(type),
      'prompt': prompt,
      'order': order,
      'choices': choices.map((c) => c.toMap()).toList(),
      'correctAnswers': correctAnswers,
      'points': points,
      'metadata': metadata ?? {},
      'required': required,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  QuestionModel copyWith({
    String? id,
    QuestionType? type,
    String? prompt,
    int? order,
    List<Choice>? choices,
    List<String>? correctAnswers,
    int? points,
    Map<String, dynamic>? metadata,
    bool? required,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      prompt: prompt ?? this.prompt,
      order: order ?? this.order,
      choices: choices ?? this.choices,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      points: points ?? this.points,
      metadata: metadata ?? this.metadata,
      required: required ?? this.required,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
 
String _typeToString(QuestionType t) {
  switch (t) {
    case QuestionType.multipleChoice:
      return 'multipleChoice';
    case QuestionType.checkbox:
      return 'checkbox';
    case QuestionType.dropdown:
      return 'dropdown';
    case QuestionType.shortAnswer:
      return 'shortAnswer';
    case QuestionType.paragraph:
      return 'paragraph';
    // removed types handled by default
  }
}

QuestionType _typeFromString(String s) {
  switch (s) {
    case 'multipleChoice':
      return QuestionType.multipleChoice;
    case 'checkbox':
      return QuestionType.checkbox;
    case 'dropdown':
      return QuestionType.dropdown;
    case 'shortAnswer':
      return QuestionType.shortAnswer;
    case 'paragraph':
      return QuestionType.paragraph;
    // removed types fall through to default
    default:
      return QuestionType.shortAnswer;
  }
}

String questionTypeDisplayName(QuestionType t) {
  switch (t) {
    case QuestionType.multipleChoice:
      return 'Multiple Choice';
    case QuestionType.checkbox:
      return 'Checkboxes';
    case QuestionType.dropdown:
      return 'Dropdown';
    case QuestionType.shortAnswer:
      return 'Short Answer';
    case QuestionType.paragraph:
      return 'Paragraph';
    // removed types
  }
}

String questionTypeDescription(QuestionType t) {
  switch (t) {
    case QuestionType.multipleChoice:
      return 'Single best answer from a list of choices.';
    case QuestionType.checkbox:
      return 'Select one or more correct choices.';
    case QuestionType.dropdown:
      return 'Select a single option from a dropdown.';
    case QuestionType.shortAnswer:
      return 'Short free-text response (one line).';
    case QuestionType.paragraph:
      return 'Long-form free-text response.';
    // removed types
  }
}
 
