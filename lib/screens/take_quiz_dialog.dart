import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quiz_application/services/firestore_service.dart';
// models imported via FirestoreService responses; no direct model types required here

Future<void> showTakeQuizDialog(BuildContext context) async {
  final codeController = TextEditingController();
  bool isLoading = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        Future<void> pasteFromClipboard() async {
          final data = await Clipboard.getData('text/plain');
          if (data?.text != null) {
            codeController.text = data!.text!.trim();
          }
        }

        Future<void> takeQuiz() async {
          final code = codeController.text.trim();
          if (code.isEmpty) return;
          setState(() => isLoading = true);
          try {
            final quiz = await FirestoreService().getQuizByCode(code);
            if (quiz == null) {
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('No quiz found for that code')));
              setState(() => isLoading = false);
              return;
            }
            // fetch creator info
            final creator = await FirestoreService().getUser(quiz.createdBy);
            // if the quiz doc doesn't have a totalQuestions value set, fetch the questions
            // subcollection to compute an accurate count so the UI doesn't show 0.
            int questionCount = quiz.totalQuestions;
            try {
              if (questionCount == 0) {
                final qs = await FirestoreService().getQuizQuestions(quiz.id);
                questionCount = qs.length;
              }
            } catch (_) {
              // if fetching questions fails, fall back to the stored totalQuestions
            }
            if (!ctx.mounted) return;
            setState(() => isLoading = false);
            Navigator.of(ctx).pop(); // close code dialog
            // show summary (below)
              final nav = Navigator.of(context);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (sctx) {
                  final displayNameRaw = creator?.displayName ?? '';
                  final firstName = creator?.firstName ?? '';
                  final lastName = creator?.lastName ?? '';

                  // Normalize duplicates such as "Nepomuceno Nepomuceno"
                  String normalizeDuplicateTrailingWords(String s) {
                    final parts = s.trim().split(RegExp(r'\\s+'));
                    if (parts.length >= 2 && parts[parts.length - 1] == parts[parts.length - 2]) {
                      parts.removeLast();
                    }
                    return parts.join(' ');
                  }

                  final authorName = (displayNameRaw.trim().isNotEmpty)
                      ? normalizeDuplicateTrailingWords(displayNameRaw)
                      : normalizeDuplicateTrailingWords('$firstName $lastName');

                  return AlertDialog(
                    title: Text(quiz.title),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (quiz.description.isNotEmpty) Text(quiz.description),
                        const SizedBox(height: 8),
                        Text('Questions: $questionCount'),
                        const SizedBox(height: 8),
                        Text('Author: ${authorName.isNotEmpty ? authorName : 'Unknown'}'),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(sctx).pop(false), child: const Text('Close')),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(sctx).pop(true);
                        },
                        child: const Text('Attempt Quiz'),
                      ),
                    ],
                  );
                },
              );
              if (confirmed == true) {
                nav.pushNamed('/take_quiz', arguments: quiz.id);
              }
          } catch (e) {
            if (!ctx.mounted) return;
            setState(() => isLoading = false);
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        }

        return AlertDialog(
          title: const Text('Enter Quiz Code'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(
                    hintText: 'Quiz code',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.paste),
                      tooltip: 'Paste',
                      onPressed: pasteFromClipboard,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (isLoading) const CircularProgressIndicator(),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
            ElevatedButton(onPressed: takeQuiz, child: const Text('Take Quiz')),
          ],
        );
      });
    },
  );
}
