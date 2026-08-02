import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../services/supabase_service.dart';
import '../services/update_service.dart';
import '../theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _opacity = 0.0;
  double _translateY = 16.0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _opacity = 1.0;
          _translateY = 0.0;
        });
      }
    });

    // Run cold-start update check FIRST before auth/onboarding/home routing decision
    _runStartupSequence();
  }

  Future<void> _runStartupSequence() async {
    debugPrint("[Splash] Checking for updates...");

    bool isAvailable = false;
    try {
      isAvailable = await UpdateService.instance.checkForUpdates(context).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint("[Splash] Update check timed out after 3 seconds");
          return false;
        },
      );
    } catch (e) {
      debugPrint("[Splash] Update check error: $e");
      isAvailable = false;
    }

    debugPrint("[Splash] Update check result: ${isAvailable ? 'available' : 'not available'}");

    if (!mounted) return;

    // Brief delay to ensure splash animation is visible if check completes fast
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // Evaluate Auth & Onboarding state AFTER update check
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final isCompleted = await chatProvider.isOnboardingCompleted();
    final isLoggedIn = SupabaseService.instance.isLoggedIn;

    String routeName = '/auth';
    String routeLog = 'Auth';
    if (isLoggedIn) {
      if (isCompleted) {
        routeName = '/home';
        routeLog = 'Home';
      } else {
        routeName = '/onboarding';
        routeLog = 'Onboarding';
      }
    }

    debugPrint("[Splash] Proceeding to route: $routeLog");
    if (mounted) {
      Navigator.pushReplacementNamed(context, routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(0, _translateY, 0),
                child: AnimatedOpacity(
                  opacity: _opacity,
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Stitch Brand Logo Card Container (24px radius)
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.25),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.language,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Brand Title
                      const Text(
                        "FluentUp",
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.02 * 32,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tagline
                      const Text(
                        "AI Spoken English & Fluency Coach",
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),

            // Bottom subtle loading indicator
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.primary.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
