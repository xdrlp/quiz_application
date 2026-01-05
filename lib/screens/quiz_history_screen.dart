import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quiz_application/services/firestore_service.dart';
import 'package:quiz_application/providers/auth_provider.dart';
import 'package:quiz_application/models/attempt_model.dart';
import 'package:quiz_application/models/quiz_model.dart';

class QuizHistoryScreen extends StatefulWidget {
  const QuizHistoryScreen({super.key});

  @override
  State<QuizHistoryScreen> createState() => _QuizHistoryScreenState();
}

class _QuizHistoryScreenState extends State<QuizHistoryScreen> {
  final FirestoreService _fs = FirestoreService();
  bool _loading = true;
  List<AttemptModel> _attempts = [];
  final Map<String, QuizModel?> _quizCache = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final attempts = await _fs.getAttemptsByUser(user.uid);
      _attempts = attempts;
      // prefetch quiz titles
      for (var a in attempts) {
        if (!_quizCache.containsKey(a.quizId)) {
          _quizCache[a.quizId] = await _fs.getQuiz(a.quizId);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _attempts.isEmpty
              ? Center(child: Text('No quiz attempts yet', style: Theme.of(context).textTheme.bodyMedium))
              : ListView.separated(
                  itemCount: _attempts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final a = _attempts[index];
                    final q = _quizCache[a.quizId];
                    final title = q?.title ?? 'Quiz';
                    final when = a.submittedAt ?? a.startedAt;
                    final ago = _relativeTime(when);
                    return Card(
                      child: ListTile(
                        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
                        subtitle: Text('$ago • ${a.score}/${a.totalPoints}'),
                        onTap: () {
                          Navigator.of(context).pushNamed('/attempt_review', arguments: a.id);
                        },
                      ),
                    );
                  },
                ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 48) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }
}
