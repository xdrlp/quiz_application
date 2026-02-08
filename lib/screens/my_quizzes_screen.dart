import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:quiz_application/providers/auth_provider.dart';
import 'package:quiz_application/services/firestore_service.dart';
import 'package:quiz_application/models/quiz_model.dart';
import 'package:quiz_application/screens/quiz_analysis_screen.dart';
import 'package:quiz_application/utils/snackbar_utils.dart';

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

class _MyQuizzesScreenState extends State<MyQuizzesScreen> {
  bool _loading = true;
  List<QuizModel> _quizzes = [];
  String _searchQuery = '';
  String _selectedMode = 'Recent'; // 'Recent' | 'Name' | 'Created' | 'Incomplete' | 'Popular'
  bool _sortAscending = false; // Default false (Descending/Newest First) for Recent/Created. True for Name.

  final Set<String> _selected = {};
  final Map<String, DateTime> _lastCopyTime = {};
  // snack showing state intentionally not tracked (we replace snackbars)

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> _showUndoSnackBar({
    required ScaffoldMessengerState messenger, 
    required VoidCallback onUndo, 
    required String itemInfo, 
    bool hasFloatingButtons = false
  }) {
    // Replace any existing snackbar so each delete shows an undo option.
    const snackDur = Duration(seconds: 5);
    // Adjust margin if floating buttons are present
    final margin = hasFloatingButtons
        ? const EdgeInsets.fromLTRB(48, 12, 48, 120)  // Extra bottom margin for FABs
        : const EdgeInsets.fromLTRB(48, 12, 48, 20);
        
    messenger.hideCurrentSnackBar();
    return messenger.showSnackBar(SnackBar(
      duration: snackDur,
      behavior: SnackBarBehavior.floating,
      margin: margin,
      elevation: 0,
      backgroundColor: Colors.transparent,
      content: CustomPaint(
        painter: GradientPainter(
          strokeWidth: 1.5,
          radius: 16,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.fromARGB(255, 0, 0, 0), Color.fromARGB(255, 151, 151, 151), Color.fromARGB(255, 180, 180, 180), Color.fromARGB(255, 255, 255, 255)],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color.fromARGB(34, 143, 143, 143),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.delete_outline, size: 20, color: Colors.black54),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    itemInfo,
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
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    onUndo();
                  },
                  child: const Text('Undo'),
                ),
              ]),
              const SizedBox(height: 4),
              SnackBarTimer(startTime: DateTime.now(), duration: snackDur, height: 6.0),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _buildOutlinedButton({
    required VoidCallback onPressed,
    required IconData icon,
    required Color hoverColor,
    required Color splashColor,
  }) {
    return SizedBox(
      width: 56,
      height: 56,
      child: InkWell(
        onTap: onPressed,
        hoverColor: hoverColor,
        splashColor: splashColor,
        borderRadius: BorderRadius.circular(20),
        child: CustomPaint(
          painter: _GradientPainter(
            strokeWidth: 2,
            radius: 16,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Color(0xFF333333), Color(0xFF666666), Colors.white],
            ),
          ),
          child: Container(
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.black, size: 24),
          ),
        ),
      ),
    );
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
    setState(() => _loading = true);
    try {
      _quizzes = await FirestoreService().getQuizzesByTeacher(uid);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
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
    _showThemedSnackBar(messenger, message, duration: const Duration(seconds: 1));
  }

  void _showThemedSnackBar(ScaffoldMessengerState messenger, String message, {Duration? duration, IconData? leading, bool showClose = true}) {
    SnackBarUtils.showThemedSnackBar(messenger, message, duration: duration, leading: leading, showClose: showClose);
  }

  Widget _buildSkeletonQuizCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: CustomPaint(
        painter: GradientPainter(
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
                painter: GradientPainter(
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
                  // Debug button: temporarily show the Undo snackbar for testing
                  IconButton(
                    icon: const Icon(Icons.bug_report, color: Colors.black54),
                    tooltip: 'Debug: show Undo snackbar',
                    onPressed: () {
                      final messenger = ScaffoldMessenger.of(context);
                      _showUndoSnackBar(
                        messenger: messenger,
                        onUndo: () => SnackBarUtils.showThemedSnackBar(messenger, 'Undo pressed'),
                        itemInfo: 'Debug Quiz deleted',
                        hasFloatingButtons: false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: AnimatedSwitcher(
          duration: Duration.zero,
          child: _selected.isNotEmpty
              ? Column(
                  key: const ValueKey('fab_column'),
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_areAllSelectedDrafts())
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _buildOutlinedButton(
                          onPressed: _batchPublishSelected,
                          icon: Icons.publish,
                          hoverColor: const Color.fromARGB(255, 76, 175, 80).withValues(alpha: 0.9),
                          splashColor: const Color.fromARGB(255, 76, 175, 80).withValues(alpha: 1),
                        ),
                      ),
                    if (_areAllSelectedPublished())
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _buildOutlinedButton(
                          onPressed: _batchDraftSelected,
                          icon: Icons.visibility_off,
                          hoverColor: const Color.fromARGB(255, 255, 152, 0).withValues(alpha: 0.9),
                          splashColor: const Color.fromARGB(255, 255, 152, 0).withValues(alpha: 1),
                        ),
                      ),
                    _buildOutlinedButton(
                      onPressed: () {
                        setState(() {
                          if (_selected.length == _filterAndSort(_quizzes).length) {
                            _selected.clear();
                          } else {
                            _selected.addAll(_filterAndSort(_quizzes).map((q) => q.id));
                          }
                        });
                      },
                      icon: _selected.length == _filterAndSort(_quizzes).length ? Icons.done_all : Icons.select_all,
                      hoverColor: const Color(0xFF2196F3).withValues(alpha: 0.9),
                      splashColor: const Color(0xFF2196F3).withValues(alpha: 1),
                    ),
                    const SizedBox(height: 8),
                    _buildOutlinedButton(
                      onPressed: () => setState(() => _selected.clear()),
                      icon: Icons.close,
                      hoverColor: const Color.fromARGB(255, 143, 143, 143).withValues(alpha: 0.9),
                      splashColor: const Color.fromARGB(255, 77, 77, 77).withValues(alpha: 1),
                    ),
                    const SizedBox(height: 8),
                    _buildOutlinedButton(
                      onPressed: _batchDeleteSelected,
                      icon: Icons.delete,
                      hoverColor: const Color.fromARGB(255, 255, 25, 0).withValues(alpha: 0.9),
                      splashColor: const Color.fromARGB(255, 255, 25, 0).withValues(alpha: 1),
                    ),
                  ],
                )
              : const SizedBox.shrink(key: ValueKey('fab_empty')),
        ),
        body: _loading
            ? _buildSkeletonQuizzesSection()
            : _quizzes.isEmpty
                ? Center(
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
                            if (mounted) await _load();
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
                  )
                : Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        // Search & controls
                        Row(children: [
                          Expanded(
                            child: CustomPaint(
                              painter: GradientPainter(
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
                        if (_selected.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_selected.length} selected',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF222222)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              children: [
                                _sectionHeader('Drafts', _filterAndSort(_quizzes).where((q) => q.published == false).length),
                                for (var q in _filterAndSort(_quizzes).where((q) => q.published == false)) _buildQuizCard(q, isPublished: false),
                                const SizedBox(height: 12),
                                _sectionHeader('Published', _filterAndSort(_quizzes).where((q) => q.published == true).length),
                                for (var q in _filterAndSort(_quizzes).where((q) => q.published == true)) _buildQuizCard(q, isPublished: true),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
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

  bool _areAllSelectedDrafts() {
    if (_selected.isEmpty) return false;
    return _quizzes.where((q) => _selected.contains(q.id)).every((q) => !q.published);
  }

  bool _areAllSelectedPublished() {
    if (_selected.isEmpty) return false;
    return _quizzes.where((q) => _selected.contains(q.id)).every((q) => q.published);
  }

  Future<void> _batchDraftSelected() async {
    if (_selected.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final ids = List<String>.from(_selected);
    final failures = <String>[];
    for (final id in ids) {
      try {
        await FirestoreService().publishQuiz(id, false);
        // Update local list
        final index = _quizzes.indexWhere((q) => q.id == id);
        if (index != -1) {
          _quizzes[index] = _quizzes[index].copyWith(published: false);
        }
      } catch (e) {
        failures.add('$id: $e');
      }
    }
    if (mounted) {
      setState(() {
        _selected.clear();
      });
    }
    if (failures.isEmpty) {
      _showThemedSnackBar(messenger, 'Selected quizzes drafted', leading: Icons.check_circle_outline);
    } else {
      _showThemedSnackBar(messenger, 'Some failed: ${failures.join(', ')}', leading: Icons.error_outline);
    }
  }

  Future<void> _batchPublishSelected() async {
    if (_selected.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final ids = List<String>.from(_selected);
    final failures = <String>[];
    for (final id in ids) {
      try {
        final qs = await FirestoreService().getQuizQuestions(id);
        if (qs.isEmpty) {
          failures.add('Quiz $id has no questions');
          continue;
        }
        await FirestoreService().publishQuiz(id, true);
        // Update local list
        final index = _quizzes.indexWhere((q) => q.id == id);
        if (index != -1) {
          _quizzes[index] = _quizzes[index].copyWith(published: true);
        }
      } catch (e) {
        failures.add('$id: $e');
      }
    }
    if (mounted) {
      setState(() {
        _selected.clear();
      });
    }
    if (failures.isEmpty) {
      _showThemedSnackBar(messenger, 'Selected quizzes published', leading: Icons.check_circle_outline);
    } else {
      _showThemedSnackBar(messenger, 'Some failed: ${failures.join(', ')}', leading: Icons.error_outline);
    }
  }

  Future<void> _batchDeleteSelected() async {
    if (_selected.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);

    // Get quizzes to delete
    final quizzesToDelete = _quizzes.where((q) => _selected.contains(q.id)).toList();
    final quizTitles = quizzesToDelete.map((q) => q.title).toList();

    final quizInfo = quizTitles.length == 1 
        ? 'Quiz "${quizTitles.first}" deleted'
        : '${quizTitles.length} quizzes deleted';

    // Optimistic UI update: Remove from display immediately
    setState(() {
      _quizzes.removeWhere((q) => _selected.contains(q.id));
      _selected.clear();
    });

    bool undoPressed = false;

    // Show undo snackbar
    final controller = _showUndoSnackBar(
      messenger: messenger,
      onUndo: () {
        undoPressed = true;
        // Restore items to UI
        setState(() {
          _quizzes.addAll(quizzesToDelete);
        });
        SnackBarUtils.showThemedSnackBar(messenger, 'Quizzes restored', leading: Icons.check_circle_outline);
      },
      itemInfo: quizInfo,
      hasFloatingButtons: false,  // FABs are gone since selection is cleared
    );

    // When snackbar closes, if not undone and timer ran out, perform actual delete
    controller.closed.then((reason) {
      if (!undoPressed && reason == SnackBarClosedReason.timeout) {
        for (final quiz in quizzesToDelete) {
          FirestoreService().deleteQuiz(quiz.id).catchError((e) {
            debugPrint('Delete failed for quiz ${quiz.id}: $e');
          });
        }
      }
    });
  }

  Widget _buildQuizCard(QuizModel q, {required bool isPublished}) {
    final messenger = ScaffoldMessenger.of(context);
    return Container(
      key: ValueKey(q.id),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: CustomPaint(
        painter: GradientPainter(
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
                  // Check if adding this quiz would mix categories
                  final firstSelectedQuiz = _quizzes.firstWhere((quiz) => _selected.contains(quiz.id));
                  if (firstSelectedQuiz.published == q.published) {
                    _selected.add(q.id);
                  } else {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    _showThemedSnackBar(ScaffoldMessenger.of(context), 'Can only select quizzes from the same category (draft or published)', leading: Icons.info_outline);
                  }
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
                          _showThemedSnackBar(messenger, 'Cannot publish an empty quiz — add at least one question', leading: Icons.error_outline);
                          return;
                        }
                        await FirestoreService().publishQuiz(q.id, true);
                        // Update local list
                        if (mounted) {
                          setState(() {
                            final index = _quizzes.indexWhere((quiz) => quiz.id == q.id);
                            if (index != -1) {
                              _quizzes[index] = _quizzes[index].copyWith(published: true);
                            }
                          });
                        }
                      } catch (e) {
                        messenger.hideCurrentSnackBar();
                        _showThemedSnackBar(messenger, 'Failed to publish: $e', leading: Icons.error_outline);
                      }
                      break;
                    case 'unpublish':
                      try {
                        await FirestoreService().publishQuiz(q.id, false);
                        // Update local list
                        if (mounted) {
                          setState(() {
                            final index = _quizzes.indexWhere((quiz) => quiz.id == q.id);
                            if (index != -1) {
                              _quizzes[index] = _quizzes[index].copyWith(published: false);
                            }
                          });
                        }
                      } catch (e) {
                        messenger.hideCurrentSnackBar();
                        _showThemedSnackBar(messenger, 'Failed to unpublish: $e', leading: Icons.error_outline);
                      }
                      break;
                    case 'delete':
                      // Optimistic UI update: Remove from display immediately
                      setState(() {
                        _quizzes.removeWhere((quiz) => quiz.id == q.id);
                      });

                      bool undoPressed = false;

                      // Show undo snackbar
                      final controller = _showUndoSnackBar(
                        messenger: messenger,
                        onUndo: () {
                          undoPressed = true;
                          // Restore item to UI
                          setState(() {
                            _quizzes.add(q);
                          });
                          SnackBarUtils.showThemedSnackBar(messenger, 'Quiz restored', leading: Icons.check_circle_outline);
                        },
                        itemInfo: 'Quiz "${q.title}" deleted',
                        hasFloatingButtons: false,
                      );

                      // When snackbar closes, if not undone and timer ran out, perform actual delete
                      controller.closed.then((reason) {
                        if (!undoPressed && reason == SnackBarClosedReason.timeout) {
                          FirestoreService().deleteQuiz(q.id).catchError((e) {
                            debugPrint('Delete failed for quiz ${q.id}: $e');
                          });
                        }
                      });
                      break;
                  }
                },
                itemBuilder: (_) => [
                  if (!isPublished) const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500))),
                  if (isPublished) const PopupMenuItem(value: 'copy', child: Text('Copy code', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500))),
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
