import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'models/word.dart';
import 'word_queue.dart';

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

  /// 每一轮「知新」的伪随机种子来源（种子本身不落盘，换一轮就换一个）
  final Random _seedSource = Random();

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

  /// 存档内容：写盘和「导出数据」共用同一份格式，导出的东西就是能用来恢复的东西
  Map<String, dynamic> toSnapshot() => {
        'progress': progress.map((k, v) => MapEntry(k, v.toJson())),
        'daily': daily.map((k, v) => MapEntry(k, v.toJson())),
        'settings': settings.toJson(),
        'streak': streak,
        'lastStudyDay': lastStudyDay,
      };

  Future<void> _saveNow() async {
    await _prefs?.setString(_key, jsonEncode(toSnapshot()));
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

  /// 当前词库里各分级的词数（easy / normal / hard / extra）
  Map<String, int> get levelCounts {
    final counts = <String, int>{for (final l in kLevels) l: 0};
    for (final w in bankWords) {
      counts[w.level] = (counts[w.level] ?? 0) + 1;
    }
    return counts;
  }

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
  /// 知新的基础队列：伪随机打乱 + 按各分级在词库里的占比均匀交错。
  ///
  /// 每个分级单独一个桶，桶内**没见过的词**打乱后放前面，见过的词按「最久没复习」
  /// 排后面（新词优先，其次是该复习的）；再把各桶交错成一条队列，让不同难度均匀出现。
  /// [seed] 只给测试用：不传就用一个真随机种子，所以每次进「知新」顺序都是新的，
  /// 但同一轮里固定不变。
  List<Word> pickStudyWords({int size = 20, int? seed}) {
    final buckets = bucketByLevel(bankWords.where((w) {
      final p = progress[w.id];
      if (p == null) return true;
      return !p.mastered && !p.inWrongBook;
    }));

    final rng = Random(seed ?? _seedSource.nextInt(1 << 31));
    for (final level in kLevels) {
      final fresh = <Word>[];
      final seen = <Word>[];
      for (final w in buckets[level]!) {
        (progress[w.id] == null ? fresh : seen).add(w);
      }
      fresh.shuffle(rng);
      seen.sort((a, b) => (progress[a.id]?.lastSeenMs ?? 0)
          .compareTo(progress[b.id]?.lastSeenMs ?? 0));
      buckets[level] = [...fresh, ...seen];
    }

    return buildBalancedQueue(buckets, rng: rng).take(size).toList();
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

  Future<void> setThemeMode(ThemeModeSetting mode) async {
    settings.themeMode = mode;
    notifyListeners();
    await _saveNow();
  }

  /// 切换词库（菜鸟 / 大神）。进度按单词 id 存，换库不会丢已经背过的词
  Future<void> setBank(String bank) async {
    final target = bank == kBankExt ? kBankExt : kBankCore;
    if (settings.bank == target) return;
    settings.bank = target;
    notifyListeners();
    await _saveNow();
  }

  /// 修改高考年份（更多页里也能改）
  Future<void> setExamYear(int? year) async {
    if (settings.examYear == year) return;
    settings.examYear = year;
    notifyListeners();
    await _saveNow();
  }

  /// 主题色四选一；留空的格子不接受选中
  Future<void> setThemePreset(String id) async {
    final preset = presetById(id);
    if (preset.reserved) return;
    if (settings.themePreset == preset.id) return;
    settings.themePreset = preset.id;
    notifyListeners();
    await _saveNow();
  }

  /// 清空学习进度，但保留外观偏好
  Future<void> resetAll() async {
    final mode = settings.themeMode;
    final preset = settings.themePreset;

    progress = {};
    daily = {};
    streak = 0;
    lastStudyDay = null;
    settings = Settings(themeMode: mode, themePreset: preset);
    notifyListeners();
    await _saveNow();
  }
}
