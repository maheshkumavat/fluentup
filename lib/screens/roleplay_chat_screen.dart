import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../providers/roleplay_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/progress_provider.dart';
import '../services/tts_service.dart';
import 'roleplay_report_screen.dart';
import '../theme.dart';

class RoleplayChatScreen extends StatefulWidget {
  const RoleplayChatScreen({super.key});

  @override
  State<RoleplayChatScreen> createState() => _RoleplayChatScreenState();
}

class _RoleplayChatScreenState extends State<RoleplayChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _speech.stop();
    TtsService.instance.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendRoleplayMessage(RoleplayProvider roleplayProvider) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    int beforeLen = roleplayProvider.messages.length;

    await roleplayProvider.sendRoleplayMessage(text);

    if (mounted) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      int afterLen = roleplayProvider.messages.length;
      if (afterLen > beforeLen) {
        final lastMsg = roleplayProvider.messages.last;
        if (lastMsg['sender'] == 'ai' && chatProvider.autoReadReplies) {
          _speak(lastMsg['text'] as String);
        }
      }

      if (roleplayProvider.isCompleted) {
        _finishSession(roleplayProvider);
      }
    }
  }

  Future<void> _checkPermissionAndToggleListening() async {
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.background,
            title: const Text("Microphone Required", style: TextStyle(color: AppTheme.textPrimary)),
            content: const Text("FluentUp needs microphone access for voice input.", style: TextStyle(color: AppTheme.textSecondary)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel", style: TextStyle(color: AppTheme.textSecondary))),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final reqStatus = await Permission.microphone.request();
                  if (reqStatus.isGranted) _toggleListening();
                },
                child: const Text("Allow"),
              ),
            ],
          ),
        );
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.background,
            title: const Text("Microphone Disabled", style: TextStyle(color: AppTheme.textPrimary)),
            content: const Text("Microphone permission was permanently denied.", style: TextStyle(color: AppTheme.textSecondary)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel", style: TextStyle(color: AppTheme.textSecondary))),
              ElevatedButton(onPressed: () { Navigator.of(ctx).pop(); openAppSettings(); }, child: const Text("Settings")),
            ],
          ),
        );
      }
    } else {
      _toggleListening();
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (errorNotification) {
          if (mounted) setState(() => _isListening = false);
        },
      );

      if (available) {
        if (mounted) setState(() => _isListening = true);
        await _speech.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _messageController.text = result.recognizedWords;
              });
            }
          },
          listenOptions: stt.SpeechListenOptions(
            listenFor: const Duration(seconds: 30),
            pauseFor: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _speak(String text) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final isSlow = chatProvider.speakingSpeed == 'slow';

    String speakText = text;
    if (text.contains('[Correction:]')) {
      int index = text.indexOf('[Correction:]');
      speakText = text.substring(0, index).trim();
    }

    await TtsService.instance.stop();
    await TtsService.instance.speak(
      speakText,
      rate: isSlow ? "-15%" : "+0%",
    );
  }

  void _finishSession(RoleplayProvider roleplayProvider) async {
    await roleplayProvider.finishAndSaveSession();
    if (mounted) {
      Provider.of<ProgressProvider>(context, listen: false).addXP(30);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const RoleplayReportScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleplayProvider = Provider.of<RoleplayProvider>(context);
    final scenario = roleplayProvider.selectedScenario;

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              scenario != null ? scenario['title'] as String : "Roleplay",
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const Text(
              "Scenario Conversation",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _finishSession(roleplayProvider),
            child: const Text(
              "End Session",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.hairline),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (roleplayProvider.errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: AppTheme.error.withOpacity(0.1),
                child: Text(
                  roleplayProvider.errorMessage!,
                  style: const TextStyle(color: AppTheme.error, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),

            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppTheme.containerPadding),
                itemCount: roleplayProvider.messages.length + (roleplayProvider.isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == roleplayProvider.messages.length) {
                    return const _TypingIndicator();
                  }
                  final msg = roleplayProvider.messages[index];
                  final isUser = msg['sender'] == 'user';
                  return _buildMessageBubble(msg['text'] as String, isUser);
                },
              ),
            ),

            // Input Bar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.containerPadding,
                vertical: 12,
              ),
              decoration: const BoxDecoration(
                color: AppTheme.background,
                border: Border(top: BorderSide(color: AppTheme.hairline)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: AppTheme.hairline),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _checkPermissionAndToggleListening,
                            child: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: _isListening ? AppTheme.error : AppTheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                color: AppTheme.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                hintText: "Respond in character...",
                                hintStyle: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  color: AppTheme.textSecondary,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onSubmitted: (_) => _sendRoleplayMessage(roleplayProvider),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _sendRoleplayMessage(roleplayProvider),
                            child: const Icon(
                              Icons.send,
                              color: AppTheme.primary,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    String mainText = text;
    String? correctionText;

    if (!isUser) {
      if (text.contains('[Correction:]')) {
        int index = text.indexOf('[Correction:]');
        mainText = text.substring(0, index).trim();
        correctionText = text.substring(index).replaceAll('[Correction:]', '').trim();
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                const Text(
                  "Partner",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ] else ...[
                const Text(
                  "You",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            decoration: isUser
                ? null
                : const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: AppTheme.primary, width: 2),
                    ),
                  ),
            padding: EdgeInsets.only(
              left: isUser ? 0 : 12,
              right: isUser ? 12 : 0,
            ),
            child: Text(
              mainText,
              textAlign: isUser ? TextAlign.right : TextAlign.left,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                height: 1.5,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          if (!isUser && correctionText != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.hairline),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: AppTheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      correctionText,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.only(left: 12),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
          child: const Text(
            "Partner is typing...",
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
