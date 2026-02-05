import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:quiz_application/providers/auth_provider.dart';
import 'package:quiz_application/services/firestore_service.dart';
import 'package:flutter/scheduler.dart';
import 'package:quiz_application/models/quiz_model.dart';
import 'package:quiz_application/screens/quiz_analysis_screen.dart';

// ignore_for_file: use_super_parameters

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
  String _selectedMode = 'Recent'; // 'Recent' | 'Name' | 'Created' | 'Incomplete' | 'Popular'
  bool _sortAscending = false; // Default false (Descending/Newest First) for Recent/Created. True for Name.

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

  List<QuizModel> _filterAndSort(List<QuizModel> items) {
    // 1. Filter by Search Query
    var list = items.where((q) => 
      q.title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
      q.description.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
    
    
    // 3. Sort
    list.sort((a, b) {
      int cmp;
      if (_selectedMode == 'Name') {
        cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      } else if (_selectedMode == 'Created') {
        cmp = a.createdAt.compareTo(b.createdAt);
      } else {
        // 'Recent', 'Incomplete', 'Popular' -> Default to Updated/Created
        final da = a.updatedAt ?? a.createdAt;
        final db = b.updatedAt ?? b.createdAt;
        cmp = da.compareTo(db);
      }
      return _sortAscending ? cmp : -cmp; 
    });
    
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
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222222),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF222222),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Color(0xFF222222),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
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

  Widget _buildSkeletonQuizCard() {
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
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 200,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 60,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 200,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonQuizzesSection() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          // Search & controls (actual UI, not skeleton)
          Row(children: [
            Expanded(
              child: CustomPaint(
                painter: _GradientPainter(
                  strokeWidth: 1.5,
                  radius: 12,
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
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search quizzes',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF999999)),
                      hintStyle: const TextStyle(color: Color(0xFF999999), fontSize: 14),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          // Quick filters (actual UI, not skeleton)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _modeChip('Recent'),
              const SizedBox(width: 8),
              _modeChip('Name'),
              const SizedBox(width: 8),
              _modeChip('Created'),
              const SizedBox(width: 8),
              _modeChip('Popular'),
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                _sectionHeader('Drafts', 3),
                ...[0, 1, 2].map((_) => _buildSkeletonQuizCard()),
                const SizedBox(height: 12),
                _sectionHeader('Published', 2),
                ...[0, 1].map((_) => _buildSkeletonQuizCard()),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
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
                colors: [Color.fromARGB(255, 179, 179, 179), Color.fromARGB(255, 255, 255, 255)],
              ),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              color: const Color.fromARGB(255, 240, 240, 240),
              child: AppBar(
                scrolledUnderElevation: 0,
                systemOverlayStyle: SystemUiOverlayStyle.dark,
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: const Text('My Quizzes', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
                actions: [
                  if (_selected.isNotEmpty) ...[
                    IconButton(onPressed: () => setState(() => _selected.clear()), tooltip: 'Cancel selection', icon: const Icon(Icons.close, color: Colors.black54)),
                    IconButton(onPressed: _batchPublishSelected, tooltip: 'Publish selected', icon: const Icon(Icons.publish, color: Colors.black54)),
                    IconButton(onPressed: _batchDeleteSelected, tooltip: 'Delete selected', icon: const Icon(Icons.delete_forever, color: Colors.black54)),
                  ]
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: _selected.isNotEmpty ? FloatingActionButton.extended(
          onPressed: () {},
          backgroundColor: const Color(0xFF222222),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.check_box),
          label: Text('${_selected.length} selected'),
        ) : null,
        body: FutureBuilder<List<QuizModel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return _buildSkeletonQuizzesSection();
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
            final allQuizzes = snap.data ?? [];
            final processed = _filterAndSort(allQuizzes);
            final drafts = processed.where((q) => q.published == false).toList();
            final published = processed.where((q) => q.published == true).toList();

            if (allQuizzes.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.quiz, size: 84, color: Color.fromARGB(255, 0, 0, 0)),
                    const SizedBox(height: 16),
                    const Text('No quizzes yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF222222))),
                    const SizedBox(height: 8),
                    const Text('Create your first quiz to get started. It will appear here and you can publish or share it.' , textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF7F8C8D))),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).pushNamed('/create_quiz');
                        if (mounted) setState(() => _load());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF222222),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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
                      child: CustomPaint(
                        painter: _GradientPainter(
                          strokeWidth: 1.5,
                          radius: 12,
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
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search quizzes',
                              prefixIcon: const Icon(Icons.search, color: Color(0xFF999999)),
                              hintStyle: const TextStyle(color: Color(0xFF999999), fontSize: 14),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onChanged: (v) => setState(() => _searchQuery = v),
                          ),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  // Quick filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _modeChip('Recent'),
                      const SizedBox(width: 8),
                      _modeChip('Name'),
                      const SizedBox(width: 8),
                      _modeChip('Created'),
                      const SizedBox(width: 8),
                      _modeChip('Popular'),
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
                          for (var q in drafts) _buildQuizCard(q, isPublished: false),
                          const SizedBox(height: 12),
                          _sectionHeader('Published', published.length),
                          for (var q in published) _buildQuizCard(q, isPublished: true),
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
      ),
    );
  }

  Widget _modeChip(String label) {
    final selected = _selectedMode == label;
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? const Color(0xFF222222) : const Color(0xFFD0D0D0),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              if (_selectedMode == label) {
                // Toggle direction
                _sortAscending = !_sortAscending;
              } else {
                // Change mode and set default direction
                _selectedMode = label;
                if (label == 'Name') {
                  _sortAscending = true; // A-Z default
                } else {
                  _sortAscending = false; // Newest default
                }
              }
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? const Color(0xFF222222) : const Color(0xFF222222),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 4),
                  Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14,
                    color: const Color(0xFF222222),
                  ),
                ],
              ],
            ),
          ),
        ),
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
              padding: const EdgeInsets.all(16.0),
              child: Row(children: [
                if (_selected.contains(q.id))
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Icon(Icons.check_circle, color: const Color(0xFF222222), size: 24),
                  ),
                Container(
                  width: 56,
                  height: 56,
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
                  alignment: Alignment.center,
                  child: Text(
                    q.title.isEmpty ? '?' : q.title[0].toUpperCase(), 
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF222222))
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(q.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF222222)))),
                    ]),
                    const SizedBox(height: 4),
                    Text(q.description.isEmpty ? 'No description' : q.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color.fromARGB(255, 97, 97, 97))),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.calendar_today, size: 12, color: Color.fromARGB(255, 134, 134, 134)),
                      const SizedBox(width: 4),
                      Text(_relativeTime(q.createdAt), style: const TextStyle(fontSize: 11, color: Color.fromARGB(255, 126, 126, 126))),
                      const SizedBox(width: 12),
                      const Icon(Icons.people, size: 12, color: Color.fromARGB(255, 122, 122, 122)),
                      const SizedBox(width: 4),
                      Text('${q.totalAttempts} Respondents', style: const TextStyle(fontSize: 11, color: Color.fromARGB(255, 128, 128, 128))),
                    ])
                  ]),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Color.fromARGB(255, 135, 135, 135)),
                  tooltip: '',
                  color: const Color.fromARGB(244, 197, 197, 197),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFF666666), width: 1.5),
                  ),
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
                  if (!isPublished) const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500))),
                  const PopupMenuItem(value: 'copy', child: Text('Copy code', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500))),
                  if (!isPublished) const PopupMenuItem(value: 'publish', child: Text('Publish', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500))),
                  if (isPublished) const PopupMenuItem(value: 'unpublish', child: Text('Unpublish', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500))),
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500))),
                ],
              )
            ]),
          ),
          // status badge removed per UX request
        ]),
            ),
          ),
        ),
      ),
    );
  }
}
