import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:quiz_application/providers/auth_provider.dart';
import 'package:quiz_application/services/firestore_service.dart';
import 'package:flutter/scheduler.dart';
import 'package:quiz_application/models/quiz_model.dart';
import 'package:quiz_application/screens/attempts_review_screen.dart';

// ignore_for_file: use_super_parameters

class MyQuizzesScreen extends StatefulWidget {
  const MyQuizzesScreen({super.key});

  @override
  State<MyQuizzesScreen> createState() => _MyQuizzesScreenState();
}

class _SnackBarTimer extends StatefulWidget {
  final DateTime startTime;
  final Duration duration;
  const _SnackBarTimer({Key? key, required this.startTime, required this.duration}) : super(key: key);

  @override
  State<_SnackBarTimer> createState() => _SnackBarTimerState();
}

class _SnackBarTimerState extends State<_SnackBarTimer> {
  late final Ticker _ticker;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _updateProgress();
    _ticker = Ticker(_onTick)..start();
  }

  void _onTick(Duration _) => _updateProgress();

  void _updateProgress() {
    final elapsed = DateTime.now().difference(widget.startTime);
    final p = elapsed.inMilliseconds / widget.duration.inMilliseconds;
    final newProgress = p.clamp(0.0, 1.0);
    if (mounted) setState(() => _progress = newProgress);
    if (newProgress >= 1.0) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4,
      child: LinearProgressIndicator(
        value: _progress,
        backgroundColor: Theme.of(context).colorScheme.onSurface.withAlpha((0.06 * 255).round()),
        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _MyQuizzesScreenState extends State<MyQuizzesScreen> {
  late Future<List<QuizModel>> _future;
  final Map<String, DateTime> _lastCopyTime = {};

  void _load() {
    final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
    _future = FirestoreService().getQuizzesByTeacher(uid);
  }

  Future<void> _copyWithCooldown(String key, String text, String message) async {
    final now = DateTime.now();
    final last = _lastCopyTime[key];
    if (last != null && now.difference(last) < const Duration(milliseconds: 800)) return;
    _lastCopyTime[key] = now;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 1), content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Quizzes')),
      body: FutureBuilder<List<QuizModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final err = snap.error.toString();
            // Try to extract an index creation URL from the error message
            final urlRegex = RegExp(r'https?://[^\s)]+');
            final match = urlRegex.firstMatch(err);
            if (match != null) {
              final url = match.group(0)!;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Firestore query requires a composite index.'),
                      const SizedBox(height: 8),
                      const Text('Create the index using the link below, then refresh this screen.'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: SelectableText(url)),
                          IconButton(
                            tooltip: 'Copy index URL',
                            icon: const Icon(Icons.copy),
                            onPressed: () async {
                              await _copyWithCooldown(url, url, 'Index URL copied');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }
            return Center(child: Text('Error: $err'));
          }
          final quizzes = snap.data ?? [];
          final drafts = quizzes.where((q) => q.published == false).toList();
          final published = quizzes.where((q) => q.published == true).toList();
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      const Text('Drafts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (drafts.isEmpty) const Text('No drafts yet'),
                      for (var q in drafts)
                        Card(
                          child: ListTile(
                            title: Text(q.title),
                            subtitle: Text(q.description),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => Navigator.of(context).pushNamed('/edit_quiz', arguments: q.id),
                                ),
                                IconButton(
                                  tooltip: 'Copy code',
                                  icon: const Icon(Icons.copy),
                                  onPressed: () async {
                                    await _copyWithCooldown(q.id, q.quizCode ?? '', 'Quiz code copied');
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.publish),
                                  onPressed: () async {
                                    await FirestoreService().publishQuiz(q.id, true);
                                    setState(() => _load());
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Delete quiz',
                                  icon: const Icon(Icons.delete_forever),
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Delete Quiz'),
                                        content: const Text('Delete this draft quiz? You can undo this action from the snackbar immediately after.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                                          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      String? backupId;
                                      try {
                                        backupId = await FirestoreService().backupQuiz(q.id);
                                        await FirestoreService().deleteQuiz(q.id);
                                        setState(() => _load());
                                        if (!mounted) return;
                                        messenger.removeCurrentSnackBar();
                                        messenger.showSnackBar(
                                          SnackBar(
                                            duration: const Duration(seconds: 5),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Expanded(child: Text('Quiz deleted')),
                                                    TextButton(
                                                      onPressed: () async {
                                                        messenger.removeCurrentSnackBar();
                                                        if (backupId != null) {
                                                          try {
                                                            await FirestoreService().restoreQuizFromBackup(backupId);
                                                            if (!mounted) return;
                                                            setState(() => _load());
                                                            messenger.showSnackBar(const SnackBar(
                                                              duration: Duration(seconds: 2),
                                                              content: Text('Quiz restored'),
                                                            ));
                                                          } catch (e) {
                                                            if (!mounted) return;
                                                            messenger.showSnackBar(SnackBar(content: Text('Failed to restore: $e')));
                                                          }
                                                        }
                                                      },
                                                      child: const Text('Undo'),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                _SnackBarTimer(startTime: DateTime.now(), duration: const Duration(seconds: 5)),
                                              ],
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        messenger.removeCurrentSnackBar();
                                        messenger.showSnackBar(SnackBar(
                                          duration: const Duration(seconds: 5),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('Failed to delete: $e'),
                                              const SizedBox(height: 6),
                                              _SnackBarTimer(startTime: DateTime.now(), duration: const Duration(seconds: 5)),
                                            ],
                                          ),
                                        ));
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      const Text('Published', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (published.isEmpty) const Text('No published quizzes'),
                      for (var q in published)
                        Card(
                          child: ListTile(
                            title: Text(q.title),
                            subtitle: Text('Code: ${q.quizCode ?? '—'}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility),
                                  tooltip: 'View',
                                  onPressed: () {
                                    showModalBottomSheet<void>(
                                      context: context,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                                      builder: (ctx) {
                                        return SafeArea(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ListTile(
                                                leading: const Icon(Icons.insert_chart_outlined),
                                                title: const Text('Summary'),
                                                onTap: () {
                                                  Navigator.of(ctx).pop();
                                                  showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Summary'), content: Text('Summary for ${q.title}')));
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.insights_outlined),
                                                title: const Text('Insights'),
                                                onTap: () {
                                                  Navigator.of(ctx).pop();
                                                  showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Insights'), content: Text('Insights for ${q.title}')));
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.person_outline),
                                                title: const Text('Individual'),
                                                onTap: () async {
                                                  Navigator.of(ctx).pop();
                                                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AttemptsReviewScreen(quizId: q.id)));
                                                  setState(() => _load());
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Copy code',
                                  icon: const Icon(Icons.copy),
                                  onPressed: () async {
                                    await _copyWithCooldown(q.id, q.quizCode ?? '', 'Quiz code copied');
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.unpublished),
                                  onPressed: () async {
                                    await FirestoreService().publishQuiz(q.id, false);
                                    setState(() => _load());
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Delete quiz',
                                  icon: const Icon(Icons.delete_forever),
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Delete Quiz'),
                                        content: const Text('Delete this published quiz? This will also remove attempts and violations. You can undo this from the snackbar immediately after.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                                          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      String? backupId;
                                      try {
                                        backupId = await FirestoreService().backupQuiz(q.id);
                                        await FirestoreService().deleteQuiz(q.id);
                                        setState(() => _load());
                                        if (!mounted) return;
                                        messenger.removeCurrentSnackBar();
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: const Text('Quiz deleted'),
                                            action: SnackBarAction(
                                              label: 'Undo',
                                              onPressed: () async {
                                                messenger.removeCurrentSnackBar();
                                                if (backupId != null) {
                                                  try {
                                                    await FirestoreService().restoreQuizFromBackup(backupId);
                                                    if (!mounted) return;
                                                    setState(() => _load());
                                                    messenger.showSnackBar(const SnackBar(duration: Duration(seconds:2), content: Text('Quiz restored')));
                                                  } catch (e) {
                                                    if (!mounted) return;
                                                    messenger.showSnackBar(SnackBar(content: Text('Failed to restore: $e')));
                                                  }
                                                }
                                              },
                                            ),
                                            duration: const Duration(seconds: 5),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        messenger.removeCurrentSnackBar();
                                        messenger.showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
