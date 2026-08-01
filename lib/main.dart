import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'providers/chat_provider.dart';
import 'providers/gym_provider.dart';
import 'providers/roleplay_provider.dart';
import 'providers/code_explanation_provider.dart';
import 'providers/vocabulary_provider.dart';
import 'providers/progress_provider.dart';
import 'providers/roadmap_provider.dart';
import 'providers/practice_call_provider.dart';
import 'providers/mission_provider.dart';
import 'providers/real_world_mission_provider.dart';
import 'services/supabase_service.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/baseline_assessment_screen.dart';
import 'screens/topic_library_screen.dart';
import 'screens/describe_image_screen.dart';
import 'screens/presentation_practice_screen.dart';
import 'screens/vocabulary_screen.dart';
import 'screens/real_world_missions_screen.dart';
import 'screens/sound_practice_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: Could not load .env file: $e");
  }

  await SupabaseService.instance.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => GymProvider()),
        ChangeNotifierProvider(create: (_) => RoleplayProvider()),
        ChangeNotifierProvider(create: (_) => CodeExplanationProvider()),
        ChangeNotifierProvider(create: (_) => VocabularyProvider()),
        ChangeNotifierProvider(create: (_) => ProgressProvider()),
        ChangeNotifierProvider(create: (_) => RoadmapProvider()),
        ChangeNotifierProvider(create: (_) => PracticeCallProvider()),
        ChangeNotifierProvider(create: (_) => MissionProvider()),
        ChangeNotifierProvider(create: (_) => RealWorldMissionProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FluentUp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/auth': (context) => const AuthScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/baseline': (context) => const BaselineAssessmentScreen(),
        '/home': (context) => const HomeScreen(),
        '/topics': (context) => const TopicLibraryScreen(),
        '/describe-image': (context) => const DescribeImageScreen(),
        '/presentation-practice': (context) => const PresentationPracticeScreen(),
        '/vocabulary': (context) => const VocabularyScreen(),
        '/sound-practice': (context) => const SoundPracticeScreen(),
      },
    );
  }
}
