import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/code_explanation_provider.dart';
import '../providers/chat_provider.dart';
import '../theme.dart';

class ExplainCodeScreen extends StatefulWidget {
  const ExplainCodeScreen({super.key});

  @override
  State<ExplainCodeScreen> createState() => _ExplainCodeScreenState();
}

class _ExplainCodeScreenState extends State<ExplainCodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _explanationController = TextEditingController();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  final FlutterTts _flutterTts = FlutterTts();

  final List<Map<String, String>> _samplePresets = [
    {
      "label": "Greeting",
      "code": "function greeting(name) {\n  return `Hello, \${name}!`;\n}\n\nconsole.log(greeting('World'));",
    },
    {
      "label": "Reverse String",
      "code": "String reverse(String str) {\n  return str.split('').reversed.join('');\n}",
    },
    {
      "label": "Binary Search",
      "code": "int binarySearch(List<int> arr, int target) {\n  int low = 0, high = arr.length - 1;\n  while (low <= high) {\n    int mid = low + (high - low) ~/ 2;\n    if (arr[mid] == target) return mid;\n  }\n  return -1;\n}",
    },
  ];

  @override
  void initState() {
    super.initState();
    _codeController.text = _samplePresets[0]["code"]!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CodeExplanationProvider>(context, listen: false).loadPastExplanations();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _explanationController.dispose();
    _speech.stop();
    _flutterTts.stop();
    super.dispose();
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
                _explanationController.text = result.recognizedWords;
              });
            }
          },
          listenOptions: stt.SpeechListenOptions(
            listenFor: const Duration(seconds: 45),
            pauseFor: const Duration(seconds: 3),
          ),
        );
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
    await _flutterTts.speak(text);
  }

  void _submitEvaluation(CodeExplanationProvider provider) async {
    final code = _codeController.text.trim();
    final explanation = _explanationController.text.trim();

    if (code.isEmpty || explanation.isEmpty) return;

    FocusScope.of(context).unfocus();
    await provider.evaluateExplanation(code, explanation);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CodeExplanationProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Icon(Icons.settings_outlined, color: AppTheme.textSecondary),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.hairline),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.containerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Title Section
              const Text(
                "Code Explainer",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Paste your snippet and record your explanation to receive a linguistic breakdown.",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Preset Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _samplePresets.map((preset) {
                    final isSelected = _codeController.text == preset["code"];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(preset["label"]!),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _codeController.text = preset["code"]!;
                          });
                        },
                        selectedColor: AppTheme.primary,
                        backgroundColor: AppTheme.surfaceContainer,
                        labelStyle: TextStyle(
                          fontFamily: 'Inter',
                          color: isSelected ? Colors.white : AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Code Editor Box
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.hairline),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Line numbers bar
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      decoration: const BoxDecoration(
                        border: Border(right: BorderSide(color: AppTheme.hairline)),
                      ),
                      child: Column(
                        children: List.generate(6, (index) => Text(
                          "${index + 1}",
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 14,
                            color: AppTheme.primary.withOpacity(0.6),
                          ),
                        )),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _codeController,
                        maxLines: 6,
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: "// Paste your code here...",
                          hintStyle: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Recording Control Area
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _checkPermissionAndToggleListening,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening ? AppTheme.primary : AppTheme.background,
                          border: Border.all(color: AppTheme.primary, width: 2),
                        ),
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.white : AppTheme.primary,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isListening ? "Recording..." : "Tap to Record Question",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        color: _isListening ? AppTheme.primary : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Explanation Input Field
              TextField(
                controller: _explanationController,
                maxLines: 3,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: "Your spoken or typed explanation in English...",
                  hintStyle: TextStyle(color: AppTheme.textSecondary),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.hairline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: provider.isLoading ? null : () => _submitEvaluation(provider),
                  child: provider.isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("Analyze Explanation"),
                ),
              ),
              const SizedBox(height: 32),

              // Evaluation Feedback Breakdown
              if (provider.feedbackResult != null) ...[
                const Divider(height: 1, color: AppTheme.hairline),
                const SizedBox(height: 24),
                const Text(
                  "FEEDBACK & BREAKDOWN",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  provider.feedbackResult!,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
