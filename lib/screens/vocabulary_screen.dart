import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/vocabulary_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/progress_provider.dart';
import '../theme.dart';

class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({super.key});

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen> {
  final TextEditingController _sentenceController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  int _tabIndex = 0; // 0: Daily Deck, 1: Saved Favorites

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<VocabularyProvider>(context, listen: false).initVocabulary();
    });
  }

  @override
  void dispose() {
    _sentenceController.dispose();
    _speech.stop();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _checkPermissionAndToggleListening() async {
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      status = await Permission.microphone.request();
      if (!status.isGranted) return;
    }

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
        onError: (e) {
          if (mounted) setState(() => _isListening = false);
        },
      );

      if (available) {
        setState(() => _isListening = true);
        await _speech.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _sentenceController.text = result.recognizedWords;
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
    final rate = chatProvider.speakingSpeed == 'slow' ? 0.3 : 0.5;

    await _flutterTts.stop();
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(rate);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(text);
  }

  void _checkSentence(VocabularyProvider provider) async {
    final text = _sentenceController.text.trim();
    if (text.isEmpty) return;

    FocusScope.of(context).unfocus();
    await provider.evaluateUserSentence(text);
    if (mounted) {
      Provider.of<ProgressProvider>(context, listen: false).addXP(15);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vocabProvider = Provider.of<VocabularyProvider>(context);
    final wordMap = vocabProvider.currentWord;
    final isSaved = (wordMap?['is_saved'] as int? ?? 0) == 1;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.language, color: AppTheme.primary, size: 24),
            SizedBox(width: 8),
            Text(
              "Vocabulary",
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
            icon: const Icon(Icons.refresh, color: AppTheme.primary),
            tooltip: "Fetch Fresh Word",
            onPressed: () {
              _sentenceController.clear();
              vocabProvider.fetchFreshWord();
            },
          ),
          IconButton(
            icon: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: isSaved ? AppTheme.secondaryAccent : AppTheme.textSecondary,
            ),
            tooltip: "Save Word",
            onPressed: () {
              vocabProvider.toggleSaveCurrentWord();
            },
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
              const SizedBox(height: 16),

              // PHASE H: SITUATION-GROUPED VOCABULARY SELECTION
              const Text(
                "SITUATION CATEGORY",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSituationChip("All Topics", true),
                    const SizedBox(width: 8),
                    _buildSituationChip("🍽️ Restaurant & Cafe", false),
                    const SizedBox(width: 8),
                    _buildSituationChip("💼 Job Interview", false),
                    const SizedBox(width: 8),
                    _buildSituationChip("💻 Tech & Coding", false),
                    const SizedBox(width: 8),
                    _buildSituationChip("✈️ Travel & Hotel", false),
                    const SizedBox(width: 8),
                    _buildSituationChip("📈 Office & Business", false),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Weekly Progress Indicator Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      "${vocabProvider.wordsLearnedThisWeek} words learned this week",
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Filter Tabs (Learn New Words vs Saved Favorites)
              Row(
                children: [
                  ChoiceChip(
                    label: const Text("Learn New Words"),
                    selected: _tabIndex == 0,
                    onSelected: (_) => setState(() => _tabIndex = 0),
                    selectedColor: AppTheme.primary,
                    backgroundColor: AppTheme.surfaceContainer,
                    labelStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _tabIndex == 0 ? Colors.white : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text("Saved Favorites (${vocabProvider.savedWords.length})"),
                    selected: _tabIndex == 1,
                    onSelected: (_) => setState(() => _tabIndex = 1),
                    selectedColor: AppTheme.primary,
                    backgroundColor: AppTheme.surfaceContainer,
                    labelStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _tabIndex == 1 ? Colors.white : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, end: 0),
              const SizedBox(height: 20),

              if (_tabIndex == 1) ...[
                // Saved Favorites Tab Content
                if (vocabProvider.savedWords.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48.0),
                      child: Text(
                        "No saved words yet. Tap the bookmark icon on any word card to save it!",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppTheme.textSecondary),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: vocabProvider.savedWords.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = vocabProvider.savedWords[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.hairline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item['word'] as String? ?? '',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.volume_up, color: AppTheme.primary, size: 20),
                                  onPressed: () => _speak(item['word'] as String? ?? ''),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['meaning'] as String? ?? '',
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppTheme.textSecondary),
                            ),
                            if ((item['example_sentence'] as String? ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                "\"${item['example_sentence']}\"",
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontStyle: FontStyle.italic, color: AppTheme.textPrimary),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
              ] else ...[
                // Learn New Words Card Section
                if (vocabProvider.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48.0),
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    ),
                  )
                else if (wordMap == null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48.0),
                      child: Column(
                        children: [
                          const Text(
                            "No word available right now.",
                            style: TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => vocabProvider.fetchFreshWord(),
                            child: const Text("Fetch Word"),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, animation) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.05, 0.0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: Container(
                      key: ValueKey(wordMap['word'] as String? ?? 'card'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.hairline, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Pills Row
                          Row(
                            children: [
                              if ((wordMap['part_of_speech'] as String? ?? '').isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    (wordMap['part_of_speech'] as String).toLowerCase(),
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              if ((wordMap['synonym'] as String? ?? '').isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "Synonym: ${wordMap['synonym']}",
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              const Spacer(),
                              IconButton(
                                icon: Icon(
                                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                                  color: isSaved ? AppTheme.secondaryAccent : AppTheme.textSecondary,
                                ),
                                onPressed: () => vocabProvider.toggleSaveCurrentWord(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Word & TTS Icon Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  wordMap['word'] as String? ?? '',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              IconButton.filledTonal(
                                icon: const Icon(Icons.volume_up, color: AppTheme.primary),
                                tooltip: "Hear pronunciation",
                                onPressed: () => _speak(wordMap['word'] as String? ?? ''),
                              ),
                            ],
                          ),

                          // Pronunciation Guide
                          if ((wordMap['pronunciation_guide'] as String? ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              "Pronunciation: ${wordMap['pronunciation_guide']}",
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),
                          const Divider(height: 1, color: AppTheme.hairline),
                          const SizedBox(height: 16),

                          // Meaning
                          const Text(
                            "MEANING",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            wordMap['meaning'] as String? ?? '',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Example Sentence
                          const Text(
                            "EXAMPLE SENTENCE",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "\"${wordMap['example_sentence'] as String? ?? ''}\"",
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: AppTheme.textPrimary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Where You'd Use This (Real-life Context Field)
                          if ((wordMap['usage_context'] as String? ?? '').isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.lightbulb_outline, color: AppTheme.primary, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "WHERE YOU'D USE THIS",
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.8,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          wordMap['usage_context'] as String,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 13,
                                            color: AppTheme.textPrimary,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Next Word Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _sentenceController.clear();
                                vocabProvider.fetchFreshWord();
                              },
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text("Next Word", style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sentence Practice Section
                  const Divider(height: 1, color: AppTheme.hairline),
                  const SizedBox(height: 24),
                  const Text(
                    "PRACTICE IN YOUR OWN SENTENCE",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _sentenceController,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            hintText: "Use this word in a sentence...",
                            hintStyle: TextStyle(color: AppTheme.textSecondary),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: AppTheme.hairline),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: AppTheme.primary, width: 2),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? AppTheme.secondaryAccent : AppTheme.primary,
                        ),
                        onPressed: _checkPermissionAndToggleListening,
                      ),
                      ElevatedButton(
                        onPressed: () => _checkSentence(vocabProvider),
                        child: const Text("Check"),
                      ),
                    ],
                  ),

                  if (vocabProvider.isSentenceChecking) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                  ] else if (vocabProvider.sentenceCheckResult != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (vocabProvider.sentenceCheckResult!['correct'] as bool? ?? false)
                              ? AppTheme.primary
                              : AppTheme.secondaryAccent,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                (vocabProvider.sentenceCheckResult!['correct'] as bool? ?? false)
                                    ? Icons.check_circle
                                    : Icons.info,
                                color: (vocabProvider.sentenceCheckResult!['correct'] as bool? ?? false)
                                    ? AppTheme.primary
                                    : AppTheme.secondaryAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                (vocabProvider.sentenceCheckResult!['correct'] as bool? ?? false)
                                    ? "Correct Usage!"
                                    : "Needs Revision",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: (vocabProvider.sentenceCheckResult!['correct'] as bool? ?? false)
                                      ? AppTheme.primary
                                      : AppTheme.secondaryAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            vocabProvider.sentenceCheckResult!['feedback'] as String? ?? '',
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppTheme.textPrimary, height: 1.4),
                          ),
                        ],
                      ),
                    ),

                    if (vocabProvider.additionalExamples.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text(
                        "VARIED EXAMPLES (CASUAL / PROF / ACADEMIC)",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...vocabProvider.additionalExamples.map((ex) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.arrow_right, color: AppTheme.primary, size: 20),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    "\"$ex\"",
                                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textPrimary, height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ],
                  const SizedBox(height: 32),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSituationChip(String label, bool isSelected) {
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : AppTheme.textPrimary,
        ),
      ),
      backgroundColor: AppTheme.surfaceContainer,
      selectedColor: AppTheme.primary,
      checkmarkColor: Colors.white,
      side: const BorderSide(color: AppTheme.hairline),
      onSelected: (val) {
        final vocabProvider = Provider.of<VocabularyProvider>(context, listen: false);
        vocabProvider.fetchFreshWord();
      },
    );
  }
}
