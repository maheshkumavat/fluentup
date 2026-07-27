import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  static final VoiceService instance = VoiceService._internal();
  VoiceService._internal();

  List<dynamic> _availableVoices = [];
  Map<String, String>? _voiceCoach;
  Map<String, String>? _voiceSpeakerA;
  Map<String, String>? _voiceSpeakerB;
  bool _initialized = false;

  Future<void> init(FlutterTts tts) async {
    if (_initialized) return;
    try {
      final voices = await tts.getVoices;
      if (voices is List && voices.isNotEmpty) {
        _availableVoices = voices;
        debugPrint("🎙️ [VOICE SERVICE] Found ${_availableVoices.length} system TTS voices.");

        // Filter English voices
        final englishVoices = _availableVoices.where((v) {
          if (v is Map) {
            final locale = (v['locale'] ?? v['lang'] ?? '').toString().toLowerCase();
            final name = (v['name'] ?? '').toString().toLowerCase();
            return locale.contains('en') || name.contains('en');
          }
          return false;
        }).toList();

        final voicePool = englishVoices.isNotEmpty ? englishVoices : _availableVoices;

        Map<String, String> parseVoiceMap(dynamic item) {
          if (item is Map) {
            final name = (item['name'] ?? '').toString();
            final locale = (item['locale'] ?? item['lang'] ?? 'en-US').toString();
            return {"name": name, "locale": locale};
          }
          return {"name": "", "locale": "en-US"};
        }

        if (voicePool.length >= 3) {
          _voiceCoach = parseVoiceMap(voicePool[0]);
          _voiceSpeakerA = parseVoiceMap(voicePool[1]);
          _voiceSpeakerB = parseVoiceMap(voicePool[2]);
        } else if (voicePool.length == 2) {
          _voiceCoach = parseVoiceMap(voicePool[0]);
          _voiceSpeakerA = parseVoiceMap(voicePool[0]);
          _voiceSpeakerB = parseVoiceMap(voicePool[1]);
        } else if (voicePool.isNotEmpty) {
          _voiceCoach = parseVoiceMap(voicePool[0]);
          _voiceSpeakerA = parseVoiceMap(voicePool[0]);
          _voiceSpeakerB = parseVoiceMap(voicePool[0]);
        }
      }
      _initialized = true;
    } catch (e) {
      debugPrint("Notice initializing voices: $e");
    }
  }

  Future<void> configureVoiceForPersona(FlutterTts tts, {required String persona, double basePitch = 1.0, double baseRate = 0.5}) async {
    await init(tts);

    Map<String, String>? targetVoice;
    double targetPitch = basePitch;
    double targetRate = baseRate;

    if (persona == 'Coach' || persona == 'AI') {
      targetVoice = _voiceCoach;
      targetPitch = 1.05;
      targetRate = 0.50;
    } else if (persona == 'SpeakerA' || persona == 'RoleA' || persona == 'UserA') {
      targetVoice = _voiceSpeakerA;
      targetPitch = 1.25;
      targetRate = 0.48;
    } else if (persona == 'SpeakerB' || persona == 'RoleB' || persona == 'UserB') {
      targetVoice = _voiceSpeakerB;
      targetPitch = 0.85;
      targetRate = 0.52;
    }

    if (targetVoice != null && targetVoice['name']!.isNotEmpty) {
      try {
        await tts.setVoice(targetVoice);
        debugPrint("🎙️ [VOICE SERVICE] Assigned voice for '$persona': ${targetVoice['name']} (${targetVoice['locale']})");
      } catch (e) {
        debugPrint("Notice setting voice map: $e");
      }
    }

    await tts.setPitch(targetPitch);
    await tts.setSpeechRate(targetRate);
  }
}
