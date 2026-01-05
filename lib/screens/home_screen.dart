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
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.person),
          onPressed: () {
            Navigator.of(context).pushNamed('/profile');
          },
        ),
        title: Text('Quiz Application', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).pushNamed('/profile');
            },
          ),
        ],
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
                  Text('Hello, $userName', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('What would you like to do today?', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                  const SizedBox(height: 16),
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
                      Card(
                        color: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
                          onTap: () => Navigator.of(context).pushNamed('/create_quiz'),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                CircleAvatar(radius: 22, backgroundColor: Colors.black26, child: const Icon(Icons.add, size: 28, color: Colors.white)),
                                const SizedBox(height: 12),
                                Text('Create Quiz', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                              ]),
                              const SizedBox(height: 12),
                              Flexible(child: Text('Design your own quiz', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFFBEC5D1)))),
                            ]),
                          ),
                        ),
                      ),
                      // My Quizzes
                      Card(
                        color: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
                          onTap: () => Navigator.of(context).pushNamed('/my_quizzes'),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                CircleAvatar(radius: 22, backgroundColor: Colors.black26, child: const Icon(Icons.menu_book_outlined, size: 26, color: Colors.white)),
                                const SizedBox(height: 12),
                                Text('Quiz board', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                              ]),
                              const SizedBox(height: 12),
                              Flexible(child: Text('${quizzes.length} created', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFFBEC5D1)))),
                            ]),
                          ),
                        ),
                      ),
                      // Take Quiz
                      Card(
                        color: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
                          onTap: () => showTakeQuizDialog(context),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                CircleAvatar(radius: 22, backgroundColor: Colors.black26, child: const Icon(Icons.gps_fixed, size: 26, color: Colors.white)),
                                const SizedBox(height: 12),
                                Text('Take Quiz', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                              ]),
                              const SizedBox(height: 12),
                              Flexible(child: Text('Enter quiz code', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFFBEC5D1)))),
                            ]),
                          ),
                        ),
                      ),
                      // Quiz History
                      Card(
                        color: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
                          onTap: () => Navigator.of(context).pushNamed('/quiz_history'),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                CircleAvatar(radius: 22, backgroundColor: Colors.black26, child: const Icon(Icons.history, size: 26, color: Colors.white)),
                                const SizedBox(height: 12),
                                Text('Quiz Taken', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                              ]),
                              const SizedBox(height: 12),
                              Flexible(child: Text('45 Completed 89% avg score', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFFBEC5D1)))),
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Text('recent activity', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: const Color(0xFF787B82), fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (recent.isEmpty)
                    Card(child: Padding(padding: const EdgeInsets.all(12.0), child: Text('No recent activity', style: Theme.of(context).textTheme.bodyMedium)))
                  else
                    Column(
                      children: List.generate(math.min(5, recent.length), (i) {
                        final q = recent[i];
                        final ago = _relativeTime(q.createdAt);
                        return Card(
                          color: Theme.of(context).colorScheme.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            title: Text(q.title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70)),
                            subtitle: Text(ago, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54)),
                            trailing: Text('View Details', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                            onTap: () => Navigator.of(context).pushNamed('/edit_quiz', arguments: q.id),
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
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 48) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }
}
