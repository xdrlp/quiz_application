import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:quiz_application/providers/auth_provider.dart';
import 'package:quiz_application/services/firestore_service.dart';
import 'package:flutter/scheduler.dart';
import 'package:quiz_application/models/quiz_model.dart';
import 'package:quiz_application/screens/quiz_analysis_screen.dart';

// ignore_for_file: use_super_parameters

class MyQuizzesScreen extends StatefulWidget {
  const MyQuizzesScreen({super.key});

  @override
  State<MyQuizzesScreen> createState() => _MyQuizzesScreenState();
}

class _SnackBarTimer extends StatefulWidget {
  final DateTime startTime;
  final Duration duration;
  final double height;
  const _SnackBarTimer({Key? key, required this.startTime, required this.duration, this.height = 4.0}) : super(key: key);

  @override
  State<_SnackBarTimer> createState() => _SnackBarTimerState();
}

class _SnackBarTimerState extends State<_SnackBarTimer> {
  late final Ticker _ticker;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick);
    _updateProgress();
    if (_progress < 1.0) {
      _ticker.start();
    }
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
      height: widget.height,
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
  String _searchQuery = '';
  String _sortBy = 'updated'; // 'updated' | 'name' | 'created'
  String _filter = 'All'; // 'All' | 'Recent' | 'Incomplete' | 'Popular'
  final Set<String> _selected = {};
  final Map<String, DateTime> _lastCopyTime = {};
  // snack showing state intentionally not tracked (we replace snackbars)

  void _showUndoSnackBar({required ScaffoldMessengerState messenger, required Future<String?> backupFuture, required VoidCallback onRestoreSuccess, required String quizTitle}) {
    // Replace any existing snackbar so each delete shows an undo option.
    const snackDur = Duration(seconds: 3);
    // show (replacing any existing)
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: snackDur,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  "Quiz ${quizTitle.replaceAll('\n', ' ')} deleted",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  minimumSize: const Size(64, 32),
                ),
                onPressed: () async {
                  messenger.hideCurrentSnackBar();
                  try {
                    final backupId = await backupFuture;
                    if (backupId != null) {
                      await FirestoreService().restoreQuizFromBackup(backupId);
                      if (!mounted) return;
                      setState(() => _load());
                      onRestoreSuccess();
                      messenger.showSnackBar(const SnackBar(duration: Duration(seconds: 2), content: Text('Quiz restored')));
                    } else {
                      messenger.showSnackBar(const SnackBar(content: Text('Undo unavailable')));
                    }
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(SnackBar(content: Text('Failed to restore: $e')));
                  }
                },
                child: const Text('Undo'),
              ),
            ]),
            const SizedBox(height: 4),
            _SnackBarTimer(startTime: DateTime.now(), duration: snackDur, height: 6.0),
          ],
        ),
      ),
    );

    // nothing else to track; snackbar will dismiss automatically
  }

  void _load() {
    final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
    _future = FirestoreService().getQuizzesByTeacher(uid);
  }

  List<QuizModel> _applyQuery(List<QuizModel> items) {
    var list = items.where((q) => q.title.toLowerCase().contains(_searchQuery.toLowerCase()) || q.description.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    // filters
    if (_filter == 'Recent') {
      list.sort((a, b) => (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt));
    } else if (_filter == 'Incomplete') {
      list = list.where((q) => q.totalQuestions == 0).toList();
    } else if (_filter == 'Popular') {
      // placeholder: no popularity metric available; keep as-is
    }
    // sort
    if (_sortBy == 'name') {
      list.sort((a, b) => a.title.compareTo(b.title));
    } else if (_sortBy == 'created') {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      list.sort((a, b) => (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt));
    }
    return list;
  }

  String _relativeTime(DateTime when) {
    final now = DateTime.now();
    final diff = now.difference(when);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    // Else show short date
    return '${when.month}/${when.day}/${when.year}';
  }

  Widget _sectionHeader(String title, int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            Text('($count)', style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
        const SizedBox(height: 6),
        Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _copyWithCooldown(String key, String text, String message) async {
    final now = DateTime.now();
    final last = _lastCopyTime[key];
    if (last != null && now.difference(last) < const Duration(milliseconds: 800)) return;
    _lastCopyTime[key] = now;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
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
      appBar: AppBar(
        title: const Text('My Quizzes'),
        actions: [
          if (_selected.isNotEmpty) ...[
            IconButton(onPressed: () => setState(() => _selected.clear()), tooltip: 'Cancel selection', icon: const Icon(Icons.close)),
            IconButton(onPressed: _batchPublishSelected, tooltip: 'Publish selected', icon: const Icon(Icons.publish)),
            IconButton(onPressed: _batchDeleteSelected, tooltip: 'Delete selected', icon: const Icon(Icons.delete_forever)),
          ]
        ],
      ),
      floatingActionButton: _selected.isNotEmpty ? FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.check_box),
        label: Text('${_selected.length} selected'),
      ) : null,
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
          if (quizzes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.quiz, size: 84, color: Colors.blueAccent),
                  const SizedBox(height: 16),
                  const Text('No quizzes yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Create your first quiz to get started. It will appear here and you can publish or share it.' , textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).pushNamed('/create_quiz');
                      if (mounted) setState(() => _load());
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Quiz'),
                  ),
                ]),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                // Search & controls
                Row(children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search quizzes'),
                        onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _sortBy,
                    items: const [DropdownMenuItem(value: 'updated', child: Text('Sort: Recent')), DropdownMenuItem(value: 'name', child: Text('Sort: Name')), DropdownMenuItem(value: 'created', child: Text('Sort: Created'))],
                    onChanged: (v) => setState(() => _sortBy = v ?? 'updated'),
                  ),
                ]),
                const SizedBox(height: 8),
                // Quick filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    ChoiceChip(label: const Text('All'), selected: _filter == 'All', onSelected: (_) => setState(() => _filter = 'All')),
                    const SizedBox(width: 8),
                    ChoiceChip(label: const Text('Recent'), selected: _filter == 'Recent', onSelected: (_) => setState(() => _filter = 'Recent')),
                    const SizedBox(width: 8),
                    ChoiceChip(label: const Text('Incomplete'), selected: _filter == 'Incomplete', onSelected: (_) => setState(() => _filter = 'Incomplete')),
                    const SizedBox(width: 8),
                    ChoiceChip(label: const Text('Popular'), selected: _filter == 'Popular', onSelected: (_) => setState(() => _filter = 'Popular')),
                  ]),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      _load();
                      // wait for future
                      await _future;
                    },
                    child: ListView(
                      children: [
                        _sectionHeader('Drafts', drafts.length),
                        for (var q in _applyQuery(drafts)) _buildQuizCard(q, isPublished: false),
                        const SizedBox(height: 12),
                        _sectionHeader('Published', published.length),
                        for (var q in _applyQuery(published)) _buildQuizCard(q, isPublished: true),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _batchPublishSelected() async {
    if (_selected.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final failures = <String>[];
    for (final id in _selected) {
      try {
        final qs = await FirestoreService().getQuizQuestions(id);
        if (qs.isEmpty) {
          failures.add('Quiz $id has no questions');
          continue;
        }
        await FirestoreService().publishQuiz(id, true);
      } catch (e) {
        failures.add('$id: $e');
      }
    }
    setState(() => _selected.clear());
    _load();
    if (failures.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Selected quizzes published')));
    } else {
      messenger.showSnackBar(SnackBar(content: Text('Some failed: ${failures.join(', ')}')));
    }
  }

  Future<void> _batchDeleteSelected() async {
    if (_selected.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Delete selected quizzes'), content: const Text('Delete selected quizzes? You can undo this from the snackbar immediately after.'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete'))]));
    if (confirmed != true) return;
    final ids = List<String>.from(_selected);
    // create backups
    final Map<String, String> backups = {};
    for (final id in ids) {
      try {
        final b = await FirestoreService().backupQuiz(id);
        backups[id] = b;
      } catch (_) {}
    }
    // delete
    for (final id in ids) {
      try {
        await FirestoreService().deleteQuiz(id);
      } catch (_) {}
    }
    setState(() => _selected.clear());
    _load();

    // Show undo snackbar that restores backups for any that were created
    final Future<String?> backupFuture = backups.isEmpty ? Future.value(null) : Future.value(backups.values.join(','));
    _showUndoSnackBar(messenger: messenger, backupFuture: backupFuture, onRestoreSuccess: () async {
      for (final b in backups.values) {
        try {
          await FirestoreService().restoreQuizFromBackup(b);
        } catch (_) {}
      }
      if (mounted) setState(() => _load());
    }, quizTitle: '${ids.length} quizzes');
  }

  Widget _buildQuizCard(QuizModel q, {required bool isPublished}) {
    final messenger = ScaffoldMessenger.of(context);
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (_selected.isNotEmpty) {
            setState(() {
              if (_selected.contains(q.id)) {
                _selected.remove(q.id);
              } else {
                _selected.add(q.id);
              }
            });
            return;
          }
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuizAnalysisScreen(quizId: q.id, initialTab: 'summary')));
        },
        onLongPress: () {
          setState(() => _selected.add(q.id));
        },
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(children: [
              if (_selected.contains(q.id))
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Checkbox(
                    value: true,
                    onChanged: (_) => setState(() {
                      if (_selected.contains(q.id)) {
                        _selected.remove(q.id);
                      } else {
                        _selected.add(q.id);
                      }
                    }),
                  ),
                ),
              CircleAvatar(radius: 28, backgroundColor: Colors.grey.shade100, child: Text(q.title.isEmpty ? '?' : q.title[0].toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(q.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18))),
                  ]),
                  const SizedBox(height: 6),
                  Text(q.description.isEmpty ? 'This quiz has no description' : q.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(_relativeTime(q.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(width: 12),
                    Icon(Icons.note, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text('${q.totalQuestions} questions', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ])
                ]),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  switch (v) {
                    case 'edit':
                      final res = await Navigator.of(context).pushNamed('/edit_quiz', arguments: q.id);
                      if (res == true && mounted) setState(() => _load());
                      break;
                    case 'copy':
                      await _copyWithCooldown(q.id, q.quizCode ?? '', 'Quiz code copied');
                      break;
                    case 'publish':
                      try {
                        final qs = await FirestoreService().getQuizQuestions(q.id);
                        if (qs.isEmpty) {
                          messenger.hideCurrentSnackBar();
                          messenger.showSnackBar(const SnackBar(content: Text('Cannot publish an empty quiz — add at least one question')));
                          return;
                        }
                        await FirestoreService().publishQuiz(q.id, true);
                        setState(() => _load());
                      } catch (e) {
                        messenger.hideCurrentSnackBar();
                        messenger.showSnackBar(SnackBar(content: Text('Failed to publish: $e')));
                      }
                      break;
                    case 'unpublish':
                      try {
                        await FirestoreService().publishQuiz(q.id, false);
                        setState(() => _load());
                      } catch (e) {
                        messenger.hideCurrentSnackBar();
                        messenger.showSnackBar(SnackBar(content: Text('Failed to unpublish: $e')));
                      }
                      break;
                    case 'delete':
                      final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Delete Quiz'), content: const Text('Delete this quiz?'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete'))]));
                      if (confirmed == true) {
                        final backupFuture = (() async { try { return await FirestoreService().backupQuiz(q.id); } catch (_) { return null; }})();
                        final deleteFuture = backupFuture.then((backupId) async {
                          try {
                            await FirestoreService().deleteQuiz(q.id);
                          } catch (_) {}
                          if (!mounted) {
                            return backupId;
                          }
                          setState(() => _load());
                          return backupId;
                        });
                        _showUndoSnackBar(messenger: messenger, backupFuture: backupFuture, onRestoreSuccess: () {}, quizTitle: q.title);
                        deleteFuture.catchError((e) {
                          if (!mounted) {
                            return null;
                          }
                          messenger.hideCurrentSnackBar();
                          messenger.showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
                          return null;
                        });
                      }
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'copy', child: Text('Copy code')),
                  if (!isPublished) const PopupMenuItem(value: 'publish', child: Text('Publish')),
                  if (isPublished) const PopupMenuItem(value: 'unpublish', child: Text('Unpublish')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              )
            ]),
          ),
          // status badge removed per UX request
        ]),
      ),
    );
  }
}
