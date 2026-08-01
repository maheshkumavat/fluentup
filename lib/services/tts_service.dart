import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'supabase_service.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  static TtsService get instance => _instance;
  TtsService._internal() {
    _initFallbackTts();
  }

  final FlutterTts _fallbackTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<String, Uint8List> _audioCache = {};

  Future<void> _initFallbackTts() async {
    try {
      await _fallbackTts.setLanguage("en-US");
      await _fallbackTts.setSpeechRate(0.5);
      await _fallbackTts.setVolume(1.0);
    } catch (e) {
      debugPrint("Fallback TTS init notice: $e");
    }
  }

  /// Maps persona/language names to Microsoft Edge TTS neural voices
  static String getVoiceForPersona({
    String? personaName,
    String? language,
    String? gender,
    bool isDialogueCharacterB = false,
  }) {
    // 1. Language specific neural voice overrides
    if (language != null && language.isNotEmpty) {
      final lowerLang = language.toLowerCase();
      if (lowerLang.contains("hindi") || lowerLang.startsWith("hi")) {
        return "hi-IN-SwaraNeural";
      }
      if (lowerLang.contains("marathi") || lowerLang.startsWith("mr")) {
        return "mr-IN-AarohiNeural";
      }
      if (lowerLang.contains("gujarati") || lowerLang.startsWith("gu")) {
        return "gu-IN-DhwaniNeural";
      }
      if (lowerLang.contains("tamil") || lowerLang.startsWith("ta")) {
        return "ta-IN-PallaviNeural";
      }
      if (lowerLang.contains("telugu") || lowerLang.startsWith("te")) {
        return "te-IN-MohanNeural";
      }
      if (lowerLang.contains("bengali") || lowerLang.startsWith("bn")) {
        return "bn-IN-TanishaaNeural";
      }
      if (lowerLang.contains("kannada") || lowerLang.startsWith("kn")) {
        return "kn-IN-SapnaNeural";
      }
      if (lowerLang.contains("malayalam") || lowerLang.startsWith("ml")) {
        return "ml-IN-SobhanaNeural";
      }
      if (lowerLang.contains("punjabi") || lowerLang.startsWith("pa")) {
        return "pa-IN-OjasNeural";
      }
    }

    // 2. Dialogue Practice Characters
    if (isDialogueCharacterB) {
      return "en-GB-SoniaNeural"; // British female voice for character B
    }
    if (personaName == "CharacterA" || personaName == "Davis") {
      return "en-US-DavisNeural"; // Distinct American male voice for character A
    }

    // 3. Main AI Coach Personas (Maya, Alex, Sam, etc.)
    if (personaName != null && personaName.isNotEmpty) {
      final name = personaName.trim().toLowerCase();
      if (name.contains("alex") || name.contains("guy") || gender == "male") {
        return "en-US-GuyNeural";
      }
      if (name.contains("sam") || name.contains("jenny")) {
        return "en-US-JennyNeural";
      }
      if (name.contains("maya") || name.contains("aria")) {
        return "en-US-AriaNeural";
      }
    }

    // Default Main AI Coach Voice
    return "en-US-AriaNeural";
  }

  /// Stop current playing audio or TTS speech
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    try {
      await _fallbackTts.stop();
    } catch (_) {}
  }

  /// Primary speak method with Edge TTS & automatic flutter_tts fallback
  Future<void> speak(
    String text, {
    String? personaName,
    String? language,
    String? customVoice,
    String? rate = "+0%",
    bool isDialogueCharacterB = false,
  }) async {
    if (text.trim().isEmpty) return;

    final targetVoice = customVoice ??
        getVoiceForPersona(
          personaName: personaName,
          language: language,
          isDialogueCharacterB: isDialogueCharacterB,
        );

    final cleanText = text.trim();
    final cacheKey = "${targetVoice}_${rate}_$cleanText";

    // 1. Check in-memory audio cache for instant playback
    if (_audioCache.containsKey(cacheKey)) {
      try {
        await stop();
        await _audioPlayer.play(BytesSource(_audioCache[cacheKey]!));
        return;
      } catch (e) {
        debugPrint("Error playing cached audio: $e");
      }
    }

    // 2. Attempt Edge TTS Proxy synthesis via Supabase Edge Function
    bool edgeTtsSuccess = false;

    if (SupabaseService.instance.isInitialized) {
      try {
        final client = SupabaseService.instance.client;
        if (client != null) {
          final res = await client.functions
              .invoke(
                'tts-proxy',
                body: {
                  'text': cleanText,
                  'voice': targetVoice,
                  'rate': rate ?? "+0%",
                },
              )
              .timeout(const Duration(seconds: 5));

          if (res.status == 200 && res.data != null) {
            Map<String, dynamic> resData;
            if (res.data is Map<String, dynamic>) {
              resData = Map<String, dynamic>.from(res.data as Map<String, dynamic>);
            } else if (res.data is String) {
              resData = jsonDecode(res.data as String) as Map<String, dynamic>;
            } else {
              resData = {};
            }

            final base64Audio = resData['audio_base64'] as String?;
            if (base64Audio != null && base64Audio.isNotEmpty) {
              final audioBytes = base64Decode(base64Audio);
              _audioCache[cacheKey] = audioBytes; // Save to cache

              await stop();
              await _audioPlayer.play(BytesSource(audioBytes));
              edgeTtsSuccess = true;
              return;
            }
          }
        }
      } catch (e) {
        debugPrint("Edge TTS Proxy call failed/timed out, triggering silent fallback to flutter_tts: $e");
      }
    }

    // 3. CRITICAL FALLBACK: Silently fall back to flutter_tts if Edge TTS fails/times out
    if (!edgeTtsSuccess) {
      try {
        await stop();
        if (language != null && language.toLowerCase().contains("hindi")) {
          await _fallbackTts.setLanguage("hi-IN");
        } else {
          await _fallbackTts.setLanguage("en-US");
        }

        // Adjust pitch based on persona for distinct fallback voices
        double pitch = 1.0;
        if (isDialogueCharacterB) {
          pitch = 1.2;
        } else if (personaName?.toLowerCase().contains("alex") == true) {
          pitch = 0.85;
        }
        await _fallbackTts.setPitch(pitch);

        await _fallbackTts.speak(cleanText);
      } catch (e) {
        debugPrint("Fallback TTS error: $e");
      }
    }
  }

  /// Sets completion handler for audio playback or fallback TTS
  void setCompletionHandler(VoidCallback callback) {
    _audioPlayer.onPlayerComplete.listen((_) => callback());
    _fallbackTts.setCompletionHandler(callback);
  }
}
