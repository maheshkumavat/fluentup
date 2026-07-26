import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import 'otp_verification_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    if (SupabaseService.instance.isInitialized && SupabaseService.instance.client != null) {
      _authSubscription = SupabaseService.instance.client!.auth.onAuthStateChange.listen((data) {
        final session = data.session;
        if (session != null && mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.instance.signInWithGoogle();
      // Do NOT navigate to /home immediately upon launching browser.
      // Wait for authStateChange callback on OAuth redirect.
      Future.delayed(const Duration(seconds: 20), () {
        if (mounted && _isLoading && !SupabaseService.instance.isLoggedIn) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Google Sign-In error: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleEmailSendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = "Please enter a valid email address.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.instance.sendEmailOtp(email);
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(email: email),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to send code: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.containerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // Branding Logo & Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.language, color: AppTheme.primary, size: 32),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "FluentUp",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                "Welcome to FluentUp",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Master English speaking confidence with AI voice practice, instant feedback, and structured roadmaps.",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              // Google OAuth Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  icon: CachedNetworkImage(
                    imageUrl: 'https://lh3.googleusercontent.com/COxitImplementedGoogleIconLogoPlaceholder',
                    width: 20,
                    height: 20,
                    errorWidget: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 28, color: AppTheme.primary),
                  ),
                  label: const Text(
                    "Continue with Google",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.hairline, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    minimumSize: const Size(double.infinity, 56),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Row(
                children: [
                  Expanded(child: Divider(color: AppTheme.hairline)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      "OR WITH EMAIL",
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: AppTheme.hairline)),
                ],
              ),
              const SizedBox(height: 24),

              // Email OTP Registration / Login Box
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 15, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: "Email Address",
                  hintText: "name@example.com",
                  prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.textSecondary),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: const BorderSide(color: AppTheme.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: const BorderSide(color: AppTheme.hairline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.error),
                ),
                const SizedBox(height: 12),
              ],

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleEmailSendOtp,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text("Send Verification Code"),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  "First time? We'll create your account automatically. Returning? We'll log you in.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
