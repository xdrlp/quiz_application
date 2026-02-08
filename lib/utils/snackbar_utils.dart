import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class GradientPainter extends CustomPainter {
  final double radius;
  final double strokeWidth;
  final Gradient gradient;

  GradientPainter({
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

class SnackBarTimer extends StatefulWidget {
  final DateTime startTime;
  final Duration duration;
  final double height;
  const SnackBarTimer({super.key, required this.startTime, required this.duration, this.height = 4.0});

  @override
  State<SnackBarTimer> createState() => _SnackBarTimerState();
}

class _SnackBarTimerState extends State<SnackBarTimer> {
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
        valueColor: AlwaysStoppedAnimation<Color>(const Color.fromARGB(121, 5, 5, 5)),
      ),
    );
  }
}

class SnackBarUtils {
  static void showThemedSnackBar(
    ScaffoldMessengerState messenger,
    String message, {
    Duration? duration,
    IconData? leading,
    bool showClose = true,
  }) {
    messenger.hideCurrentSnackBar();
    final snackDur = duration ?? const Duration(seconds: 2);
    final icon = leading ?? _iconForMessage(message);
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(48, 12, 48, 20),
      elevation: 0,
      backgroundColor: Colors.transparent,
      duration: snackDur,
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
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: Colors.black54),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
              if (showClose)
                InkWell(
                  onTap: () => messenger.hideCurrentSnackBar(),
                  child: const Padding(padding: EdgeInsets.all(4.0), child: Icon(Icons.close, size: 20, color: Colors.black54)),
                ),
            ],
          ),
        ),
      ),
    ));
  }

  static IconData? _iconForMessage(String message) {
    final m = message.toLowerCase();
    if (m.contains('error') || m.contains('failed') || m.contains('undo unavailable') || m.contains('incorrect')) {
      return Icons.error_outline;
    }
    if (m.contains('copied') || m.contains('restored') || m.contains('published') || m.contains('created') || m.contains('saved')) {
      return Icons.check_circle_outline;
    }
    if (m.contains('deleted')) return Icons.delete_outline;
    if (m.contains('quiz code')) return Icons.code;
    return null;
  }
}
