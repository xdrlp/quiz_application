import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:quiz_application/services/firestore_service.dart';
import 'package:quiz_application/providers/auth_provider.dart';
import 'package:quiz_application/models/attempt_model.dart';
import 'package:quiz_application/models/quiz_model.dart';

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
  String _searchQuery = '';
  String _selectedMode = 'Recent'; // 'Recent' | 'Quiz Name' | 'Date Submitted'
  bool _sortAscending = false;
  final Set<String> _selected = {};

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

  List<AttemptModel> _filterAndSort(List<AttemptModel> items) {
    // Filter by Search Query
    var list = items.where((a) {
      final q = _quizCache[a.quizId];
      final title = q?.title ?? 'Unknown Quiz';
      return title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // Sort
    list.sort((a, b) {
      int cmp;
      if (_selectedMode == 'Quiz Name') {
        final titleA = _quizCache[a.quizId]?.title ?? 'Unknown';
        final titleB = _quizCache[b.quizId]?.title ?? 'Unknown';
        cmp = titleA.toLowerCase().compareTo(titleB.toLowerCase());
      } else if (_selectedMode == 'Date Submitted') {
        final dateA = a.submittedAt ?? a.startedAt;
        final dateB = b.submittedAt ?? b.startedAt;
        cmp = dateA.compareTo(dateB);
      } else {
        // 'Recent' -> Default to submitted/started
        final dateA = a.submittedAt ?? a.startedAt;
        final dateB = b.submittedAt ?? b.startedAt;
        cmp = dateA.compareTo(dateB);
      }
      return _sortAscending ? cmp : -cmp;
    });

    return list;
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  Future<void> _batchDeleteSelected() async {
    if (_selected.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete selected attempts'),
        content: const Text('Delete selected quiz attempts? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE74C3C)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ids = List<String>.from(_selected);
    for (final id in ids) {
      try {
        await _fs.deleteAttempt(id);
      } catch (_) {}
    }
    setState(() => _selected.clear());
    _load();
    messenger.showSnackBar(const SnackBar(content: Text('Selected attempts deleted')));
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
                if (label == 'Quiz Name') {
                  _sortAscending = true; // A-Z default
                } else {
                  _sortAscending = false; // Newest default
                }
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(color: selected ? const Color(0xFF222222) : const Color(0xFF999999))),
                if (selected) ...[
                  const SizedBox(width: 6),
                  Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: const Color(0xFF222222)),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonAttemptCard() {
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
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 150,
                        height: 14,
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
                const SizedBox(width: 12),
                Container(
                  width: 50,
                  height: 40,
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

  Widget _buildSkeletonHistorySection() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          // Search bar (actual UI)
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
                      hintText: 'Search attempts',
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
          // Filter chips (actual UI)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _modeChip('Recent'),
              const SizedBox(width: 8),
              _modeChip('Quiz Name'),
              const SizedBox(width: 8),
              _modeChip('Date Submitted'),
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: 6,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              itemBuilder: (context, index) => _buildSkeletonAttemptCard(),
            ),
          ),
        ],
      ),
    );
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
                  onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => route.isFirst),
                ),
                title: const Text('Quiz History', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
              ),
            ),
          ),
        ),
        floatingActionButton: _selected.isNotEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        if (_selected.length == _filterAndSort(_attempts).length) {
                          _selected.clear();
                        } else {
                          _selected.addAll(_filterAndSort(_attempts).map((a) => a.id));
                        }
                      });
                    },
                    backgroundColor: const Color(0xFF2196F3),
                    child: Icon(
                      _selected.length == _filterAndSort(_attempts).length ? Icons.done_all : Icons.select_all,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    onPressed: () => setState(() => _selected.clear()),
                    backgroundColor: Colors.grey,
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    onPressed: _batchDeleteSelected,
                    backgroundColor: const Color(0xFFE74C3C),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                ],
              )
            : null,
        body: _loading
            ? _buildSkeletonHistorySection()
            : _attempts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No quiz attempts yet', 
                          style: TextStyle(fontSize: 18, color: const Color.fromARGB(255, 116, 116, 116))
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        // Search bar
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
                                    hintText: 'Search quiz history',
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
                            _modeChip('Quiz Name'),
                            const SizedBox(width: 8),
                            _modeChip('Date Submitted'),
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
                            onRefresh: () async {
                              _load();
                            },
                            child: ListView.separated(
                              itemCount: _filterAndSort(_attempts).length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              itemBuilder: (context, index) {
                                final filteredAttempts = _filterAndSort(_attempts);
                                final a = filteredAttempts[index];
                                final q = _quizCache[a.quizId];
                                final title = q?.title ?? 'Unknown Quiz';
                                final when = a.submittedAt ?? a.startedAt;
                                final ago = _relativeTime(when);
                                
                                return Container(
                                  key: ValueKey(a.id),
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
                                                if (_selected.contains(a.id)) {
                                                  _selected.remove(a.id);
                                                } else {
                                                  _selected.add(a.id);
                                                }
                                              });
                                              return;
                                            }
                                            Navigator.of(context).pushNamed('/attempt_review', arguments: a.id);
                                          },
                                          onLongPress: () {
                                            setState(() => _selected.add(a.id));
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Row(
                                              children: [
                                                if (_selected.contains(a.id))
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
                                                  child: const Icon(Icons.assignment_turned_in, color: Color.fromARGB(255, 70, 70, 70), size: 28),
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
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
      ),
    );
  }
}
