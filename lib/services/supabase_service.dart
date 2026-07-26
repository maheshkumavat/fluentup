import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'db_helper.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  static SupabaseService get instance => _instance;
  SupabaseService._internal();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (url.isEmpty || url == 'PLACEHOLDER_SUPABASE_URL' || anonKey.isEmpty || anonKey == 'PLACEHOLDER_SUPABASE_ANON_KEY') {
      debugPrint("Supabase notice: SUPABASE_URL or SUPABASE_ANON_KEY not configured in .env.");
      return;
    }

    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
      _initialized = true;
    } catch (e) {
      debugPrint("Error initializing Supabase: $e");
    }
  }

  SupabaseClient? get client => _initialized ? Supabase.instance.client : null;

  User? get currentUser => client?.auth.currentUser;
  String? get currentUserId => currentUser?.id;
  bool get isLoggedIn => currentUser != null;

  Future<bool> signInWithGoogle() async {
    if (!isInitialized || client == null) {
      throw Exception("Supabase is not configured with a valid URL/Key in .env");
    }

    try {
      return await client!.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.fluentup://login-callback/',
      );
    } catch (e) {
      debugPrint("Error in Google Sign-In: $e");
      rethrow;
    }
  }

  Future<void> sendEmailOtp(String email) async {
    if (!isInitialized || client == null) {
      throw Exception("Supabase is not configured with a valid URL/Key in .env");
    }

    try {
      await client!.auth.signInWithOtp(
        email: email.trim(),
        shouldCreateUser: true,
      );
    } catch (e) {
      debugPrint("Error sending Email OTP: $e");
      rethrow;
    }
  }

  Future<AuthResponse> verifyEmailOtp(String email, String token) async {
    if (!isInitialized || client == null) {
      throw Exception("Supabase is not configured with a valid URL/Key in .env");
    }

    try {
      final response = await client!.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: OtpType.email,
      );
      return response;
    } catch (e) {
      debugPrint("Error verifying OTP: $e");
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (isInitialized && client != null) {
      await client!.auth.signOut();
    }
    await DbHelper.instance.clearUserData();
  }

  static String cleanGroqContent(String rawContent) {
    return rawContent.replaceAll(RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false), '').trim();
  }

  Future<Map<String, dynamic>> invokeGroqProxy(Map<String, dynamic> body) async {
    if (!isInitialized || client == null) {
      throw Exception("Supabase is not initialized. Please ensure SUPABASE_URL and SUPABASE_ANON_KEY are set.");
    }
    final response = await client!.functions.invoke(
      'groq-proxy',
      body: body,
    );
    if (response.status != 200) {
      throw Exception("Groq proxy error (Status ${response.status}): ${response.data}");
    }
    Map<String, dynamic> resMap;
    if (response.data is Map<String, dynamic>) {
      resMap = Map<String, dynamic>.from(response.data as Map<String, dynamic>);
    } else if (response.data is String) {
      resMap = jsonDecode(response.data as String) as Map<String, dynamic>;
    } else {
      throw Exception("Invalid response format from Groq proxy Edge Function.");
    }

    // Clean reasoning tags from choices content if present
    try {
      if (resMap.containsKey('choices') && (resMap['choices'] as List).isNotEmpty) {
        final choice = resMap['choices'][0];
        if (choice is Map && choice.containsKey('message') && choice['message'] is Map) {
          final messageMap = Map<String, dynamic>.from(choice['message'] as Map);
          if (messageMap.containsKey('content') && messageMap['content'] is String) {
            messageMap['content'] = cleanGroqContent(messageMap['content'] as String);
            resMap['choices'][0]['message'] = messageMap;
          }
        }
      }
    } catch (e) {
      debugPrint("Notice: Error cleaning Groq content tags: $e");
    }

    return resMap;
  }

  Future<Map<String, dynamic>> invokeUnsplashProxy() async {
    if (!isInitialized || client == null) {
      throw Exception("Supabase is not initialized. Please ensure SUPABASE_URL and SUPABASE_ANON_KEY are set.");
    }
    final response = await client!.functions.invoke(
      'unsplash-proxy',
      body: {},
    );
    if (response.status != 200) {
      throw Exception("Unsplash proxy error (Status ${response.status}): ${response.data}");
    }
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    } else if (response.data is String) {
      return jsonDecode(response.data as String) as Map<String, dynamic>;
    }
    throw Exception("Invalid response format from Unsplash proxy Edge Function.");
  }

  Future<Map<String, dynamic>> invokeVersionProxy() async {
    if (!isInitialized || client == null) {
      throw Exception("Supabase is not initialized. Please ensure SUPABASE_URL and SUPABASE_ANON_KEY are set.");
    }
    final response = await client!.functions.invoke(
      'version-proxy',
      body: {},
    );
    if (response.status != 200) {
      throw Exception("Version proxy error (Status ${response.status}): ${response.data}");
    }
    if (response.data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(response.data as Map<String, dynamic>);
    } else if (response.data is String) {
      return jsonDecode(response.data as String) as Map<String, dynamic>;
    }
    throw Exception("Invalid response format from Version proxy Edge Function.");
  }
}
