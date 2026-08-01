import 'package:flutter_test/flutter_test.dart';
import 'package:fluentup/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TtsService fallback triggers flutter_tts gracefully when proxy function is invalid', () async {
    // Attempting to speak with an invalid proxy trigger or network failure
    // Should catch exception silently and trigger fallbackTts without throw/crash
    bool exceptionThrown = false;
    try {
      await TtsService.instance.speak(
        "Testing automatic fallback voice engine",
        customVoice: "invalid_test_voice_name",
      );
    } catch (e) {
      exceptionThrown = true;
    }

    expect(exceptionThrown, false, reason: "TtsService should catch proxy failure silently and fall back without throwing errors");
  });

  test('TtsService returns correct voice mappings per persona', () {
    expect(TtsService.getVoiceForPersona(personaName: "Maya"), "en-US-AriaNeural");
    expect(TtsService.getVoiceForPersona(personaName: "Alex"), "en-US-GuyNeural");
    expect(TtsService.getVoiceForPersona(personaName: "CharacterA"), "en-US-DavisNeural");
    expect(TtsService.getVoiceForPersona(isDialogueCharacterB: true), "en-GB-SoniaNeural");
    expect(TtsService.getVoiceForPersona(language: "Hindi"), "hi-IN-SwaraNeural");
    expect(TtsService.getVoiceForPersona(language: "Marathi"), "mr-IN-AarohiNeural");
  });
}
