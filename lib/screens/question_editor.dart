import 'package:flutter/material.dart';
import 'package:quiz_application/models/question_model.dart';
import 'package:quiz_application/utils/answer_utils.dart';

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

class QuestionEditor extends StatefulWidget {
  final QuestionModel? initial;
  const QuestionEditor({super.key, this.initial});

  @override
  State<QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<QuestionEditor> {
  late QuestionType _type;
  final _promptController = TextEditingController();
  final List<Choice> _choices = [];
  final List<TextEditingController> _choiceControllers = [];
  int _points = 1;
  final Set<String> _correctAnswers = {};
  final _shortAnswerController = TextEditingController();
  // (scale and grid question types removed)

  // File upload metadata
  // (file upload removed for quiz/exam app)

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _type = init?.type ?? QuestionType.multipleChoice;
    _promptController.text = init?.prompt ?? '';
    _choices.addAll(init?.choices ?? []);
    for (var c in _choices) {
      _choiceControllers.add(TextEditingController(text: c.text));
    }
    _correctAnswers.addAll(init?.correctAnswers ?? []);
    // If this is a short answer/paragraph type, populate the short answer field
    if ((_type == QuestionType.shortAnswer || _type == QuestionType.paragraph) && (init?.correctAnswers.isNotEmpty ?? false)) {
      _shortAnswerController.text = init!.correctAnswers.first;
    }
    _points = init?.points ?? 1;
    // questions are required by default in a quiz/exam
    // keep model field but always set true when saving
    // no metadata to load for removed types

    // no file-upload metadata — removed
  }

  @override
  void dispose() {
    _promptController.dispose();
    for (var c in _choiceControllers) {
      c.dispose();
    }
    _shortAnswerController.dispose();
    // no controllers for removed types
    // file-upload removed
    super.dispose();
  }

  void _addChoice() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _choices.add(Choice(id: id, text: ''));
      _choiceControllers.add(TextEditingController(text: ''));
    });
  }

  // grid helpers removed

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: CustomPaint(
        painter: _GradientPainter(
          strokeWidth: 2,
          radius: 20,
          gradient: const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color.fromARGB(255, 109, 109, 109), Color.fromARGB(255, 224, 224, 224)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 550),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromARGB(255, 220, 220, 220),
                  Color.fromARGB(255, 180, 180, 180),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.initial == null ? 'Add Question' : 'Edit Question',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF222222),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildQuestionTypeSelector(),
                  const SizedBox(height: 20),
                  _buildGradientTextField(
                    controller: _promptController,
                    hint: 'Question prompt',
                    icon: Icons.help,
                  ),
                  const SizedBox(height: 20),
                  if (_type == QuestionType.multipleChoice || _type == QuestionType.checkbox || _type == QuestionType.dropdown)
                    _buildChoicesSection(),
                  if (_type == QuestionType.shortAnswer || _type == QuestionType.paragraph)
                    _buildShortAnswerSection(),
                  if (_type == QuestionType.multipleChoice || _type == QuestionType.checkbox || _type == QuestionType.dropdown || _type == QuestionType.shortAnswer || _type == QuestionType.paragraph)
                    const SizedBox(height: 20),
                  _buildPointsSelector(),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel', style: TextStyle(color: Color.fromARGB(255, 59, 59, 59), fontSize: 15, fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF222222),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _saveQuestion,
                        child: const Text('Save', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Question Type',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF222222),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        PopupMenuButton<QuestionType>(
          initialValue: _type,
          constraints: const BoxConstraints(),
          onSelected: (QuestionType type) => setState(() => _type = type),
          color: const Color.fromARGB(244, 197, 197, 197),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF666666), width: 1.5),
          ),
          position: PopupMenuPosition.under,
          itemBuilder: (BuildContext context) => QuestionType.values
              .map((t) => PopupMenuItem(
                    value: t,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    height: 44,
                    child: Text(
                      questionTypeDisplayName(t),
                      style: const TextStyle(
                        color: Color(0xFF222222),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ))
              .toList(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF666666), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  questionTypeDisplayName(_type),
                  style: const TextStyle(
                    color: Color(0xFF222222),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Icon(Icons.expand_more, color: Color(0xFF333333), size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          questionTypeDescription(_type),
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF555555),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildGradientTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return CustomPaint(
      painter: _GradientPainter(
        strokeWidth: 1.5,
        radius: 10,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.white],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          controller: controller,
          style: const TextStyle(color: Color(0xFF222222), fontSize: 15, fontWeight: FontWeight.w500),
          cursorColor: Colors.black54,
          maxLines: null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF999999), fontSize: 15),
            prefixIcon: Icon(icon, color: Color.fromARGB(255, 124, 124, 124), size: 20),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildChoicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choices',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF222222),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _choices.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                if (_type == QuestionType.checkbox)
                  Checkbox(
                    value: _correctAnswers.contains(_choices[i].id),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _correctAnswers.add(_choices[i].id);
                      } else {
                        _correctAnswers.remove(_choices[i].id);
                      }
                    }),
                    side: const BorderSide(color: Color(0xFFD0D0D0)),
                  )
                else
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    icon: Icon(
                      _correctAnswers.contains(_choices[i].id)
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: const Color(0xFF222222),
                      size: 22,
                    ),
                    onPressed: () => setState(() {
                      _correctAnswers.clear();
                      _correctAnswers.add(_choices[i].id);
                    }),
                  ),
                Expanded(
                  child: _buildGradientTextField(
                    controller: _choiceControllers[i],
                    hint: 'Choice ${i + 1}',
                    icon: Icons.edit,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFF555555), size: 20),
                  onPressed: () => setState(() {
                    final removedId = _choices[i].id;
                    _choices.removeAt(i);
                    _choiceControllers.removeAt(i).dispose();
                    _correctAnswers.remove(removedId);
                  }),
                ),
              ],
            ),
          ),
        Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF666666), width: 1.5),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _addChoice,
                customBorder: const CircleBorder(),
                child: const Icon(Icons.add, size: 18, color: Color(0xFF222222)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShortAnswerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Correct Answer',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF222222),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        _buildGradientTextField(
          controller: _shortAnswerController,
          hint: 'Enter correct answer (optional)',
          icon: Icons.check,
        ),
      ],
    );
  }

  Widget _buildPointsSelector() {
    return Row(
      children: [
        const Text(
          'Points',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF222222),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 80,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF666666), width: 1),
          ),
          child: DropdownButtonFormField<int>(
            initialValue: _points,
            dropdownColor: Colors.white,
            icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF333333), size: 20),
            items: List.generate(10, (i) => i + 1)
                .map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(
                        v.toString(),
                        style: const TextStyle(color: Color(0xFF222222), fontSize: 14),
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _points = v ?? 1),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            style: const TextStyle(color: Color(0xFF222222), fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.expand_less, color: Color(0xFF333333), size: 20),
          onPressed: () => setState(() => _points = (_points + 1).clamp(1, 10)),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.expand_more, color: Color(0xFF333333), size: 20),
          onPressed: () => setState(() => _points = (_points - 1).clamp(1, 10)),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  void _saveQuestion() {
    Map<String, dynamic>? metadata;
    List<String> correct = [];
    if (_type == QuestionType.shortAnswer || _type == QuestionType.paragraph) {
      final raw = _shortAnswerController.text.trim();
      if (raw.isNotEmpty) {
        correct = [normalizeAnswerForComparison(raw)];
      }
    } else {
      correct = _correctAnswers.toList();
    }

    // Validate choices for choice-like questions
    if (_type == QuestionType.multipleChoice || _type == QuestionType.checkbox || _type == QuestionType.dropdown) {
      if (_choices.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one choice')));
        return;
      }
      final hasEmpty = _choiceControllers.any((controller) => controller.text.trim().isEmpty);
      if (hasEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all choice text')));
        return;
      }
    }

    final requiresCorrect = {
      QuestionType.multipleChoice,
      QuestionType.checkbox,
      QuestionType.dropdown,
    };
    if (requiresCorrect.contains(_type) && correct.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please mark at least one correct answer')));
      return;
    }

    if (_type == QuestionType.shortAnswer) {
      final raw = _shortAnswerController.text.trim();
      if (raw.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Short answer questions require a correct answer')));
        return;
      }
    }

    final q = QuestionModel(
      id: widget.initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: _type,
      prompt: _promptController.text.trim(),
      order: widget.initial?.order ?? 0,
      choices: List.generate(_choices.length, (i) => _choices[i].copyWith(text: _choiceControllers[i].text.trim())),
      correctAnswers: correct,
      points: _points,
      metadata: metadata ?? widget.initial?.metadata,
      required: true,
      createdAt: widget.initial?.createdAt ?? DateTime.now(),
    );
    Navigator.of(context).pop(q);
  }
}
