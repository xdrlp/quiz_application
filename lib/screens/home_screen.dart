import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:quiz_application/providers/auth_provider.dart';
import 'package:quiz_application/providers/quiz_provider.dart';
import 'package:quiz_application/models/quiz_model.dart';
// user_model import removed — roles simplified
import 'package:quiz_application/screens/take_quiz_dialog.dart';

class _GradientPainter extends CustomPainter {
  final double radius;
  final double strokeWidth;
  final Gradient gradient;

  _GradientPainter({
    required this.gradient,
    required this.radius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final RRect rRect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = gradient.createShader(rect);
    canvas.drawRRect(rRect, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

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
          colors: [
            Color(0xFFFFFFFF),
            Color.fromARGB(255, 197, 197, 197),
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
                colors: [
                  Color.fromARGB(255, 179, 179, 179),
                  Color.fromARGB(255, 255, 255, 255),
                ],
              ),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              color: const Color.fromARGB(255, 240, 240, 240),
              child: AppBar(
                systemOverlayStyle: SystemUiOverlayStyle.dark,
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.person, color: Colors.black, size: 28),
                  onPressed: () {
                    Navigator.of(context).pushNamed('/profile');
                  },
                ),
                title: const Text(
                  'Quiz Application',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.settings,
                      color: Colors.black,
                      size: 28,
                    ),
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
            // Load user quizzes and attempts once
            if (!_loaded && authProvider.currentUser != null) {
              _loaded = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final uid = authProvider.currentUser!.uid;
                quizProvider.loadUserQuizzes(uid);
                quizProvider.loadUserAttempts(uid);
              });
            }

            final userName = authProvider.currentUser?.displayName ?? 'there';
            
            // Stats for Quiz Board
            final quizzes = quizProvider.userQuizzes;
            final createdCount = quizzes.length;
            final publishedCount = quizzes.where((q) => q.published).length;
            final draftsCount = quizzes.where((q) => !q.published).length;
            
            // Stats for Quiz Taken
            final attempts = quizProvider.userAttempts;
            final submittedCount = attempts.where((a) => a.submittedAt != null).length;
            double avgScore = 0;
            if (submittedCount > 0) {
              final totalPerc = attempts
                  .where((a) => a.submittedAt != null)
                  .fold(0.0, (sum, a) => sum + a.scorePercentage);
               avgScore = totalPerc / submittedCount;
            }

            final recent = List<QuizModel>.from(quizzes)
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return LayoutBuilder(
              builder: (context, constraints) {
                final double screenWidth = constraints.maxWidth;
                // Use 4 columns on large screens, 2 on smaller to prevent wide stretched tiles
                final int crossAxisCount = screenWidth > 900 ? 4 : 2;

                // Calculate childAspectRatio dynamically to maintain a reasonable card height (~180px)
                // regardless of screen width.
                // Horizontal padding: 16 + 16 = 32
                // Spacing: 12 * (crossAxisCount - 1)
                final double totalHorizontalPadding =
                    32.0 + (12.0 * (crossAxisCount - 1));
                final double cardWidth =
                    (screenWidth - totalHorizontalPadding) / crossAxisCount;
                // Original design was ~0.85 on mobile (approx 160px width / 190px height)
                // We aim for height around 170-180px to accommodate content without excessive emptiness
                final double desiredHeight = 190.0;
                final double dynamicAspectRatio = cardWidth / desiredHeight;

                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $userName',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 46, 46, 46),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'What would you like to do today?',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color.fromARGB(255, 136, 136, 136),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Action tiles arranged in a responsive grid
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: dynamicAspectRatio,
                          children: [
                            // Create Quiz (top-left)
                            _neumorphicCard(
                              onTap: () => Navigator.of(
                                context,
                              ).pushNamed('/create_quiz'),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.add_circle,
                                    size: 72,
                                    color: Colors.black,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Create Quiz',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Design your own Quiz',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color.fromARGB(255, 71, 71, 71),
                                    ),
                                  ),
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
                                  const Icon(
                                    Icons.gps_fixed,
                                    size: 72,
                                    color: Colors.black,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Take Quiz',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Enter quiz code to take quiz',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color.fromARGB(255, 71, 71, 71),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Quiz board
                            _neumorphicCard(
                              onTap: () => Navigator.of(
                                context,
                              ).pushNamed('/my_quizzes'),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.menu_book,
                                    size: 72,
                                    color: Colors.black,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Quiz board',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$publishedCount Published\n$draftsCount drafts',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color.fromARGB(255, 71, 71, 71),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Quiz History
                            _neumorphicCard(
                              onTap: () => Navigator.of(
                                context,
                              ).pushNamed('/quiz_history'),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.history,
                                    size: 72,
                                    color: Colors.black,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Quiz Taken',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$submittedCount Submitted\n${avgScore.toStringAsFixed(0)}% avg score',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color.fromARGB(255, 71, 71, 71),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        const Text(
                          'recent activity',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color.fromARGB(255, 119, 119, 119),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (quizProvider.isLoading)
                          Column(
                            children: List.generate(3, (index) {
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                child: CustomPaint(
                                  painter: _GradientPainter(
                                    strokeWidth: 2,
                                    radius: 14,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.black, Colors.white],
                                    ),
                                  ),
                                  child: Container(
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                  width: 140,
                                                  height: 14,
                                                  color: Colors.grey.withValues(alpha: 0.3),
                                                ),
                                                const SizedBox(height: 6),
                                                Container(
                                                  width: 80,
                                                  height: 10,
                                                  color: Colors.grey.withValues(alpha: 0.2),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            width: 70,
                                            height: 10,
                                            color: Colors.grey.withValues(alpha: 0.2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          )
                        else if (recent.isEmpty)
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            child: CustomPaint(
                              painter: _GradientPainter(
                                strokeWidth: 2,
                                radius: 14,
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.black, Colors.white],
                                ),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'No recent activity',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color.fromARGB(255, 139, 139, 139),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Column(
                            children: List.generate(
                              math.min(5, recent.length),
                              (i) {
                                final q = recent[i];
                                final ago = _relativeTime(q.createdAt);
                                return Container(
                                  key: ValueKey(q.id),
                                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                  child: CustomPaint(
                                    painter: _GradientPainter(
                                      strokeWidth: 2,
                                      radius: 14,
                                      gradient: const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [Colors.black, Colors.white],
                                      ),
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(12),
                                          onTap: () {
                                            Navigator.of(context).pushNamed('/edit_quiz', arguments: q.id);
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Text(q.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF222222))),
                                                      const SizedBox(height: 4),
                                                      Text(ago, style: const TextStyle(fontSize: 11, color: Color.fromARGB(255, 139, 139, 139))),
                                                    ],
                                                  ),
                                                ),
                                                Text(q.published ? 'Published' : 'Draft', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color.fromARGB(255, 59, 59, 59))),
                                                const SizedBox(width: 8),
                                                const Icon(Icons.chevron_right, color: Color.fromARGB(255, 141, 141, 141), size: 20),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
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
            colors: [
              Color.fromARGB(255, 248, 248, 248),
              Color.fromARGB(255, 121, 121, 121),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color.fromARGB(255, 201, 201, 201), Color.fromARGB(255, 233, 233, 233)],
            ),
            borderRadius: BorderRadius.circular(17),
          ),
          child: child,
        ),
      ),
    );
  }
}
