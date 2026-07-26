import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/chat_provider.dart';
import '../providers/progress_provider.dart';
import '../theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChatProvider>(context, listen: false).loadMessages();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _speech.stop();
    _flutterTts.stop();
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

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
    progressProvider.addXP(10);
    int beforeLen = chatProvider.messages.length;

    await chatProvider.sendMessage(text);

    if (mounted) {
      int afterLen = chatProvider.messages.length;
      if (afterLen > beforeLen) {
        final lastMsg = chatProvider.messages.last;
        if (lastMsg['sender'] == 'ai' && chatProvider.autoReadReplies) {
          _speak(lastMsg['text'] as String);
        }
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
            title: const Text(
              "Microphone Permission Required",
              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            content: const Text(
              "FluentUp needs microphone access so you can speak your answers and practice your English pronunciation.",
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("Cancel", style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final reqStatus = await Permission.microphone.request();
                  if (reqStatus.isGranted) {
                    _toggleListening();
                  }
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
            title: const Text(
              "Microphone Permission Disabled",
              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            content: const Text(
              "Microphone permission was permanently denied. Please enable it in system settings to use voice input.",
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("Cancel", style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  openAppSettings();
                },
                child: const Text("Settings"),
              ),
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
            if (mounted) {
              setState(() => _isListening = false);
            }
          }
        },
        onError: (errorNotification) {
          if (mounted) {
            setState(() => _isListening = false);
          }
        },
      );

      if (available) {
        if (mounted) {
          setState(() => _isListening = true);
        }
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
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Speech recognition not available on this device")),
          );
        }
      }
    }
  }

  Future<void> _speak(String text) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final rate = chatProvider.speakingSpeed == 'slow' ? 0.3 : 0.5;

    await _flutterTts.stop();
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(rate);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    String speakText = text;
    if (text.contains('[Correction:]')) {
      int index = text.indexOf('[Correction:]');
      speakText = text.substring(0, index).trim();
    }

    await _flutterTts.speak(speakText);
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.language, color: AppTheme.primary, size: 24),
            SizedBox(width: 8),
            Text(
              "FluentUp",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.textSecondary),
            onPressed: () {
              chatProvider.resetConversation();
            },
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
            if (chatProvider.errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: AppTheme.error.withOpacity(0.1),
                child: Text(
                  chatProvider.errorMessage!,
                  style: const TextStyle(color: AppTheme.error, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),

            Expanded(
              child: chatProvider.messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppTheme.containerPadding),
                      itemCount: chatProvider.messages.length + (chatProvider.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Column(
                            children: [
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceContainer,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Text(
                                    "Today",
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              if (index < chatProvider.messages.length)
                                _buildMessageItem(chatProvider.messages[index]),
                            ],
                          );
                        }
                        if (index == chatProvider.messages.length) {
                          return const _TypingIndicator();
                        }
                        return _buildMessageItem(chatProvider.messages[index]);
                      },
                    ),
            ),

            // Floating Input Area
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
                                hintText: "Type your response...",
                                hintStyle: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  color: AppTheme.textSecondary,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          GestureDetector(
                            onTap: _sendMessage,
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.containerPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 40,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Start Practicing",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Say 'Hello' or ask a question in English to begin your session.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> msg) {
    final isUser = msg['sender'] == 'user';
    final text = msg['text'] as String;

    String mainText = text;
    String? correctionText;

    if (!isUser) {
      if (text.contains('[Correction:]')) {
        int index = text.indexOf('[Correction:]');
        mainText = text.substring(0, index).trim();
        correctionText = text.substring(index).replaceAll('[Correction:]', '').trim();
      } else if (text.contains('💡 Correction:')) {
        int index = text.indexOf('💡 Correction:');
        mainText = text.substring(0, index).trim();
        correctionText = text.substring(index).replaceAll('💡 Correction:', '').trim();
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
                  "Tutor",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "10:02 AM",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ] else ...[
                const Text(
                  "10:03 AM",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Quick Tip",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          correctionText,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _speak(text),
                    child: const Icon(
                      Icons.volume_up_outlined,
                      color: AppTheme.textSecondary,
                      size: 18,
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
            "Tutor is formulating response...",
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
