import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/roleplay_provider.dart';
import 'roleplay_chat_screen.dart';
import 'explain_code_screen.dart';
import 'describe_image_screen.dart';
import 'presentation_practice_screen.dart';
import '../theme.dart';
import '../widgets/tactile_button.dart';

class RoleplayScreen extends StatelessWidget {
  const RoleplayScreen({super.key});

  IconData _getScenarioIcon(String id) {
    switch (id) {
      case 'interview':
        return Icons.work_outline;
      case 'coffee':
        return Icons.people_outline;
      case 'code':
        return Icons.code;
      case 'food':
        return Icons.restaurant_outlined;
      case 'talk':
        return Icons.chat_bubble_outline;
      case 'pitch':
        return Icons.present_to_all_outlined;
      default:
        return Icons.forum_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleplayProvider = Provider.of<RoleplayProvider>(context);
    final scenarios = roleplayProvider.scenarios;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.language, color: AppTheme.primary, size: 24),
            SizedBox(width: 8),
            Text(
              "FluentUp Practice",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
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
              const Text(
                "Scenarios & Practice Modules",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Choose a context to practice your natural fluency through interactive roleplay and camera practice.",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Grid Layout (2 Columns matching Stitch)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.0,
                children: [
                  // Presentation Practice (Camera + MLKit + Groq Vision)
                  _buildScenarioCard(
                    context: context,
                    icon: Icons.videocam_outlined,
                    title: "Presentation Practice",
                    subtitle: "Camera & Vision",
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const PresentationPracticeScreen(),
                        ),
                      );
                    },
                  ),

                  // Describe the Image (Unsplash + Groq Analysis)
                  _buildScenarioCard(
                    context: context,
                    icon: Icons.image_search_outlined,
                    title: "Describe Image",
                    subtitle: "Unsplash Photo",
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const DescribeImageScreen(),
                        ),
                      );
                    },
                  ),

                  // Explain My Code
                  _buildScenarioCard(
                    context: context,
                    icon: Icons.code,
                    title: "Explain My Code",
                    subtitle: "Technical",
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ExplainCodeScreen(),
                        ),
                      );
                    },
                  ),

                  // Dynamic Scenarios
                  ...scenarios.map((scenario) {
                    return _buildScenarioCard(
                      context: context,
                      icon: _getScenarioIcon(scenario['id'] as String),
                      title: scenario['title'] as String,
                      subtitle: "Interactive",
                      onTap: () {
                        roleplayProvider.startSession(scenario);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const RoleplayChatScreen(),
                          ),
                        );
                      },
                    );
                  }),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScenarioCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return TactileButton(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.hairline, width: 1),
        ),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
  }
}
