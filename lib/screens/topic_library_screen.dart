import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'practice_call_screen.dart';
import 'explain_code_screen.dart';
import 'dialogue_practice_screen.dart';
import '../services/learner_profile_service.dart';

class TopicLibraryScreen extends StatefulWidget {
  const TopicLibraryScreen({super.key});

  @override
  State<TopicLibraryScreen> createState() => _TopicLibraryScreenState();
}

class _TopicLibraryScreenState extends State<TopicLibraryScreen> {
  List<Map<String, dynamic>> _allTopics = [];
  List<Map<String, dynamic>> _filteredTopics = [];
  String _selectedCategory = "All";
  String _searchQuery = "";
  bool _isLoading = true;

  final List<String> _categories = ["All", "Daily Life", "Professional", "Exams", "Technical"];

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    try {
      final jsonString = await rootBundle.loadString('assets/topics.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final topics = jsonList.map((e) => Map<String, dynamic>.from(e)).toList();

      final profile = await LearnerProfileService.instance.computeProfile();
      final goal = profile.learningGoal.toLowerCase();

      String targetCat = "";
      if (goal.contains("interview") || goal.contains("job") || goal.contains("work")) {
        targetCat = "Professional";
      } else if (goal.contains("daily") || goal.contains("conversation")) {
        targetCat = "Daily Life";
      } else if (goal.contains("abroad") || goal.contains("study") || goal.contains("exam")) {
        targetCat = "Exams";
      }

      if (targetCat.isNotEmpty) {
        topics.sort((a, b) {
          final catA = a['category'] as String? ?? '';
          final catB = b['category'] as String? ?? '';
          if (catA == targetCat && catB != targetCat) return -1;
          if (catB == targetCat && catA != targetCat) return 1;
          return 0;
        });
      }

      setState(() {
        _allTopics = topics;
        _filteredTopics = topics;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading topics: $e");
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    setState(() {
      _filteredTopics = _allTopics.where((t) {
        final matchesCat = _selectedCategory == "All" || t['category'] == _selectedCategory;
        final matchesQuery = _searchQuery.isEmpty ||
            (t['title'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (t['description'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesCat && matchesQuery;
      }).toList();
    });
  }

  IconData _getTopicIcon(String iconName) {
    switch (iconName) {
      case 'schedule': return Icons.schedule;
      case 'palette': return Icons.palette_outlined;
      case 'flight_takeoff': return Icons.flight_takeoff;
      case 'restaurant': return Icons.restaurant_outlined;
      case 'movie': return Icons.movie_outlined;
      case 'fitness_center': return Icons.fitness_center;
      case 'devices': return Icons.devices;
      case 'wb_sunny': return Icons.wb_sunny_outlined;
      case 'music_note': return Icons.music_note_outlined;
      case 'location_city': return Icons.location_city;
      case 'work': return Icons.work_outline;
      case 'badge': return Icons.badge_outlined;
      case 'call': return Icons.call_outlined;
      case 'groups': return Icons.groups_outlined;
      case 'co_present': return Icons.co_present;
      case 'attach_money': return Icons.attach_money;
      case 'record_voice_over': return Icons.record_voice_over;
      case 'hourglass_empty': return Icons.hourglass_empty;
      case 'quiz': return Icons.quiz_outlined;
      case 'eco': return Icons.eco_outlined;
      case 'account_balance': return Icons.account_balance_outlined;
      case 'school': return Icons.school_outlined;
      case 'computer': return Icons.computer;
      case 'code': return Icons.code;
      case 'architecture': return Icons.architecture;
      case 'bug_report': return Icons.bug_report_outlined;
      case 'api': return Icons.api;
      case 'storage': return Icons.storage;
      default: return Icons.forum_outlined;
    }
  }

  void _startTopicSession(Map<String, dynamic> topic) {
    if (topic['id'] == 'tech_1') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const ExplainCodeScreen()),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PracticeCallScreen(topic: topic),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.language, color: AppTheme.primary, size: 24),
            SizedBox(width: 8),
            Text(
              "Topic Library",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
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
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Scripted Dialogue Practice Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.containerPadding),
              child: Card(
                color: AppTheme.primary.withOpacity(0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DialoguePracticeScreen()),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.record_voice_over, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "NEW: Dialogue Practice",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: AppTheme.primary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Scripted Shadowing",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                "Practice real-life two-person scripts line by line.",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Search Input Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.containerPadding),
              child: TextField(
                onChanged: (val) {
                  _searchQuery = val;
                  _applyFilter();
                },
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: "Search 35+ practice topics...",
                  hintStyle: const TextStyle(color: AppTheme.textSecondary),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.surfaceContainer,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.hairline),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.containerPadding),
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (_) {
                        _selectedCategory = cat;
                        _applyFilter();
                      },
                      selectedColor: AppTheme.primary,
                      backgroundColor: AppTheme.surfaceContainer,
                      labelStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppTheme.hairline),

            // Topics Grid / List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppTheme.containerPadding),
                      itemCount: _filteredTopics.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final topic = _filteredTopics[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.hairline),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _startTopicSession(topic),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _getTopicIcon(topic['icon'] as String? ?? 'forum'),
                                        color: AppTheme.primary,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primary.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  (topic['category'] as String).toUpperCase(),
                                                  style: const TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.primary,
                                                    letterSpacing: 0.8,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            topic['title'] as String,
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            topic['description'] as String,
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 13,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.phone_in_talk,
                                      color: AppTheme.primary,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
