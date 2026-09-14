import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_vision/features/home/presentation/home_screen.dart';
import 'package:ai_vision/features/face_detection/presentation/face_detection_screen.dart';
import 'package:ai_vision/features/object_detection/presentation/object_detection_screen.dart';
import 'package:ai_vision/features/hand_detection/presentation/hand_detection_screen.dart';
import 'package:ai_vision/features/settings/presentation/settings_screen.dart';
import 'package:ai_vision/features/person_management/presentation/person_list_screen.dart';
import 'package:ai_vision/features/person_management/presentation/person_registration_screen.dart';
import 'package:ai_vision/features/person_management/presentation/person_detail_screen.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final Future<SharedPreferences> _prefsFuture;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _prefsFuture = SharedPreferences.getInstance();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await _prefsFuture;
    final isDark = prefs.getBool('isDarkMode') ?? false;
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _toggleTheme(bool isDark) async {
    final prefs = await _prefsFuture;
    await prefs.setBool('isDarkMode', isDark);
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = _createRouter();

    return MaterialApp.router(
      title: 'AI Vision',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: _themeMode,
      routerConfig: router,
    );
  }

  GoRouter _createRouter() {
    return GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/face',
          builder: (context, state) => const FaceDetectionScreen(),
        ),
        GoRoute(
          path: '/objects',
          builder: (context, state) => const ObjectDetectionScreen(),
        ),
        GoRoute(
          path: '/hands',
          builder: (context, state) => const HandDetectionScreen(),
        ),
        GoRoute(
          path: '/persons',
          builder: (context, state) => const PersonListScreen(),
        ),
        GoRoute(
          path: '/persons/create',
          builder: (context, state) => const PersonRegistrationScreen(),
        ),
        GoRoute(
          path: '/persons/:id',
          builder: (context, state) => PersonDetailScreen(
            personId: int.parse(state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => SettingsScreen(onThemeChanged: _toggleTheme),
        ),
      ],
    );
  }
}
