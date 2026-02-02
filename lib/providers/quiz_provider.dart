import 'package:flutter/material.dart';
import 'package:quiz_application/models/quiz_model.dart';
import 'package:quiz_application/models/question_model.dart';
import 'package:quiz_application/models/attempt_model.dart';
import 'package:quiz_application/services/firestore_service.dart';

class QuizProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<QuizModel> _userQuizzes = [];
  List<AttemptModel> _userAttempts = []; // Add this
  QuizModel? _currentQuiz;
  List<QuestionModel> _currentQuizQuestions = [];
  AttemptModel? _currentAttempt;
  bool _isLoading = false;
  String? _errorMessage;

  List<QuizModel> get userQuizzes => _userQuizzes;
  List<AttemptModel> get userAttempts => _userAttempts; // Add this
  QuizModel? get currentQuiz => _currentQuiz;
  List<QuestionModel> get currentQuizQuestions => _currentQuizQuestions;
  AttemptModel? get currentAttempt => _currentAttempt;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> loadUserQuizzes(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _userQuizzes = await _firestoreService.getQuizzesByTeacher(userId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loadUserAttempts(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _userAttempts = await _firestoreService.getAttemptsByUser(userId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loadQuizById(String quizId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentQuiz = await _firestoreService.getQuiz(quizId);
      if (_currentQuiz != null) {
        _currentQuizQuestions =
            await _firestoreService.getQuizQuestions(quizId);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loadQuizByCode(String quizCode) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentQuiz = await _firestoreService.getQuizByCode(quizCode);
      if (_currentQuiz != null) {
        _currentQuizQuestions =
            await _firestoreService.getQuizQuestions(_currentQuiz!.id);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<String?> createQuiz(QuizModel quiz) async {
    try {
      final quizId = await _firestoreService.createQuiz(quiz);
      _userQuizzes.add(quiz.copyWith(id: quizId));
      notifyListeners();
      return quizId;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateCurrentQuiz(Map<String, dynamic> data) async {
    try {
      if (_currentQuiz != null) {
        await _firestoreService.updateQuiz(_currentQuiz!.id, data);
        _currentQuiz = _currentQuiz!.copyWith();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> publishQuiz(String quizId, bool published) async {
    try {
      await _firestoreService.publishQuiz(quizId, published);
      if (_currentQuiz != null && _currentQuiz!.id == quizId) {
        _currentQuiz = _currentQuiz!.copyWith(published: published);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> addQuestionToQuiz(QuestionModel question) async {
    try {
      if (_currentQuiz != null) {
        final questionId =
            await _firestoreService.addQuestion(_currentQuiz!.id, question);
        _currentQuizQuestions.add(question.copyWith(id: questionId));
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<String?> createAttempt(AttemptModel attempt) async {
    try {
      final attemptId = await _firestoreService.createAttempt(attempt);
      _currentAttempt = attempt.copyWith(id: attemptId);
      notifyListeners();
      return attemptId;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> submitAttempt(AttemptModel attempt) async {
    try {
      if (_currentAttempt != null) {
        await _firestoreService.submitAttempt(_currentAttempt!.id, attempt);
        _currentAttempt = attempt;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearCurrentQuiz() {
    _currentQuiz = null;
    _currentQuizQuestions = [];
    _currentAttempt = null;
    notifyListeners();
  }
}
