import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../theme.dart';
import '../services/supabase_service.dart';
import '../services/tts_service.dart';
import 'coach_avatar.dart';

class FloatingAssistantWidget extends StatefulWidget {
  const FloatingAssistantWidget({super.key});

  @override
  State<FloatingAssistantWidget> createState() => _FloatingAssistantWidgetState();
}

class _FloatingAssistantWidgetState extends State<FloatingAssistantWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _openAssistantSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const DoubtAssistantSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: GestureDetector(
            onTap: _openAssistantSheet,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.surfaceContainer,
                border: Border.all(color: AppTheme.primary, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.35 * _scaleAnim.value),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: const CoachAvatar(size: 48),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class DoubtAssistantSheet extends StatefulWidget {
  const DoubtAssistantSheet({super.key});

  @override
  State<DoubtAssistantSheet> createState() => _DoubtAssistantSheetState();
}

class _DoubtAssistantSheetState extends State<DoubtAssistantSheet> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isSpeechAvailable = false;
  bool _isListening = false;
  bool _isSending = false;
  bool _isSpeakingTts = false;

  String _selectedSttLocale = 'en-US'; // Options: 'en-US', 'hi-IN', 'mr-IN'

  final List<Map<String, String>> _messages = [
    {
      "role": "assistant",
      "content": "Hi! Ask me any doubt about English grammar, words, or why an answer was marked wrong in your practice sessions!"
    }
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    try {
      _isSpeechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
        },
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  void _toggleListening() async {
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      status = await Permission.microphone.request();
      if (!status.isGranted) return;
    }

    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    } else {
      if (!_isSpeechAvailable) return;
      setState(() {
        _isListening = true;
      });

      _speech.listen(
        localeId: _selectedSttLocale,
        onResult: (result) {
          setState(() {
            _inputController.text = result.recognizedWords;
          });
        },
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    _inputController.clear();
    setState(() {
      _messages.add({"role": "user", "content": text});
      _isSending = true;
    });

    _scrollToBottom();

    try {
      final conversationPayload = _messages.map((m) {
        return {
          "role": m["role"] == "user" ? "user" : "assistant",
          "content": m["content"],
        };
      }).toList();

      final systemPrompt =
          "You are a helpful, quick, doubt-clearing English AI Coach in FluentUp.\n"
          "The user is asking a question or doubt about English grammar, vocabulary, usage, or exercise errors.\n"
          "CRITICAL MULTILINGUAL RULES:\n"
          "1. Analyze the language of the user's latest query (Hindi, Marathi, or English).\n"
          "2. Respond in THAT SAME LANGUAGE. If the user typed or spoke in Hindi, reply in Hindi. If in Marathi, reply in Marathi. If in English, reply in English.\n"
          "3. Keep your response concise, clear, and direct (2-3 short sentences max).\n"
          "4. Do NOT use markdown code blocks or JSON, reply in plain natural conversational text.";

      final response = await SupabaseService.instance.invokeGroqProxy({
        'model': 'openai/gpt-oss-120b',
        'messages': [
          {"role": "system", "content": systemPrompt},
          ...conversationPayload,
        ],
        'temperature': 0.5,
        'max_tokens': 300,
      });

      final replyContent = response['choices'][0]['message']['content'] as String;

      if (mounted) {
        setState(() {
          _messages.add({"role": "assistant", "content": replyContent.trim()});
        });
        _scrollToBottom();
        _speakReply(replyContent.trim());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            "role": "assistant",
            "content": "I'm having trouble connecting right now. Please try asking again in a moment!"
          });
        });
        _scrollToBottom();
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _speakReply(String replyText) async {
    try {
      await TtsService.instance.stop();

      // Language Auto-Detection Query via Groq or Locale matcher
      String detectedLang = 'en-US';
      try {
        final langDetectPrompt =
            "Identify the language of this text snippet: '$replyText'. "
            "Respond strictly with ONE word: Hindi, Marathi, or English.";

        final langRes = await SupabaseService.instance.invokeGroqProxy({
          'model': 'openai/gpt-oss-120b',
          'messages': [
            {"role": "system", "content": langDetectPrompt}
          ],
          'temperature': 0.1,
          'max_tokens': 10,
        });
        final langName = (langRes['choices'][0]['message']['content'] as String).toLowerCase();
        if (langName.contains('hindi')) {
          detectedLang = 'hi-IN';
        } else if (langName.contains('marathi')) {
          detectedLang = 'mr-IN';
        } else {
          detectedLang = 'en-US';
        }
      } catch (_) {}

      setState(() => _isSpeakingTts = true);

      TtsService.instance.setCompletionHandler(() {
        if (mounted) setState(() => _isSpeakingTts = false);
      });

      await TtsService.instance.speak(
        replyText,
        language: detectedLang,
      );
    } catch (e) {
      debugPrint("Notice speaking floating assistant reply: $e");
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppTheme.hairline, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const CoachAvatar(size: 38),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "AI Doubt Assistant",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Ask anything mid-session in EN/HI/MR",
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (_isSpeakingTts)
                  IconButton(
                    icon: const Icon(Icons.volume_up_rounded, color: AppTheme.primary),
                    onPressed: () {
                      _tts.stop();
                      setState(() => _isSpeakingTts = false);
                    },
                    tooltip: "Stop Audio",
                  ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Language Selector Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: AppTheme.surfaceContainer.withOpacity(0.5),
            child: Row(
              children: [
                const Text(
                  "STT Language:",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
                const SizedBox(width: 10),
                _buildLangChip("English", "en-US"),
                const SizedBox(width: 6),
                _buildLangChip("Hindi (हिंदी)", "hi-IN"),
                const SizedBox(width: 6),
                _buildLangChip("Marathi (मराठी)", "mr-IN"),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.hairline),

          // Chat Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg["role"] == "user";

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? AppTheme.primary : AppTheme.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                      border: isUser ? null : Border.all(color: AppTheme.hairline),
                    ),
                    child: Text(
                      msg["content"] ?? "",
                      style: TextStyle(
                        fontSize: 14,
                        color: isUser ? Colors.black : AppTheme.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isSending)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
                  SizedBox(width: 10),
                  Text("AI is answering doubt...", style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),

          // Input Controller Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.hairline)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _toggleListening,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: _isListening ? Colors.red : AppTheme.primary.withOpacity(0.15),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none_rounded,
                        color: _isListening ? Colors.white : AppTheme.primary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: "Ask doubt (English, Hindi, Marathi)...",
                        hintStyle: TextStyle(fontSize: 13, color: AppTheme.textSecondary.withOpacity(0.7)),
                        filled: true,
                        fillColor: AppTheme.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppTheme.primary),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLangChip(String label, String code) {
    final isSelected = _selectedSttLocale == code;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSttLocale = code;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.hairline),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.black : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
