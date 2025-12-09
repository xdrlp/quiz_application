import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:quiz_application/providers/auth_provider.dart';
import 'package:quiz_application/providers/quiz_provider.dart';
import 'package:quiz_application/screens/splash_screen.dart';
import 'package:quiz_application/screens/login_screen.dart';
import 'package:quiz_application/screens/home_screen.dart';
import 'package:quiz_application/screens/create_quiz_screen.dart';
import 'package:quiz_application/screens/find_quiz_screen.dart';
import 'package:quiz_application/screens/edit_quiz_screen.dart';
import 'package:quiz_application/screens/take_quiz_page.dart' as tqp;
import 'package:quiz_application/screens/my_quizzes_screen.dart';
import 'package:quiz_application/screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? firebaseInitError;
  try {
    if (kIsWeb) {
      // On web we must provide FirebaseOptions — use the generated file.
      // If you haven't configured web, regenerate `lib/firebase_options.dart`
      // with the FlutterFire CLI (`flutterfire configure`).
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      // Native platforms read their config from google-services.json / plist.
      await Firebase.initializeApp();
    }
  } catch (e) {
    firebaseInitError = e.toString();
    // Print to console for debugging; we'll show a friendly error UI below.
    // Do not rethrow so app can show the error screen instead of a white page.
    // ignore: avoid_print
    print('Firebase initialization error: $firebaseInitError');
  }
    runApp(MyApp(firebaseInitError: firebaseInitError));
}

class MyApp extends StatelessWidget {
    final String? firebaseInitError;

    const MyApp({super.key, this.firebaseInitError});

  @override
  Widget build(BuildContext context) {
      // If Firebase failed to initialize on web, show a helpful error page.
      if (kIsWeb && firebaseInitError != null) {
        return MaterialApp(
          title: 'Quiz Application - Configuration Error',
          home: Scaffold(
            appBar: AppBar(title: const Text('Firebase Configuration')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Firebase is not configured for web.',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(firebaseInitError ?? ''),
                    const SizedBox(height: 12),
                    const Text('Run `flutterfire configure` to generate web config.'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => QuizProvider()),
      ],
      child: MaterialApp(
        title: 'Quiz Application',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/create_quiz': (context) => const CreateQuizScreen(),
          '/find_quiz': (context) => const FindQuizScreen(),
          '/edit_quiz': (context) => const EditQuizScreen(),
          '/my_quizzes': (context) => const MyQuizzesScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/take_quiz': (context) {
            final args = ModalRoute.of(context)!.settings.arguments;
            final quizId = args is String ? args : '';
            return tqp.TakeQuizPage(quizId: quizId);
          },
        },
      ),
    );
  }
}

