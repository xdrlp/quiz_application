import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:quiz_application/providers/auth_provider.dart';
import 'package:quiz_application/providers/quiz_provider.dart';
import 'package:quiz_application/models/quiz_model.dart';
// user_model import removed — roles simplified
import 'package:quiz_application/screens/take_quiz_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loaded = false;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.fromARGB(255, 255, 255, 255), Color.fromARGB(217, 255, 255, 255)],
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
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.person, color: Colors.black, size: 28),
                  onPressed: () {
                    Navigator.of(context).pushNamed('/profile');
                  },
                ),
                title: const Text('Quiz Application', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.black, size: 28),
                    onPressed: () {
                      Navigator.of(context).pushNamed('/profile');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Consumer2<AuthProvider, QuizProvider>(
        builder: (context, authProvider, quizProvider, _) {
          // Load user quizzes once
          if (!_loaded && authProvider.currentUser != null) {
            _loaded = true;
            quizProvider.loadUserQuizzes(authProvider.currentUser!.uid);
          }

          final userName = authProvider.currentUser?.displayName ?? 'there';
          final quizzes = quizProvider.userQuizzes;
          final recent = List<QuizModel>.from(quizzes)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello, $userName', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                  const SizedBox(height: 8),
                  Text('What would you like to do today?', style: const TextStyle(fontSize: 16, color: Color(0xFF7F8C8D))),
                  const SizedBox(height: 24),
                  // Action tiles arranged in a 2x2 grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.0,
                    children: [
                      // Create Quiz (top-left)
                      _neumorphicCard(
                        onTap: () => Navigator.of(context).pushNamed('/create_quiz'),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.add_circle, size: 48, color: Colors.black),
                            const SizedBox(height: 12),
                            const Text('Create Quiz', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                            const SizedBox(height: 4),
                            const Text('Design your own Quiz', style: TextStyle(fontSize: 12, color: Color(0xFF7F8C8D))),
                          ],
                        ),
                      ),
                      // Take Quiz
                      _neumorphicCard(
                        onTap: () => showTakeQuizDialog(context),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.gps_fixed, size: 48, color: Colors.black),
                            const SizedBox(height: 12),
                            const Text('Take Quiz', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                            const SizedBox(height: 4),
                            const Text('Enter quiz code to take quiz', style: TextStyle(fontSize: 12, color: Color(0xFF7F8C8D))),
                          ],
                        ),
                      ),
                      // Quiz board
                      _neumorphicCard(
                        onTap: () => Navigator.of(context).pushNamed('/my_quizzes'),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.menu_book, size: 48, color: Colors.black),
                            const SizedBox(height: 12),
                            const Text('Quiz board', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                            const SizedBox(height: 4),
                            Text('25 Created 5 Published\n2 drafts', style: const TextStyle(fontSize: 12, color: Color(0xFF7F8C8D), height: 1.3)),
                          ],
                        ),
                      ),
                      // Quiz History
                      _neumorphicCard(
                        onTap: () => Navigator.of(context).pushNamed('/quiz_history'),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.history, size: 48, color: Colors.black),
                            const SizedBox(height: 12),
                            const Text('Quiz Taken', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                            const SizedBox(height: 4),
                            const Text('45 Submitted 89% avg score', style: TextStyle(fontSize: 12, color: Color(0xFF7F8C8D))),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Text('recent activity', style: TextStyle(fontSize: 14, color: Color(0xFF7F8C8D), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  if (recent.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.white, offset: const Offset(-6, -6), blurRadius: 12),
                          BoxShadow(color: const Color(0xFFB0B8C1).withValues(alpha: 0.6), offset: const Offset(6, 6), blurRadius: 12),
                        ],
                      ),
                      child: const Text('No recent activity', style: TextStyle(color: Color(0xFF7F8C8D))),
                    )
                  else
                    Column(
                      children: List.generate(math.min(5, recent.length), (i) {
                        final q = recent[i];
                        final ago = _relativeTime(q.createdAt);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 110, 110, 110),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(q.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color.fromARGB(255, 224, 224, 224))),
                                  const SizedBox(height: 4),
                                  Text(ago, style: const TextStyle(fontSize: 13, color: Color.fromARGB(255, 192, 192, 192))),
                                ],
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pushNamed('/edit_quiz', arguments: q.id),
                                child: const Text('View Details', style: TextStyle(color: Color.fromARGB(255, 203, 203, 203), fontSize: 13)),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                ],
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

  Widget _neumorphicCard({required VoidCallback onTap, required Widget child}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.fromARGB(255, 255, 255, 255), Color.fromARGB(255, 0, 0, 0)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFFA6A6A6), Color(0xFFFFFFFF)],
            ),
            borderRadius: BorderRadius.circular(17),
          ),
          child: child,
        ),
      ),
    );
  }
}
