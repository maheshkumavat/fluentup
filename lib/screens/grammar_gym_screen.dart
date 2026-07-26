import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../theme.dart';
import '../providers/gym_provider.dart';
import '../widgets/tactile_button.dart';

class GrammarGymScreen extends StatefulWidget {
  const GrammarGymScreen({super.key});

  @override
  State<GrammarGymScreen> createState() => _GrammarGymScreenState();
}

class _GrammarGymScreenState extends State<GrammarGymScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isSpeechAvailable = false;
  bool _isListening = false;
  String _spokenText = "";
  final TextEditingController _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gymProvider = Provider.of<GymProvider>(context, listen: false);
      if (!gymProvider.isCurriculumLoaded) {
        gymProvider.initCurriculum();
      }
    });
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
        onError: (errorNotification) {
          if (mounted) setState(() => _isListening = false);
        },
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _answerController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _openUnitDetail(BuildContext context, CurriculumUnit unit, GymProvider gymProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UnitModalSheet(
        unit: unit,
        gymProvider: gymProvider,
        speech: _speech,
        isSpeechAvailable: _isSpeechAvailable,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gymProvider = Provider.of<GymProvider>(context);

    // Check for Level Up Celebration
    if (gymProvider.unlockedCelebrationLevel != null) {
      final levelUnlocked = gymProvider.unlockedCelebrationLevel!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLevelUpDialog(context, levelUnlocked, gymProvider);
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Grammar Learning Path"),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary),
            onPressed: () => gymProvider.initCurriculum(),
            tooltip: "Reload Curriculum",
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.hairline),
        ),
      ),
      body: !gymProvider.isCurriculumLoaded
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overall Progress Header Card
                  _buildHeaderCard(gymProvider),
                  const SizedBox(height: 20),

                  // Adaptive Review Banner if needed
                  if (gymProvider.adaptiveReviewUnit != null) ...[
                    _buildAdaptiveReviewCard(context, gymProvider),
                    const SizedBox(height: 20),
                  ],

                  const Text(
                    "CEFR CURRICULUM ROADMAP",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CEFR Level Sections
                  ...gymProvider.levels.map((level) {
                    final units = gymProvider.getUnitsForLevel(level);
                    final isCurrentLevel = gymProvider.currentCefrLevel == level;

                    return _buildLevelSection(context, level, units, isCurrentLevel, gymProvider);
                  }),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard(GymProvider gymProvider) {
    final percentage = (gymProvider.overallProgressPercentage * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.hairline),
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(0.12),
            AppTheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Grammar Master",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "CEFR Level ${gymProvider.currentCefrLevel} • $percentage% Mastered",
                    style: const TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                ),
                child: Text(
                  gymProvider.currentCefrLevel,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: gymProvider.overallProgressPercentage,
              minHeight: 10,
              backgroundColor: AppTheme.hairline,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdaptiveReviewCard(BuildContext context, GymProvider gymProvider) {
    final unit = gymProvider.adaptiveReviewUnit!;
    final score = gymProvider.getUnitScore(unit.id);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: Colors.amber, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Adaptive Skill Refresher",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber),
                ),
                const SizedBox(height: 2),
                Text(
                  "'${unit.title}' (Current score: $score%)",
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () {
              gymProvider.clearAdaptiveReviewPrompt();
              _openUnitDetail(context, unit, gymProvider);
            },
            child: const Text("Refresh", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelSection(
    BuildContext context,
    String level,
    List<CurriculumUnit> units,
    bool isCurrentLevel,
    GymProvider gymProvider,
  ) {
    final levelNames = {
      'A1': 'A1 • Beginner Basics',
      'A2': 'A2 • Elementary Foundations',
      'B1': 'B1 • Intermediate Skills',
      'B2': 'B2 • Upper-Intermediate Fluency',
      'C1': 'C1 • Advanced Mastery',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isCurrentLevel ? AppTheme.primary.withOpacity(0.15) : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isCurrentLevel ? AppTheme.primary : AppTheme.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCurrentLevel ? Icons.stars : Icons.military_tech_outlined,
                color: isCurrentLevel ? AppTheme.primary : AppTheme.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                levelNames[level] ?? level,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isCurrentLevel ? AppTheme.primary : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Vertical Unit Roadmap Nodes
        ...units.asMap().entries.map((entry) {
          final index = entry.key;
          final unit = entry.value;
          final isUnlocked = gymProvider.isUnitUnlocked(unit);
          final isMastered = gymProvider.isUnitMastered(unit.id);
          final score = gymProvider.getUnitScore(unit.id);
          final isLast = index == units.length - 1;

          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Node Circle Status Icon
                  TactileButton(
                    onTap: isUnlocked ? () => _openUnitDetail(context, unit, gymProvider) : null,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isMastered
                            ? Colors.green.withOpacity(0.2)
                            : isUnlocked
                                ? AppTheme.primary.withOpacity(0.2)
                                : AppTheme.surface,
                        border: Border.all(
                          color: isMastered
                              ? Colors.green
                              : isUnlocked
                                  ? AppTheme.primary
                                  : AppTheme.hairline,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          isMastered
                              ? Icons.check_circle
                              : isUnlocked
                                  ? Icons.play_arrow_rounded
                                  : Icons.lock_outline,
                          color: isMastered
                              ? Colors.green
                              : isUnlocked
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Unit Title & Subtitle Card
                  Expanded(
                    child: InkWell(
                      onTap: isUnlocked ? () => _openUnitDetail(context, unit, gymProvider) : null,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isUnlocked ? AppTheme.primary.withOpacity(0.3) : AppTheme.hairline,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    unit.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isUnlocked ? AppTheme.textPrimary : AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    unit.explanation,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            if (isMastered) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "$score%",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ] else if (isUnlocked && score > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "$score%",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (!isLast)
                Container(
                  margin: const EdgeInsets.only(left: 23, top: 4, bottom: 4),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 2,
                    height: 24,
                    color: isMastered ? Colors.green.withOpacity(0.5) : AppTheme.hairline,
                  ),
                ),
            ],
          );
        }),
        const SizedBox(height: 28),
      ],
    );
  }

  void _showLevelUpDialog(BuildContext context, String unlockedLevel, GymProvider gymProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
            const SizedBox(height: 16),
            const Text(
              "LEVEL UNLOCKED! 🎉",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              "Outstanding! You have mastered all grammar focus points in your current level. CEFR Level $unlockedLevel is now unlocked!",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                gymProvider.clearLevelCelebration();
                Navigator.of(ctx).pop();
              },
              child: const Text("Continue Learning"),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitModalSheet extends StatefulWidget {
  final CurriculumUnit unit;
  final GymProvider gymProvider;
  final stt.SpeechToText speech;
  final bool isSpeechAvailable;

  const _UnitModalSheet({
    required this.unit,
    required this.gymProvider,
    required this.speech,
    required this.isSpeechAvailable,
  });

  @override
  State<_UnitModalSheet> createState() => _UnitModalSheetState();
}

class _UnitModalSheetState extends State<_UnitModalSheet> {
  int _step = 1; // 1: Overview, 2: Practice Session, 3: Completed Score
  final TextEditingController _typedInputController = TextEditingController();
  bool _isListening = false;
  String _spokenText = "";

  @override
  void dispose() {
    _typedInputController.dispose();
    super.dispose();
  }

  void _toggleListening() async {
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      status = await Permission.microphone.request();
      if (!status.isGranted) return;
    }

    if (_isListening) {
      widget.speech.stop();
      setState(() => _isListening = false);
    } else {
      if (!widget.isSpeechAvailable) return;
      setState(() {
        _isListening = true;
        _spokenText = "";
      });

      widget.speech.listen(
        onResult: (result) {
          setState(() {
            _spokenText = result.recognizedWords;
            _typedInputController.text = _spokenText;
          });
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gymProvider = widget.gymProvider;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
          const SizedBox(height: 16),

          // Header Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${widget.unit.level} • ${widget.unit.title}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Mastery Requirement: 75%+",
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withOpacity(0.8)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.hairline),

          // Body Views depending on Step
          Expanded(
            child: _step == 1
                ? _buildOverviewStep(context)
                : _step == 2
                    ? _buildPracticeStep(context, gymProvider)
                    : _buildCompletedStep(context, gymProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStep(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Explanation Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: AppTheme.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Grammar Rule Explanation",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.unit.explanation,
                  style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Example Correct
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withOpacity(0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.green, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Correct Example:",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "\"${widget.unit.exampleCorrect}\"",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Common Mistake
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withOpacity(0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.highlight_off, color: Colors.red, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Common Mistake to Avoid:",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "\"${widget.unit.exampleCommonMistake}\"",
                        style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Start Practice Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                setState(() => _step = 2);
                widget.gymProvider.startUnitPractice(widget.unit);
              },
              child: const Text("Start 4-Item Practice", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeStep(BuildContext context, GymProvider gymProvider) {
    if (gymProvider.isSessionLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            const SizedBox(height: 16),
            TextStyle(color: AppTheme.textSecondary) == null
                ? const SizedBox()
                : Text("Generating fresh Groq AI exercises...", style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    if (gymProvider.activeItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(gymProvider.sessionErrorMessage ?? "Could not load exercises", style: TextStyle(color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => gymProvider.startUnitPractice(widget.unit),
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    final currentItem = gymProvider.activeItems[gymProvider.currentItemIndex];
    final isSpoken = currentItem.expects == 'spoken';
    final hasAnswered = currentItem.isCorrect != null;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Progress Bar
          Row(
            children: [
              Text(
                "Exercise ${gymProvider.currentItemIndex + 1} of ${gymProvider.activeItems.length}",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
              ),
              const Spacer(),
              if (isSpoken)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.purple.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Icon(Icons.mic, color: Colors.purple, size: 14),
                      SizedBox(width: 4),
                      Text("Spoken Item", style: TextStyle(fontSize: 11, color: Colors.purple, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (gymProvider.currentItemIndex + 1) / gymProvider.activeItems.length,
              minHeight: 6,
              backgroundColor: AppTheme.hairline,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
          const SizedBox(height: 24),

          // Exercise Prompt Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("PRACTICE QUESTION", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 1)),
                const SizedBox(height: 8),
                Text(
                  currentItem.prompt,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // User Input Box or Result Card
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!hasAnswered) ...[
                    TextField(
                      controller: _typedInputController,
                      maxLines: isSpoken ? 3 : 2,
                      decoration: InputDecoration(
                        hintText: isSpoken ? "Speak or type your response..." : "Type your answer here...",
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppTheme.hairline)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isSpoken) ...[
                      Center(
                        child: GestureDetector(
                          onTap: _toggleListening,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isListening ? Colors.red : AppTheme.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: (_isListening ? Colors.red : AppTheme.primary).withOpacity(0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(_isListening ? Icons.stop : Icons.mic, color: Colors.white, size: 32),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          _isListening ? "Listening... Speak now" : "Tap mic to record audio",
                          style: TextStyle(fontSize: 12, color: _isListening ? Colors.red : AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ] else ...[
                    // Evaluated Result Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: currentItem.isCorrect! ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: currentItem.isCorrect! ? Colors.green : Colors.red),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(currentItem.isCorrect! ? Icons.check_circle : Icons.cancel, color: currentItem.isCorrect! ? Colors.green : Colors.red),
                              const SizedBox(width: 8),
                              Text(
                                currentItem.isCorrect! ? "Correct!" : "Needs Improvement",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: currentItem.isCorrect! ? Colors.green : Colors.red),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (!currentItem.isCorrect!) ...[
                            Text("Corrected Form:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                            const SizedBox(height: 4),
                            Text("\"${currentItem.correctedSentence}\"", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                            const SizedBox(height: 8),
                          ],
                          Text("AI Feedback:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Text(currentItem.explanation ?? "", style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Submit or Next Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: gymProvider.isItemSubmitting
                  ? null
                  : !hasAnswered
                      ? () {
                          final answer = _typedInputController.text.trim();
                          if (answer.isNotEmpty) {
                            gymProvider.submitItemAnswer(answer);
                          }
                        }
                      : () {
                          _typedInputController.clear();
                          if (gymProvider.currentItemIndex < gymProvider.activeItems.length - 1) {
                            gymProvider.nextItem();
                          } else {
                            gymProvider.finishSession();
                            setState(() => _step = 3);
                          }
                        },
              child: gymProvider.isItemSubmitting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(!hasAnswered ? "Submit Answer" : (gymProvider.currentItemIndex < gymProvider.activeItems.length - 1 ? "Next Exercise" : "Finish Session"),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedStep(BuildContext context, GymProvider gymProvider) {
    final score = gymProvider.calculatedSessionScore;
    final isMastered = score >= 75;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isMastered ? Icons.emoji_events : Icons.refresh,
            color: isMastered ? Colors.amber : Colors.orange,
            size: 72,
          ),
          const SizedBox(height: 16),
          Text(
            isMastered ? "Unit Mastered! 🎉" : "Keep Practicing! 💪",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            "Mastery Score: $score%",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isMastered ? Colors.green : Colors.orange),
          ),
          const SizedBox(height: 16),
          Text(
            isMastered
                ? "Awesome work! You scored $score% across 4 practice exercises. The next grammar unit has been unlocked!"
                : "You scored $score%. A score of 75%+ is required to master this unit and unlock the next one. Try again to get fresh exercises!",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Return to Learning Path", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
