import 'package:flutter/material.dart';
import 'package:quiz_application/models/question_model.dart';
import 'package:quiz_application/utils/answer_utils.dart';

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
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add Question' : 'Edit Question'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<QuestionType>(
              initialValue: _type,
              items: QuestionType.values
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(questionTypeDisplayName(t)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
              decoration: const InputDecoration(labelText: 'Question Type'),
            ),
            const SizedBox(height: 6),
            // show a short description of the selected question type below the dropdown
            Text(
              questionTypeDescription(_type),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _promptController,
              decoration: const InputDecoration(labelText: 'Prompt'),
            ),
            const SizedBox(height: 8),
            if (_type == QuestionType.multipleChoice || _type == QuestionType.checkbox || _type == QuestionType.dropdown)
              Column(
                children: [
                  for (var i = 0; i < _choices.length; i++)
                    Row(
                      children: [
                        if (_type == QuestionType.checkbox) ...[
                          Checkbox(
                            value: _correctAnswers.contains(_choices[i].id),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _correctAnswers.add(_choices[i].id);
                              } else {
                                _correctAnswers.remove(_choices[i].id);
                              }
                            }),
                          ),
                        ] else ...[
                          // Use an IconButton for single-selection to avoid deprecated Radio API
                          IconButton(
                            icon: Icon(_correctAnswers.contains(_choices[i].id)
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked),
                            onPressed: () => setState(() {
                              _correctAnswers.clear();
                              _correctAnswers.add(_choices[i].id);
                            }),
                          ),
                        ],
                        Expanded(
                          child: TextField(
                            controller: _choiceControllers.length > i ? _choiceControllers[i] : TextEditingController(text: _choices[i].text),
                            onChanged: (v) => _choices[i] = _choices[i].copyWith(text: v),
                            decoration: InputDecoration(labelText: 'Choice ${i + 1}'),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => setState(() {
                            final removedId = _choices[i].id;
                            _choices.removeAt(i);
                            if (_choiceControllers.length > i) {
                              _choiceControllers.removeAt(i).dispose();
                            }
                            _correctAnswers.remove(removedId);
                          }),
                        )
                      ],
                    ),
                  TextButton.icon(
                    onPressed: _addChoice,
                    icon: const Icon(Icons.add),
                    label: const Text('Add choice'),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            if (_type == QuestionType.shortAnswer || _type == QuestionType.paragraph)
              TextField(
                controller: _shortAnswerController,
                decoration: const InputDecoration(labelText: 'Correct answer (optional)'),
              ),
            Row(
              children: [
                const Text('Points'),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _points,
                    items: List.generate(10, (i) => i + 1)
                        .map((v) => DropdownMenuItem(value: v, child: Text(v.toString())))
                        .toList(),
                    onChanged: (v) => setState(() => _points = v ?? 1),
                    decoration: const InputDecoration(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
          onPressed: () {
            // Build metadata based on type (scale/grid removed)
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
              final hasEmpty = _choices.any((c) => c.text.trim().isEmpty);
              if (hasEmpty) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all choice text')));
                return;
              }
            }

            // Validation: require at least one correct answer for choice-like questions
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

            // Require a correct answer for short-answer questions
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
              choices: _choices,
              correctAnswers: correct,
              points: _points,
              metadata: metadata ?? widget.initial?.metadata,
              required: true,
              createdAt: widget.initial?.createdAt ?? DateTime.now(),
            );
            Navigator.of(context).pop(q);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
