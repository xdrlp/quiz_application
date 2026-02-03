import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color.fromARGB(255, 207, 207, 207),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color.fromARGB(255, 169, 169, 169), Color.fromARGB(255, 255, 255, 255)],
              ),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color.fromARGB(108, 244, 244, 244), Color.fromARGB(205, 223, 223, 223)],
                ),
              ),
              child: AppBar(
                systemOverlayStyle: SystemUiOverlayStyle.dark,
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: const Text('Quiz History', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
              ),
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _attempts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No quiz attempts yet', 
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade500)
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _attempts.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemBuilder: (context, index) {
                      final a = _attempts[index];
                      final q = _quizCache[a.quizId];
                      final title = q?.title ?? 'Unknown Quiz';
                      final when = a.submittedAt ?? a.startedAt;
                      final ago = _relativeTime(when);
                      
                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            const BoxShadow(
                              color: Colors.white,
                              offset: Offset(-4, -4),
                              blurRadius: 10,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              offset: const Offset(4, 4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.of(context).pushNamed('/attempt_review', arguments: a.id);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0E0E0),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        const BoxShadow(
                                          color: Colors.white,
                                          offset: Offset(-2, -2),
                                          blurRadius: 5,
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          offset: const Offset(2, 2),
                                          blurRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.assignment_turned_in, color: Color.fromARGB(255, 70, 70, 70)),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF222222))),
                                        const SizedBox(height: 4),
                                        Text(ago, style: const TextStyle(fontSize: 12, color: Color.fromARGB(255, 139, 139, 139))),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${(a.score / (a.totalPoints > 0 ? a.totalPoints : 1) * 100).toStringAsFixed(0)}%',
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 59, 59, 59)),
                                      ),
                                      Text('${a.score}/${a.totalPoints}', style: const TextStyle(fontSize: 12, color: Color(0xFF7F8C8D))),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right, color: Color.fromARGB(255, 141, 141, 141)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
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
