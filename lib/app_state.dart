import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'models/word.dart';

/// 学习队列里的一项
class StudyItem {
  final Word word;

  /// 是否是「每 5 词插入的错题本单词」
  final bool fromWrongBook;

  const StudyItem(this.word, {this.fromWrongBook = false});
}

/// 全局状态：词库、设置、学习档案、每日统计
class AppState extends ChangeNotifier {
  static const String _key = 'langobei.state.v1';
  static const int dailyGoal = 20;

  List<Word> allWords = const [];
  Map<String, WordProgress> progress = {};
  Map<String, DayStat> daily = {};
  Settings settings = Settings();
  int streak = 0;
  String? lastStudyDay;
  bool ready = false;

  SharedPreferences? _prefs;
  Timer? _saveTimer;
  final Random _random = Random();

  // ---------------- 初始化 ----------------
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = await rootBundle.loadString('assets/words_gaokao.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    allWords = (data['words'] as List<dynamic>)
        .map((e) => Word.fromJson(e as Map<String, dynamic>))
        .toList();

    final saved = _prefs?.getString(_key);
    if (saved != null && saved.isNotEmpty) {
      try {
        final s = jsonDecode(saved) as Map<String, dynamic>;
        progress = (s['progress'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, WordProgress.fromJson(v as Map<String, dynamic>)),
        );
        daily = (s['daily'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, DayStat.fromJson(v as Map<String, dynamic>)),
        );
        settings = Settings.fromJson(s['settings'] as Map<String, dynamic>? ?? {});
        streak = (s['streak'] as num?)?.toInt() ?? 0;
        lastStudyDay = s['lastStudyDay'] as String?;
      } catch (_) {
        progress = {};
        daily = {};
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<void> _saveNow() async {
    await _prefs?.setString(
      _key,
      jsonEncode({
        'progress': progress.map((k, v) => MapEntry(k, v.toJson())),
        'daily': daily.map((k, v) => MapEntry(k, v.toJson())),
        'settings': settings.toJson(),
        'streak': streak,
        'lastStudyDay': lastStudyDay,
      }),
    );
  }

  /// 连续点选时避免每张卡都写盘
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _saveNow);
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    await _saveNow();
  }

  // ---------------- 日期 / 天数 ----------------
  static String dayKey([DateTime? d]) {
    final t = d ?? DateTime.now();
    return '${t.year.toString().padLeft(4, '0')}-'
        '${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
  }

  String get todayKey => dayKey();
  DayStat get todayStat => daily[todayKey] ?? DayStat();

  /// 距离高考还有多少天（按 6 月 7 日算），未设置返回 null
  int? get daysToExam {
    final y = settings.examYear;
    if (y == null) return null;
    final exam = DateTime(y, 6, 7);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = exam.difference(today).inDays;
    return diff < 0 ? 0 : diff;
  }

  // ---------------- 词库 / 统计 ----------------
  List<Word> get bankWords =>
      settings.bank == 'ext' ? allWords : allWords.where((w) => w.tier == 'core').toList();

  int get bankTotal => bankWords.length;

  List<Word> get wrongBookWords =>
      bankWords.where((w) => progress[w.id]?.inWrongBook ?? false).toList();

  int get wrongCount => wrongBookWords.length;

  int get masteredCount => bankWords.where((w) => progress[w.id]?.mastered ?? false).length;

  double get masteredRatio => bankTotal == 0 ? 0 : masteredCount / bankTotal;

  int get studiedCount => bankWords.where((w) => progress[w.id]?.seen ?? false).length;

  double get overallAccuracy {
    final total = progress.values.fold<int>(0, (s, p) => s + p.knowCount + p.fuzzyCount + p.unknownCount);
    if (total == 0) return 0;
    final correct = progress.values.fold<int>(0, (s, p) => s + p.knowCount);
    return correct / total;
  }

  List<MapEntry<String, DayStat>> recentDays(int n) {
    final out = <MapEntry<String, DayStat>>[];
    final now = DateTime.now();
    for (var i = n - 1; i >= 0; i--) {
      final k = dayKey(now.subtract(Duration(days: i)));
      out.add(MapEntry(k, daily[k] ?? DayStat()));
    }
    return out;
  }

  // ---------------- 队列 ----------------
  /// 知新的基础队列：优先没见过的，其次最久没复习的
  List<Word> pickStudyWords({int size = 20}) {
    final pool = bankWords.where((w) {
      final p = progress[w.id];
      if (p == null) return true;
      return !p.mastered && !p.inWrongBook;
    }).toList();

    pool.sort((a, b) {
      final pa = progress[a.id];
      final pb = progress[b.id];
      if (pa == null && pb == null) return a.word.compareTo(b.word);
      if (pa == null) return -1;
      if (pb == null) return 1;
      return pa.lastSeenMs.compareTo(pb.lastSeenMs);
    });

    return pool.take(size).toList();
  }

  /// 实时取一个错题（每 5 个词插入一张时用），[exclude] 里的这一轮已经出现过
  Word? pickWrongBookWord({Set<String> exclude = const {}}) {
    final pool = wrongBookWords.where((w) => !exclude.contains(w.id)).toList();
    if (pool.isEmpty) return null;
    return pool[_random.nextInt(pool.length)];
  }

  List<StudyItem> buildReflectQueue({int size = 20}) {
    final list = wrongBookWords.toList()..shuffle(_random);
    return list.take(size).map((w) => StudyItem(w, fromWrongBook: true)).toList();
  }

  // ---------------- 记录选择 ----------------
  /// [elapsedMs] 是这张卡停留的毫秒数；超过 3 秒会**悄悄**降级为「模糊」。
  /// [fromReflect] 为 true 表示在「反思」里作答。
  void answer(
    Word word,
    Rating choice, {
    required int elapsedMs,
    required bool fromReflect,
    bool isReviewCard = false,
  }) {
    final p = progress[word.id] ?? WordProgress();
    final effective = (!fromReflect && elapsedMs > 3000) ? Rating.fuzzy : choice;

    if (choice == Rating.confirm) {
      p.knowCount += 1;
      p.forceMastered();
      p.inWrongBook = false;
    } else {
      switch (choice) {
        case Rating.know:
          p.knowCount += 1;
          break;
        case Rating.fuzzy:
          p.fuzzyCount += 1;
          break;
        case Rating.unknown:
          p.unknownCount += 1;
          break;
        case Rating.confirm:
          break;
      }
      p.push(effective.code);

      // 错题本跟随用户明面上的选择
      if (choice == Rating.unknown) {
        p.inWrongBook = true;
      } else if (choice == Rating.know) {
        // 知新里插入的错题卡 / 反思里答对 → 移出错题本
        if (fromReflect || isReviewCard) p.inWrongBook = false;
      }
    }

    p.lastSeenMs = DateTime.now().millisecondsSinceEpoch;
    progress[word.id] = p;

    final stat = daily[todayKey] ?? DayStat();
    stat.choices += 1;
    if (effective.code == 2) stat.correct += 1;
    daily[todayKey] = stat;

    _touchStreak();
    notifyListeners();
    _scheduleSave();
  }

  void _touchStreak() {
    final today = todayKey;
    if (lastStudyDay == today) return;
    final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));
    streak = lastStudyDay == yesterday ? streak + 1 : 1;
    lastStudyDay = today;
  }

  // ---------------- 设置 ----------------
  Future<void> completeOnboarding({required String bank, required int? examYear}) async {
    settings = Settings(onboarded: true, bank: bank, examYear: examYear);
    notifyListeners();
    await _saveNow();
  }

  Future<void> resetAll() async {
    progress = {};
    daily = {};
    streak = 0;
    lastStudyDay = null;
    settings = Settings();
    notifyListeners();
    await _saveNow();
  }
}
