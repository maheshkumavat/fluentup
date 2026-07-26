import 'package:flutter/material.dart';
import '../theme.dart';

class FeedbackReportScreen extends StatefulWidget {
  final Map<String, dynamic> reportData;
  final String topicTitle;

  const FeedbackReportScreen({
    super.key,
    required this.reportData,
    required this.topicTitle,
  });

  @override
  State<FeedbackReportScreen> createState() => _FeedbackReportScreenState();
}

class _FeedbackReportScreenState extends State<FeedbackReportScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _progressAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.reportData;
    final overall = (report['overall_score'] as num? ?? 7.5).toDouble();
    final pronunciation = (report['pronunciation_confidence'] as num? ?? 7).toInt();
    final fluency = (report['fluency'] as num? ?? 7).toInt();
    final grammar = (report['grammar'] as num? ?? 7).toInt();
    final vocabulary = (report['vocabulary'] as num? ?? 7).toInt();
    final fillerCount = (report['filler_word_count'] as num? ?? 0).toInt();
    final pace = (report['pace_feedback'] as String? ?? 'good');

    final strengthsList = (report['strengths'] as List? ?? [
      "Good overall communicative confidence",
      "Effective structure in answers"
    ]).cast<String>();

    final improvementsList = (report['improvements'] as List? ?? [
      "Reduce filler word pauses",
      "Incorporate more varied industry vocabulary"
    ]).cast<String>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Session Feedback Report"),
        automaticallyImplyLeading: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.hairline),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.containerPadding),
          child: AnimatedBuilder(
            animation: _progressAnim,
            builder: (context, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // Header Badge Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.secondaryAccent.withOpacity(0.4)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.topicTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              (overall * _progressAnim.value).toStringAsFixed(1),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.secondaryAccent,
                              ),
                            ),
                            const Text(
                              " / 10",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "OVERALL PERFORMANCE SCORE",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: AppTheme.hairline),

                  // Score Breakdown Horizontal Bars
                  const SizedBox(height: 24),
                  const Text(
                    "DETAILED FLUENCY SCORES",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAnimatedScoreBar("Pronunciation Confidence", pronunciation, _getStaggeredValue(0.0, 0.7)),
                  const SizedBox(height: 12),
                  _buildAnimatedScoreBar("Fluency", fluency, _getStaggeredValue(0.1, 0.8)),
                  const SizedBox(height: 12),
                  _buildAnimatedScoreBar("Grammar Structure", grammar, _getStaggeredValue(0.2, 0.9)),
                  const SizedBox(height: 12),
                  _buildAnimatedScoreBar("Vocabulary Range", vocabulary, _getStaggeredValue(0.3, 1.0)),
                  const SizedBox(height: 24),

                  // Speech Dynamics Row (Filler Words & Pace)
                  const Divider(height: 1, color: AppTheme.hairline),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.hairline),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "FILLER WORDS",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "$fillerCount words",
                                style: const TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.hairline),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "SPEECH PACE",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pace.toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: AppTheme.hairline),

                  // Strengths Section
                  const SizedBox(height: 24),
                  const Text(
                    "STRENGTHS",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...strengthsList.map((str) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle, color: AppTheme.primary, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                str,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),

                  // Improvements Section
                  const Text(
                    "AREAS TO IMPROVE",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: AppTheme.secondaryAccent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...improvementsList.map((imp) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, color: AppTheme.secondaryAccent, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                imp,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 32),

                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text("Done & Back to Home"),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  double _getStaggeredValue(double start, double end) {
    final v = (_progressAnim.value - start) / (end - start);
    return v.clamp(0.0, 1.0);
  }

  Widget _buildAnimatedScoreBar(String label, int score, double animFactor) {
    final ratio = (score / 10.0) * animFactor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              "$score / 10",
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondaryAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 6,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.hairline,
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: ratio.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.secondaryAccent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
