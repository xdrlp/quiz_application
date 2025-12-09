import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quiz_application/providers/auth_provider.dart';
// user_model import removed — roles simplified
import 'package:quiz_application/screens/take_quiz_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.person),
          onPressed: () {
            Navigator.of(context).pushNamed('/profile');
          },
        ),
        title: const Text('Quiz Application'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthProvider>().logout();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Welcome, ${authProvider.currentUser?.displayName}!',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/create_quiz');
                  },
                  child: const Text('Create Quiz'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/my_quizzes');
                  },
                  child: const Text('My Quizzes'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Open code-entry dialog to take a quiz directly
                    showTakeQuizDialog(context);
                  },
                  child: const Text('Take Quiz'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
