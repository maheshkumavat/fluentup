import 'package:flutter/material.dart';
import '../services/mlkit_service.dart';
import '../theme.dart';

class PresentationReportScreen extends StatelessWidget {
  final Map<String, dynamic> speechReport;
  final PresentationMetrics metrics;
  final List<Map<String, String>> visualTimelineNotes;
  final String topicTitle;

  const PresentationReportScreen({
    super.key,
    required this.speechReport,
    required this.metrics,
    required this.visualTimelineNotes,
    required this.topicTitle,
  });

  @override
  Widget build(BuildContext context) {
    final overall = (speechReport['overall_score'] as num? ?? 7.5).toDouble();
    final pronunciation = (speechReport['pronunciation_confidence'] as num? ?? 7).toInt();
    final fluency = (speechReport['fluency'] as num? ?? 7).toInt();
    final grammar = (speechReport['grammar'] as num? ?? 8).toInt();
    final vocabulary = (speechReport['vocabulary'] as num? ?? 7).toInt();
    final fillerCount = (speechReport['filler_word_count'] as num? ?? 0).toInt();

    final facingCam = metrics.facingCameraPercentage.toStringAsFixed(0);
    final eyeContact = metrics.eyeContactPercentage.toStringAsFixed(0);
    final smiling = metrics.smilingPercentage.toStringAsFixed(0);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Presentation Report"),
        automaticallyImplyLeading: false,
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

              // Header Overall Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                ),
                child: Column(
                  children: [
                    Text(
                      topicTitle,
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
                          overall.toStringAsFixed(1),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
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
                      "PRESENTATION DELIVERY SCORE",
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

              // On-Device Camera Signals Summary
              const Text(
                "ON-DEVICE CAMERA & EYE CONTACT SIGNALS",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard("Facing Camera", "$facingCam%"),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard("Eye Contact", "$eyeContact%"),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard("Smiling / Warmth", "$smiling%"),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(height: 1, color: AppTheme.hairline),

              // Sampled Groq Vision Notes Timeline
              const SizedBox(height: 24),
              const Text(
                "VISUAL DELIVERY TIMELINE (SAMPLED MOMENTS)",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: AppTheme.secondaryAccent,
                ),
              ),
              const SizedBox(height: 12),
              if (visualTimelineNotes.isEmpty)
                const Text(
                  "No visual frame notes available.",
                  style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textSecondary),
                )
              else
                ...visualTimelineNotes.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.hairline),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item['time'] ?? '0:00',
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.secondaryAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item['note'] ?? '',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: AppTheme.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 24),
              const Divider(height: 1, color: AppTheme.hairline),

              // Speech Scores Section
              const SizedBox(height: 24),
              const Text(
                "SPEECH & FLUENCY SCORES",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              _buildScoreBar("Pronunciation Confidence", pronunciation),
              const SizedBox(height: 10),
              _buildScoreBar("Fluency", fluency),
              const SizedBox(height: 10),
              _buildScoreBar("Grammar Structure", grammar),
              const SizedBox(height: 10),
              _buildScoreBar("Vocabulary Range", vocabulary),
              const SizedBox(height: 16),
              Text(
                "Filler words used: $fillerCount",
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),

              // Honest Privacy Disclaimer Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppTheme.primary, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Based on sampled moments during your presentation. Image frames are processed in temporary memory and never stored.",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Done Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Done & Back to Home"),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBar(String label, int score) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textPrimary)),
            Text("$score / 10", style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: score / 10.0,
            minHeight: 6,
            backgroundColor: AppTheme.hairline,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
          ),
        ),
      ],
    );
  }
}
