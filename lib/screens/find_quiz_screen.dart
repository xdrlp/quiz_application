import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quiz_application/services/firestore_service.dart';
import 'package:quiz_application/models/quiz_model.dart';
import 'package:quiz_application/utils/snackbar_utils.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

class FindQuizScreen extends StatefulWidget {
  const FindQuizScreen({super.key});

  @override
  State<FindQuizScreen> createState() => _FindQuizScreenState();
}

class _FindQuizScreenState extends State<FindQuizScreen> {
  final _codeController = TextEditingController();
  QuizModel? _found;
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _loading = true);
    try {
      final q = await FirestoreService().getQuizByCode(code);
      if (!mounted) return;
      setState(() {
        _found = q;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      SnackBarUtils.showThemedSnackBar(ScaffoldMessenger.of(context), 'Error: $e', leading: Icons.error_outline);
    }
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
                scrolledUnderElevation: 0,
                systemOverlayStyle: SystemUiOverlayStyle.dark,
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: const Text('Find Quiz', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
              ),
            ),
          ),
        ),
        body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(hintText: 'Enter quiz code'),
                  ),
                ),
                const SizedBox(width: 8),
                _GradientButton(
                  onTap: _loading ? () {} : _search,
                  text: 'Search',
                  backgroundGradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFF1F00),
                      Color(0xFFDD1700),
                    ],
                  ),
                  textShadows: const [
                    Shadow(
                      color: Color.fromARGB(255, 0, 0, 0),
                      offset: Offset(1.2, 1.2),
                      blurRadius: 0.5,
                    ),
                  ],
                  height: 44.0,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading) const CircularProgressIndicator(),
            if (!_loading && _found == null) const Text('No quiz found.'),
            if (_found != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_found!.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_found!.description),
                      const SizedBox(height: 8),
                      Text('Time limit: ${_found!.timeLimitSeconds ~/ 60} minutes'),
                      const SizedBox(height: 8),
                      _GradientButton(
                        onTap: () {
                          Navigator.of(context).pushNamed('/take_quiz', arguments: _found!.id);
                        },
                        text: 'Start Quiz',
                        backgroundGradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFF1F00),
                            Color(0xFFDD1700),
                          ],
                        ),
                        textShadows: const [
                          Shadow(
                            color: Color.fromARGB(255, 0, 0, 0),
                            offset: Offset(1.2, 1.2),
                            blurRadius: 0.5,
                          ),
                        ],
                        height: 44.0,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

class _GradientButton extends StatefulWidget {
  final VoidCallback onTap;
  final String text;
  final LinearGradient backgroundGradient;
  final List<Shadow>? textShadows;
  final double? height;

  const _GradientButton({
    required this.onTap,
    required this.text,
    required this.backgroundGradient,
    this.textShadows,
    this.height,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    const double kButtonHeight = 44.0;
    final double available = MediaQuery.of(context).size.width - (32.0 * 2);
    final double buttonWidth = available > 360.0 ? 360.0 : available;
    final double height = widget.height ?? kButtonHeight;

    return Center(
      child: SizedBox(
        width: buttonWidth,
        height: height,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              transform: _isPressed 
                ? (Matrix4.identity()..scaleByVector3(vm.Vector3(0.98, 0.98, 1.0)))
                : Matrix4.identity(),
              transformAlignment: Alignment.center,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.fromARGB(
                      255,
                      _isHovered ? 255 : 248,
                      _isHovered ? 255 : 248,
                      _isHovered ? 255 : 248,
                    ),
                    Color.fromARGB(
                      255,
                      _isHovered ? 215 : 199,
                      _isHovered ? 215 : 199,
                      _isHovered ? 215 : 199,
                    ),
                    Color.fromARGB(
                      255,
                      _isHovered ? 255 : 248,
                      _isHovered ? 255 : 248,
                      _isHovered ? 255 : 248,
                    ),
                    Color.fromARGB(
                      255,
                      _isHovered ? 130 : 116,
                      _isHovered ? 130 : 116,
                      _isHovered ? 130 : 116,
                    ),
                    Color.fromARGB(
                      242,
                      _isHovered ? 75 : 61,
                      _isHovered ? 75 : 61,
                      _isHovered ? 75 : 61,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: _isHovered || _isPressed
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  gradient: widget.backgroundGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFFE9E9E9), Color(0xFFFFFFFF)],
                      ).createShader(bounds);
                    },
                    child: Text(
                      widget.text,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        shadows: widget.textShadows,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
