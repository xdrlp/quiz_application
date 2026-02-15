import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quiz_application/models/user_model.dart';
import 'package:quiz_application/models/quiz_model.dart';
import 'package:quiz_application/models/question_model.dart';
import 'package:quiz_application/models/attempt_model.dart';
import 'package:quiz_application/models/violation_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String usersCollection = 'users';
  static const String quizzesCollection = 'quizzes';
  static const String questionsCollection = 'questions';
  static const String attemptsCollection = 'attempts';
  static const String violationsCollection = 'violations';
  static const String classesCollection = 'classes';

  // ====== USER OPERATIONS ======
  Future<void> createUser(String uid, UserModel user) async {
    try {
      final data = user.toFirestore();
      // Ensure a role is set so it satisfies stricter security rules.
      data.putIfAbsent('role', () => 1);
      await _firestore.collection(usersCollection).doc(uid).set(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection(usersCollection).doc(uid).get();
      return doc.exists ? UserModel.fromFirestore(doc) : null;
    } on FirebaseException catch (e) {
      print('Firestore.getUser error: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Returns true if a user document exists with the given email.
  Future<bool> emailExists(String email) async {
    try {
      final query = await _firestore
          .collection(usersCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(usersCollection).doc(uid).update(data);
    } catch (e) {
      rethrow;
    }
  }

  // ====== QUIZ OPERATIONS ======
  Future<String> createQuiz(QuizModel quiz) async {
    try {
      final docRef = await _firestore
          .collection(quizzesCollection)
          .add(quiz.copyWith(id: '').toFirestore());
      // Update quiz with its generated ID
      await docRef.update({'id': docRef.id});
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<QuizModel?> getQuiz(String quizId) async {
    try {
      final doc =
          await _firestore.collection(quizzesCollection).doc(quizId).get();
      return doc.exists ? QuizModel.fromFirestore(doc) : null;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<QuizModel>> getQuizzesByTeacher(String teacherId) async {
    try {
      final querySnapshot = await _firestore
          .collection(quizzesCollection)
          .where('createdBy', isEqualTo: teacherId)
          .orderBy('createdAt', descending: true)
          .get();
      return querySnapshot.docs.map((doc) => QuizModel.fromFirestore(doc)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<QuizModel?> getQuizByCode(String quizCode, {String? password}) async {
    try {
      var query = _firestore.collection(quizzesCollection).where('quizCode', isEqualTo: quizCode);
      if (password != null && password.isNotEmpty) {
        query = query.where('password', isEqualTo: password);
      }
      final querySnapshot = await query.limit(1).get();
      return querySnapshot.docs.isNotEmpty
          ? QuizModel.fromFirestore(querySnapshot.docs.first)
          : null;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<QuizModel>> getAvailableQuizzes(List<String> classIds) async {
    try {
      final querySnapshot = await _firestore
          .collection(quizzesCollection)
          .where('published', isEqualTo: true)
          .where('classIds', arrayContainsAny: classIds)
          .orderBy('createdAt', descending: true)
          .get();
      return querySnapshot.docs.map((doc) => QuizModel.fromFirestore(doc)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateQuiz(String quizId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection(quizzesCollection)
          .doc(quizId)
          .update(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> publishQuiz(String quizId, bool published) async {
    try {
      await _firestore
          .collection(quizzesCollection)
          .doc(quizId)
          .update({'published': published});
    } catch (e) {
      rethrow;
    }
  }

  // ====== QUESTION OPERATIONS ======
  Future<String> addQuestion(String quizId, QuestionModel question) async {
    try {
      final docRef = await _firestore
          .collection(quizzesCollection)
          .doc(quizId)
          .collection(questionsCollection)
          .add(question.toFirestore());
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<QuestionModel>> getQuizQuestions(String quizId) async {
    try {
      final querySnapshot = await _firestore
          .collection(quizzesCollection)
          .doc(quizId)
          .collection(questionsCollection)
          .orderBy('order', descending: false)
          .get();
      return querySnapshot.docs
          .map((doc) => QuestionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateQuestion(String quizId, String questionId,
      Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection(quizzesCollection)
          .doc(quizId)
          .collection(questionsCollection)
          .doc(questionId)
          .update(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteQuestion(String quizId, String questionId) async {
    try {
      await _firestore
          .collection(quizzesCollection)
          .doc(quizId)
          .collection(questionsCollection)
          .doc(questionId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  // ====== ATTEMPT OPERATIONS ======
  Future<String> createAttempt(AttemptModel attempt) async {
    try {
      final data = attempt.copyWith(id: '').toFirestore();
      // Debugging: print attempt data and current auth UID to help troubleshoot
      try {
        // ignore: avoid_print
        print('[FirestoreService] createAttempt data: ' + data.toString());
        // ignore: avoid_print
        print('[FirestoreService] currentAuthUid: ' + (FirebaseAuth.instance.currentUser?.uid ?? 'null'));
      } catch (_) {}
      final docRef = await _firestore
          .collection(attemptsCollection)
          .add(data);
      
      // Increment the attempt count on the quiz document transactionally or simply with FieldValue.increment
      await _firestore.collection(quizzesCollection).doc(attempt.quizId).update({
        'totalAttempts': FieldValue.increment(1),
      });

      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<AttemptModel?> getAttempt(String attemptId) async {
    try {
      final doc =
          await _firestore.collection(attemptsCollection).doc(attemptId).get();
      return doc.exists ? AttemptModel.fromFirestore(doc) : null;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<AttemptModel>> getAttemptsByUser(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(attemptsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('startedAt', descending: true)
          .get();
      return querySnapshot.docs
          .map((doc) => AttemptModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<AttemptModel>> getAttemptsByQuiz(String quizId) async {
    try {
      final querySnapshot = await _firestore
          .collection(attemptsCollection)
          .where('quizId', isEqualTo: quizId)
          .orderBy('startedAt', descending: true)
          .get();
      return querySnapshot.docs
          .map((doc) => AttemptModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      // Firestore sometimes requires a composite index for queries that combine
      // `where` and `orderBy` on different fields. The backend returns a
      // helpful URL in the error message that the developer can use to create
      // the index. Capture that and throw a typed exception so UI can surface it.
      final msg = e.message ?? e.toString();
      if (msg.contains('requires an index') || msg.contains('create_composite')) {
        // Try to extract the index creation URL
        final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(msg);
        final url = urlMatch != null ? msg.substring(urlMatch.start, urlMatch.end) : msg;
        throw FirestoreIndexRequiredException(url);
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> submitAttempt(String attemptId, AttemptModel attempt) async {
    try {
      await _firestore
          .collection(attemptsCollection)
          .doc(attemptId)
          .update(attempt.toFirestore());
    } catch (e) {
      rethrow;
    }
  }

  /// Apply a partial update to an attempt document. Useful for adding
  /// transient metadata such as flagged question ids when a penalty occurs.
  Future<void> patchAttempt(String attemptId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(attemptsCollection).doc(attemptId).set(data, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  /// Delete an attempt and its associated violations.
  Future<void> deleteAttempt(String attemptId) async {
    try {
      // Delete violations for this attempt
      final violSnap = await _firestore
          .collection(violationsCollection)
          .where('attemptId', isEqualTo: attemptId)
          .get();
      for (var vDoc in violSnap.docs) {
        try {
          await vDoc.reference.delete();
        } catch (e) {
          // Log and continue so one failing violation delete doesn't
          // prevent removing the attempt itself. This helps diagnose
          // permission issues per-document.
          print('Violation delete failed for ${vDoc.id}: $e');
        }
      }
      // Delete the attempt itself
      try {
        await _firestore.collection(attemptsCollection).doc(attemptId).delete();
      } catch (e) {
        print('Attempt delete failed for $attemptId: $e');
        rethrow;
      }
    } catch (e) {
      rethrow;
    }
  }

  // ====== VIOLATION OPERATIONS ======
  Future<void> logViolation(ViolationModel violation) async {
    try {
      await _firestore
          .collection(violationsCollection)
          .add(violation.toFirestore());
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ViolationModel>> getViolationsByAttempt(String attemptId) async {
    try {
      final querySnapshot = await _firestore
          .collection(violationsCollection)
          .where('attemptId', isEqualTo: attemptId)
          .orderBy('detectedAt', descending: false)
          .get();
      return querySnapshot.docs
          .map<ViolationModel>((doc) => ViolationModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<int> getViolationCountByAttempt(String attemptId) async {
    try {
      final querySnapshot = await _firestore
          .collection(violationsCollection)
          .where('attemptId', isEqualTo: attemptId)
          .count()
          .get();
      return querySnapshot.count ?? 0;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a quiz and its related data (questions, attempts, and violations).
  /// This performs multiple queries and deletes documents found. Use with
  /// caution; it's intended for teacher-driven cleanup of drafts or quizzes.
  Future<void> deleteQuiz(String quizId) async {
    try {
      // Delete questions subcollection
      final questionsSnap = await _firestore
          .collection(quizzesCollection)
          .doc(quizId)
          .collection(questionsCollection)
          .get();
      for (var doc in questionsSnap.docs) {
        await doc.reference.delete();
      }

      // Delete attempts and their violations
      final attemptsSnap = await _firestore
          .collection(attemptsCollection)
          .where('quizId', isEqualTo: quizId)
          .get();
      for (var aDoc in attemptsSnap.docs) {
        final attemptId = aDoc.id;
        // delete violations for this attempt
        final violSnap = await _firestore
            .collection(violationsCollection)
            .where('attemptId', isEqualTo: attemptId)
            .get();
        for (var vDoc in violSnap.docs) {
          await vDoc.reference.delete();
        }
        // delete attempt
        await aDoc.reference.delete();
      }

      // Finally delete the quiz document itself
      await _firestore.collection(quizzesCollection).doc(quizId).delete();

      // NOTE: Skipping post-delete read verification because Firestore
      // security rules may deny reads for deleted documents and that can
      // surface confusing permission-denied errors in client logs.
      // If extra verification is required, perform it from a backend
      // privileged environment or check via a callable function.
    } catch (e) {
      rethrow;
    }
  }

}

/// Thrown when a Firestore query fails because a composite index is required.
class FirestoreIndexRequiredException implements Exception {
  final String url;
  FirestoreIndexRequiredException(this.url);
  @override
  String toString() => 'Firestore index required: $url';
}
