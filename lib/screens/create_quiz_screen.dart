import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quiz_application/models/quiz_model.dart';
import 'package:quiz_application/providers/auth_provider.dart';
import 'package:quiz_application/services/firestore_service.dart';

class CreateQuizScreen extends StatefulWidget {
  const CreateQuizScreen({super.key});

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _timeController = TextEditingController(text: '10'); // minutes
  bool _loading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    final minutes = int.tryParse(_timeController.text) ?? 10;

    if (title.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a title')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final quiz = QuizModel(
        id: '',
        title: title,
        description: desc,
        timeLimitSeconds: minutes * 60,
        classIds: [],
        quizCode: _generateCode(),
        published: false,
        createdBy: user.uid,
        createdAt: DateTime.now(),
        totalQuestions: 0,
      );

      final id = await FirestoreService().createQuiz(quiz);
      if (!mounted) return;
      setState(() => _loading = false);

      // After creating a quiz, immediately open the editor so the user can
      // add questions. The code dialog will be shown only when the quiz is
      // published (from the Edit screen).
      Navigator.of(context).pushReplacementNamed('/edit_quiz', arguments: id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating quiz: $e')),
      );
    }
  }

  String _generateCode() {
    final rnd = DateTime.now().millisecondsSinceEpoch.remainder(1000000);
    return rnd.toString().padLeft(6, '0');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Quiz')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _timeController,
              decoration: const InputDecoration(labelText: 'Time limit (minutes)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading ? const CircularProgressIndicator() : const Text('Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
