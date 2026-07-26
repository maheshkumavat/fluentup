import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DbHelper {
  static final DbHelper instance = DbHelper._init();
  static Database? _database;

  DbHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('fluentup.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 11,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender TEXT NOT NULL,
        text TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE mistakes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        prompt TEXT NOT NULL,
        wrong_answer TEXT NOT NULL,
        correct_answer TEXT NOT NULL,
        tense_used TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scenario_name TEXT NOT NULL,
        summary TEXT NOT NULL,
        mistakes_count INTEGER NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE code_explanations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code_snippet TEXT NOT NULL,
        explanation_text TEXT NOT NULL,
        feedback TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE vocabulary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL UNIQUE,
        meaning TEXT NOT NULL,
        example_sentence TEXT NOT NULL,
        synonym TEXT NOT NULL,
        next_review_date TEXT NOT NULL,
        review_count INTEGER NOT NULL DEFAULT 0,
        ease_factor REAL NOT NULL DEFAULT 2.5,
        is_saved INTEGER NOT NULL DEFAULT 0,
        pronunciation_guide TEXT DEFAULT '',
        part_of_speech TEXT DEFAULT '',
        usage_context TEXT DEFAULT '',
        created_timestamp TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE activity_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        xp_earned INTEGER NOT NULL DEFAULT 0,
        activities_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE assessments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pronunciation INTEGER NOT NULL,
        fluency INTEGER NOT NULL,
        grammar INTEGER NOT NULL,
        vocabulary INTEGER NOT NULL,
        overall_level TEXT NOT NULL,
        one_line_summary TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE session_scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_type TEXT NOT NULL,
        topic_name TEXT NOT NULL,
        pronunciation INTEGER NOT NULL,
        fluency INTEGER NOT NULL,
        grammar INTEGER NOT NULL,
        vocabulary INTEGER NOT NULL,
        filler_word_count INTEGER NOT NULL,
        pace_feedback TEXT NOT NULL,
        overall_score REAL NOT NULL,
        strengths TEXT NOT NULL,
        improvements TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE roadmap_progress (
        day_number INTEGER PRIMARY KEY,
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_timestamp TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE grammar_mastery (
        unit_id TEXT PRIMARY KEY,
        score INTEGER NOT NULL,
        attempts INTEGER NOT NULL,
        last_attempted_date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE dynamic_roadmap_days (
        day_number INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        activity_type TEXT NOT NULL,
        target_topic_id TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_timestamp TEXT
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE mistakes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          prompt TEXT NOT NULL,
          wrong_answer TEXT NOT NULL,
          correct_answer TEXT NOT NULL,
          tense_used TEXT NOT NULL,
          timestamp TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          scenario_name TEXT NOT NULL,
          summary TEXT NOT NULL,
          mistakes_count INTEGER NOT NULL,
          timestamp TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE code_explanations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          code_snippet TEXT NOT NULL,
          explanation_text TEXT NOT NULL,
          feedback TEXT NOT NULL,
          timestamp TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE vocabulary (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          word TEXT NOT NULL UNIQUE,
          meaning TEXT NOT NULL,
          example_sentence TEXT NOT NULL,
          synonym TEXT NOT NULL,
          next_review_date TEXT NOT NULL,
          review_count INTEGER NOT NULL DEFAULT 0,
          ease_factor REAL NOT NULL DEFAULT 2.5
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE activity_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL UNIQUE,
          xp_earned INTEGER NOT NULL DEFAULT 0,
          activities_count INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE assessments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          pronunciation INTEGER NOT NULL,
          fluency INTEGER NOT NULL,
          grammar INTEGER NOT NULL,
          vocabulary INTEGER NOT NULL,
          overall_level TEXT NOT NULL,
          one_line_summary TEXT NOT NULL,
          timestamp TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE session_scores (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_type TEXT NOT NULL,
          topic_name TEXT NOT NULL,
          pronunciation INTEGER NOT NULL,
          fluency INTEGER NOT NULL,
          grammar INTEGER NOT NULL,
          vocabulary INTEGER NOT NULL,
          filler_word_count INTEGER NOT NULL,
          pace_feedback TEXT NOT NULL,
          overall_score REAL NOT NULL,
          strengths TEXT NOT NULL,
          improvements TEXT NOT NULL,
          timestamp TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE roadmap_progress (
          day_number INTEGER PRIMARY KEY,
          is_completed INTEGER NOT NULL DEFAULT 0,
          completed_timestamp TEXT
        )
      ''');
    }
    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE vocabulary ADD COLUMN is_saved INTEGER NOT NULL DEFAULT 0');
      } catch (e) {
        // Ignored if column already exists
      }
    }
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS grammar_mastery (
          unit_id TEXT PRIMARY KEY,
          score INTEGER NOT NULL,
          attempts INTEGER NOT NULL,
          last_attempted_date TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 10) {
      try {
        await db.execute("ALTER TABLE vocabulary ADD COLUMN pronunciation_guide TEXT DEFAULT ''");
        await db.execute("ALTER TABLE vocabulary ADD COLUMN part_of_speech TEXT DEFAULT ''");
        await db.execute("ALTER TABLE vocabulary ADD COLUMN usage_context TEXT DEFAULT ''");
        await db.execute("ALTER TABLE vocabulary ADD COLUMN created_timestamp TEXT");
      } catch (e) {
        // Ignored if columns already exist
      }
    }
    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS dynamic_roadmap_days (
          day_number INTEGER PRIMARY KEY,
          title TEXT NOT NULL,
          description TEXT NOT NULL,
          activity_type TEXT NOT NULL,
          target_topic_id TEXT NOT NULL,
          is_completed INTEGER NOT NULL DEFAULT 0,
          completed_timestamp TEXT
        )
      ''');
    }
  }

  // Messages CRUD
  Future<int> insertMessage(String sender, String text, String timestamp) async {
    final db = await instance.database;
    return await db.insert('messages', {
      'sender': sender,
      'text': text,
      'timestamp': timestamp,
    });
  }

  Future<List<Map<String, dynamic>>> getLastMessages(int limit) async {
    final db = await instance.database;
    final result = await db.query(
      'messages',
      orderBy: 'id DESC',
      limit: limit,
    );
    return result.reversed.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  Future<void> clearAllMessages() async {
    final db = await instance.database;
    await db.delete('messages');
  }

  // Settings CRUD
  Future<int> setSetting(String key, String value) async {
    final db = await instance.database;
    return await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await instance.database;
    final maps = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String;
    }
    return null;
  }

  // Mistakes CRUD
  Future<int> insertMistake(String prompt, String wrongAnswer, String correctAnswer, String tenseUsed, String timestamp) async {
    final db = await instance.database;
    return await db.insert('mistakes', {
      'prompt': prompt,
      'wrong_answer': wrongAnswer,
      'correct_answer': correctAnswer,
      'tense_used': tenseUsed,
      'timestamp': timestamp,
    });
  }

  Future<List<Map<String, dynamic>>> getMistakes() async {
    final db = await instance.database;
    return await db.query('mistakes', orderBy: 'id DESC');
  }

  Future<void> clearAllMistakes() async {
    final db = await instance.database;
    await db.delete('mistakes');
  }

  Future<Map<String, int>> getMistakeCountsByTense() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT tense_used, COUNT(*) as count 
      FROM mistakes 
      GROUP BY tense_used
    ''');
    
    final Map<String, int> counts = {
      'past': 0,
      'present': 0,
      'future': 0,
      'mixed': 0,
    };
    
    for (var row in result) {
      final tense = (row['tense_used'] as String).toLowerCase().trim();
      final count = row['count'] as int;
      if (counts.containsKey(tense)) {
        counts[tense] = count;
      } else {
        counts['mixed'] = (counts['mixed'] ?? 0) + count;
      }
    }
    return counts;
  }

  // Sessions CRUD
  Future<int> insertSession(String scenarioName, String summary, int mistakesCount, String timestamp) async {
    final db = await instance.database;
    return await db.insert('sessions', {
      'scenario_name': scenarioName,
      'summary': summary,
      'mistakes_count': mistakesCount,
      'timestamp': timestamp,
    });
  }

  Future<List<Map<String, dynamic>>> getSessions() async {
    final db = await instance.database;
    return await db.query('sessions', orderBy: 'id DESC');
  }

  Future<void> clearAllSessions() async {
    final db = await instance.database;
    await db.delete('sessions');
  }

  // Code Explanations CRUD
  Future<int> insertCodeExplanation(String codeSnippet, String explanationText, String feedback, String timestamp) async {
    final db = await instance.database;
    return await db.insert('code_explanations', {
      'code_snippet': codeSnippet,
      'explanation_text': explanationText,
      'feedback': feedback,
      'timestamp': timestamp,
    });
  }

  Future<List<Map<String, dynamic>>> getCodeExplanations() async {
    final db = await instance.database;
    return await db.query('code_explanations', orderBy: 'id DESC');
  }

  Future<void> clearAllCodeExplanations() async {
    final db = await instance.database;
    await db.delete('code_explanations');
  }

  // Vocabulary CRUD
  Future<int> insertVocabularyWord(
    String word,
    String meaning,
    String exampleSentence,
    String synonym,
    String nextReviewDate,
    int reviewCount,
    double easeFactor, {
    String pronunciationGuide = '',
    String partOfSpeech = '',
    String usageContext = '',
    String? createdTimestamp,
  }) async {
    final db = await instance.database;
    final nowIso = createdTimestamp ?? DateTime.now().toIso8601String();
    return await db.insert(
      'vocabulary',
      {
        'word': word,
        'meaning': meaning,
        'example_sentence': exampleSentence,
        'synonym': synonym,
        'next_review_date': nextReviewDate,
        'review_count': reviewCount,
        'ease_factor': easeFactor,
        'pronunciation_guide': pronunciationGuide,
        'part_of_speech': partOfSpeech,
        'usage_context': usageContext,
        'created_timestamp': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getWordsLearnedThisWeek() async {
    final db = await instance.database;
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM vocabulary WHERE created_timestamp >= ? OR (created_timestamp IS NULL AND next_review_date >= ?)",
      [sevenDaysAgo, sevenDaysAgo],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getDueVocabularyWords() async {
    final db = await instance.database;
    final nowIso = DateTime.now().toIso8601String();
    return await db.query(
      'vocabulary',
      where: 'next_review_date <= ?',
      whereArgs: [nowIso],
      orderBy: 'id ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllVocabularyWords() async {
    final db = await instance.database;
    return await db.query('vocabulary', orderBy: 'id DESC');
  }

  Future<int> updateVocabularyReview(int id, String nextReviewDate, int reviewCount, double easeFactor) async {
    final db = await instance.database;
    return await db.update(
      'vocabulary',
      {
        'next_review_date': nextReviewDate,
        'review_count': reviewCount,
        'ease_factor': easeFactor,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getSavedVocabularyWords() async {
    final db = await instance.database;
    return await db.query(
      'vocabulary',
      where: 'is_saved = 1',
      orderBy: 'id DESC',
    );
  }

  Future<int> toggleSaveVocabularyWord(int id, bool isSaved) async {
    final db = await instance.database;
    return await db.update(
      'vocabulary',
      {'is_saved': isSaved ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAllVocabulary() async {
    final db = await instance.database;
    await db.delete('vocabulary');
  }

  // Activity Log CRUD
  Future<void> logDailyActivity(String dateStr, int xp) async {
    final db = await instance.database;
    final existing = await db.query(
      'activity_log',
      where: 'date = ?',
      whereArgs: [dateStr],
    );

    if (existing.isNotEmpty) {
      final currentXp = (existing.first['xp_earned'] as int? ?? 0);
      final currentCount = (existing.first['activities_count'] as int? ?? 0);
      await db.update(
        'activity_log',
        {
          'xp_earned': currentXp + xp,
          'activities_count': currentCount + 1,
        },
        where: 'date = ?',
        whereArgs: [dateStr],
      );
    } else {
      await db.insert('activity_log', {
        'date': dateStr,
        'xp_earned': xp,
        'activities_count': 1,
      });
    }
  }

  Future<Map<String, int>> getActivityLogMap() async {
    final db = await instance.database;
    final rows = await db.query('activity_log');
    final Map<String, int> map = {};
    for (var r in rows) {
      map[r['date'] as String] = r['xp_earned'] as int;
    }
    return map;
  }

  Future<List<Map<String, dynamic>>> getActivityLogs() async {
    final db = await instance.database;
    return await db.query('activity_log', orderBy: 'date DESC');
  }

  // Baseline Assessment CRUD
  Future<int> insertAssessment(int pronunciation, int fluency, int grammar, int vocabulary, String overallLevel, String summary, String timestamp) async {
    final db = await instance.database;
    return await db.insert('assessments', {
      'pronunciation': pronunciation,
      'fluency': fluency,
      'grammar': grammar,
      'vocabulary': vocabulary,
      'overall_level': overallLevel,
      'one_line_summary': summary,
      'timestamp': timestamp,
    });
  }

  Future<Map<String, dynamic>?> getLatestAssessment() async {
    final db = await instance.database;
    final result = await db.query('assessments', orderBy: 'id DESC', limit: 1);
    if (result.isNotEmpty) {
      return Map<String, dynamic>.from(result.first);
    }
    return null;
  }

  // Session Scores CRUD
  Future<int> insertSessionScore(
    String sessionType,
    String topicName,
    int pronunciation,
    int fluency,
    int grammar,
    int vocabulary,
    int fillerWordCount,
    String paceFeedback,
    double overallScore,
    String strengthsJson,
    String improvementsJson,
    String timestamp,
  ) async {
    final db = await instance.database;
    return await db.insert('session_scores', {
      'session_type': sessionType,
      'topic_name': topicName,
      'pronunciation': pronunciation,
      'fluency': fluency,
      'grammar': grammar,
      'vocabulary': vocabulary,
      'filler_word_count': fillerWordCount,
      'pace_feedback': paceFeedback,
      'overall_score': overallScore,
      'strengths': strengthsJson,
      'improvements': improvementsJson,
      'timestamp': timestamp,
    });
  }

  Future<List<Map<String, dynamic>>> getAllSessionScores() async {
    final db = await instance.database;
    return await db.query('session_scores', orderBy: 'timestamp DESC');
  }

  Future<List<Map<String, dynamic>>> getRecentSessionScores(int limit) async {
    final db = await instance.database;
    return await db.query(
      'session_scores',
      orderBy: 'id DESC',
      limit: limit,
    );
  }

  Future<Map<String, dynamic>?> getLatestSessionScore() async {
    final db = await instance.database;
    final result = await db.query('session_scores', orderBy: 'id DESC', limit: 1);
    if (result.isNotEmpty) {
      return Map<String, dynamic>.from(result.first);
    }
    return null;
  }

  // Roadmap Progress CRUD
  Future<void> completeRoadmapDay(int dayNumber) async {
    final db = await instance.database;
    await db.insert(
      'roadmap_progress',
      {
        'day_number': dayNumber,
        'is_completed': 1,
        'completed_timestamp': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<int>> getCompletedRoadmapDays() async {
    final db = await instance.database;
    final result = await db.query(
      'roadmap_progress',
      columns: ['day_number'],
      where: 'is_completed = 1',
    );
    return result.map((r) => r['day_number'] as int).toList();
  }

  Future<void> clearAllActivityLogs() async {
    final db = await instance.database;
    await db.delete('activity_log');
  }

  Future<void> saveGrammarMastery(String unitId, int score, int attempts) async {
    final db = await instance.database;
    await db.insert(
      'grammar_mastery',
      {
        'unit_id': unitId,
        'score': score,
        'attempts': attempts,
        'last_attempted_date': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllGrammarMastery() async {
    final db = await instance.database;
    return await db.query('grammar_mastery');
  }

  Future<Map<String, dynamic>?> getGrammarMasteryForUnit(String unitId) async {
    final db = await instance.database;
    final res = await db.query('grammar_mastery', where: 'unit_id = ?', whereArgs: [unitId]);
    if (res.isNotEmpty) return res.first;
    return null;
  }

  // Dynamic Roadmap CRUD
  Future<void> insertDynamicRoadmapDays(List<Map<String, dynamic>> days) async {
    final db = await instance.database;
    for (var d in days) {
      await db.insert(
        'dynamic_roadmap_days',
        {
          'day_number': d['day_number'],
          'title': d['title'],
          'description': d['description'],
          'activity_type': d['activity_type'],
          'target_topic_id': d['target_topic_id'],
          'is_completed': (d['is_completed'] as bool? ?? false) ? 1 : 0,
          'completed_timestamp': d['completed_timestamp'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getAllDynamicRoadmapDays() async {
    final db = await instance.database;
    return await db.query('dynamic_roadmap_days', orderBy: 'day_number ASC');
  }

  Future<void> completeDynamicRoadmapDay(int dayNumber) async {
    final db = await instance.database;
    await db.update(
      'dynamic_roadmap_days',
      {
        'is_completed': 1,
        'completed_timestamp': DateTime.now().toIso8601String(),
      },
      where: 'day_number = ?',
      whereArgs: [dayNumber],
    );
    await completeRoadmapDay(dayNumber);
  }

  Future<void> clearUserData() async {
    final db = await instance.database;
    await db.delete('messages');
    await db.delete('settings');
    await db.delete('mistakes');
    await db.delete('sessions');
    await db.delete('code_explanations');
    await db.delete('vocabulary');
    await db.delete('activity_log');
    await db.delete('session_scores');
    await db.delete('roadmap_progress');
    await db.delete('grammar_mastery');
  }
}
