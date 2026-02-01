import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:quiz_application/screens/starter_screen.dart';
import 'package:quiz_application/services/local_violation_store.dart';
import 'package:quiz_application/providers/auth_provider.dart';
import 'package:quiz_application/providers/quiz_provider.dart';
import 'package:quiz_application/screens/splash_screen.dart';
import 'package:quiz_application/screens/login_screen.dart';
import 'package:quiz_application/screens/signup_screen.dart';
import 'package:quiz_application/screens/home_screen.dart';
import 'package:quiz_application/screens/create_quiz_screen.dart';
import 'package:quiz_application/screens/find_quiz_screen.dart';
import 'package:quiz_application/screens/edit_quiz_screen.dart';
import 'package:quiz_application/screens/take_quiz_page.dart' as tqp;
import 'package:quiz_application/screens/my_quizzes_screen.dart';
import 'package:quiz_application/screens/profile_screen.dart';
import 'package:quiz_application/screens/quiz_history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Hive local store for anti-cheat evidence logging.
  try {
    await LocalViolationStore.init();
  } catch (e) {
    // ignore: avoid_print
    print('LocalViolationStore init failed: $e');
  }
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
        theme: (() {
          // Core colors
          const absBlack = Color(0xFF050507);
          const coldSteel = Color(0xFF0F172A);
          const ashWhite = Color(0xFFE5E5E5);
          const deadGray = Color(0xFF4B5563);
          const dividerColor = Color(0xFF1F2937);
          const crimson = Color(0xFF8B0000);
          const violationColor = Color(0xFFB00020);

          final base = ColorScheme.dark().copyWith(
            surface: coldSteel,
            onSurface: ashWhite,
            primary: ashWhite,
            secondary: const Color(0xFF9CA3AF),
          );

          return ThemeData(
            useMaterial3: true,
            // Use slide-only page transitions to avoid fade/opacity flashes
            pageTransitionsTheme: const PageTransitionsTheme(builders: {
              TargetPlatform.android: SlidePageTransitionsBuilder(),
              TargetPlatform.iOS: SlidePageTransitionsBuilder(),
              TargetPlatform.linux: SlidePageTransitionsBuilder(),
              TargetPlatform.macOS: SlidePageTransitionsBuilder(),
              TargetPlatform.windows: SlidePageTransitionsBuilder(),
              TargetPlatform.fuchsia: SlidePageTransitionsBuilder(),
            }),
            colorScheme: base,
            scaffoldBackgroundColor: absBlack,
            cardColor: crimson,
            dividerColor: dividerColor,
            canvasColor: absBlack,
            disabledColor: deadGray,
            appBarTheme: AppBarTheme(
              backgroundColor: crimson,
              foregroundColor: Colors.black,
              elevation: 0,
              titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w700),
              iconTheme: IconThemeData(color: Colors.black),
            ),
            // Switched to Google Fonts "Inter" for consistent rendering on all devices.
            fontFamily: GoogleFonts.inter().fontFamily,
            textTheme: GoogleFonts.interTextTheme(TextTheme(
              titleLarge: TextStyle(color: ashWhite),
              bodyLarge: TextStyle(color: ashWhite),
              bodyMedium: TextStyle(color: const Color(0xFF9CA3AF)),
              labelSmall: TextStyle(color: const Color(0xFF9CA3AF)),
            )),
            iconTheme: IconThemeData(color: ashWhite),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(backgroundColor: coldSteel, foregroundColor: ashWhite),
            ),
            // Card visuals are set per-card in UI; cardColor is set above.
            extensions: <ThemeExtension<dynamic>>[
              const MonitoringColors(monitoringColor: Color(0x1A8B0000), violationColor: violationColor),
            ],
          );
        })(),
        home: const AuthGate(),
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/create_quiz': (context) => const CreateQuizScreen(),
          '/find_quiz': (context) => const FindQuizScreen(),
          '/edit_quiz': (context) => const EditQuizScreen(),
          '/my_quizzes': (context) => const MyQuizzesScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/quiz_history': (context) => const QuizHistoryScreen(),
          '/signup': (context) => const SignUpScreen(),
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

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<fb_auth.User?> _authStream;
  fb_auth.User? _lastUser;

  @override
  void initState() {
    super.initState();
    _authStream = fb_auth.FirebaseAuth.instance.authStateChanges();
    _lastUser = fb_auth.FirebaseAuth.instance.currentUser;
    _authStream.listen((user) {
      if (!mounted) return;
      if (user == _lastUser) return;
      _lastUser = user;
      // Replace the entire navigation stack so users cannot navigate back
      // into authenticated screens after signing out.
      if (user == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const StarterScreen()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    });
    // Precache frequently-used large assets to avoid frame drops / black flashes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        precacheImage(const AssetImage('assets/images/background.png'), context);
        precacheImage(const AssetImage('assets/images/starter_elements.png'), context);
        precacheImage(const AssetImage('assets/images/create_account_button.png'), context);
      } catch (_) {
        // ignore precache failures
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = fb_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return const StarterScreen();
    // Directly go to HomeScreen instead of showing the SplashScreen
    return const HomeScreen();
  }
}

class MonitoringColors extends ThemeExtension<MonitoringColors> {
  final Color? monitoringColor;
  final Color? violationColor;

  const MonitoringColors({this.monitoringColor, this.violationColor});

  @override
  MonitoringColors copyWith({Color? monitoringColor, Color? violationColor}) {
    return MonitoringColors(
      monitoringColor: monitoringColor ?? this.monitoringColor,
      violationColor: violationColor ?? this.violationColor,
    );
  }

  @override
  MonitoringColors lerp(ThemeExtension<MonitoringColors>? other, double t) {
    if (other is! MonitoringColors) return this;
    return MonitoringColors(
      monitoringColor: Color.lerp(monitoringColor, other.monitoringColor, t),
      violationColor: Color.lerp(violationColor, other.violationColor, t),
    );
  }
}

// Custom transitions builder that performs a simple horizontal slide
// without any fade/opacity animation to avoid blinking between routes.
class SlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const SlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final offsetAnimation = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
        .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
    return SlideTransition(position: offsetAnimation, child: child);
  }
}

