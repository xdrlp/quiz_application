import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quiz_application/services/firestore_service.dart';
import 'package:quiz_application/models/quiz_model.dart';
import 'package:quiz_application/utils/snackbar_utils.dart';

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
                ElevatedButton(onPressed: _loading ? null : _search, child: const Text('Search')),
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
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed('/take_quiz', arguments: _found!.id);
                        },
                        child: const Text('Start Quiz'),
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
