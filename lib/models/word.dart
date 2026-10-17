/// 单词与学习状态模型
library;

/// 词库分级：界面上直接用原文展示，配色见 theme.dart 的 [levelColor]
const List<String> kLevels = ['easy', 'normal', 'hard', 'extra'];

class Word {
  final String id;
  final String word;
  final String phonetic;
  final String pos;
  final String meaning;
  final String level;
  final String tier; // core = 保底 3000，ext = 高分词汇

  const Word({
    required this.id,
    required this.word,
    required this.phonetic,
    required this.pos,
    required this.meaning,
    required this.level,
    required this.tier,
  });

  /// 分级标签：直接显示原文 easy / normal / hard / extra
  String get levelLabel => level.isEmpty ? 'normal' : level;

  factory Word.fromJson(Map<String, dynamic> j) => Word(
        id: j['id'] as String,
        word: j['word'] as String,
        phonetic: j['phonetic'] as String? ?? '',
        pos: j['pos'] as String? ?? '',
        meaning: j['meaning'] as String? ?? '',
        level: j['level'] as String? ?? 'normal',
        tier: j['tier'] as String? ?? 'core',
      );
}

/// 三档评价；[Rating.confirm] 是首轮才出现的「确定认识」
enum Rating { unknown, fuzzy, know, confirm }

extension RatingX on Rating {
  /// 用于「最近三次」判定的编码：0 不认识 / 1 模糊 / 2 认识
  int get code => switch (this) {
        Rating.unknown => 0,
        Rating.fuzzy => 1,
        Rating.know => 2,
        Rating.confirm => 2,
      };
}

/// 每个单词的学习档案
class WordProgress {
  int knowCount;
  int fuzzyCount;
  int unknownCount;

  /// 最近若干次的有效评价（最多保留 3 个），用于「最近三次全部认识 → 已掌握」
  List<int> recent;

  /// 是否在错题本里
  bool inWrongBook;

  /// 最近一次被选中的时间（毫秒时间戳），用于排复习队列
  int lastSeenMs;

  WordProgress({
    this.knowCount = 0,
    this.fuzzyCount = 0,
    this.unknownCount = 0,
    List<int>? recent,
    this.inWrongBook = false,
    this.lastSeenMs = 0,
  }) : recent = recent ?? <int>[];

  bool get mastered => recent.length >= 3 && recent.every((c) => c == 2);

  bool get seen => knowCount + fuzzyCount + unknownCount > 0;

  /// 首次循环（还没被选过）
  bool get isFresh => !seen && recent.isEmpty;

  void push(int code) {
    recent.add(code);
    if (recent.length > 3) recent.removeAt(0);
  }

  void forceMastered() {
    recent = [2, 2, 2];
  }

  Map<String, dynamic> toJson() => {
        'k': knowCount,
        'f': fuzzyCount,
        'u': unknownCount,
        'r': recent,
        'w': inWrongBook,
        't': lastSeenMs,
      };

  factory WordProgress.fromJson(Map<String, dynamic> j) => WordProgress(
        knowCount: (j['k'] as num?)?.toInt() ?? 0,
        fuzzyCount: (j['f'] as num?)?.toInt() ?? 0,
        unknownCount: (j['u'] as num?)?.toInt() ?? 0,
        recent: ((j['r'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
        inWrongBook: j['w'] as bool? ?? false,
        lastSeenMs: (j['t'] as num?)?.toInt() ?? 0,
      );
}

/// 一天的选择统计
class DayStat {
  int choices; // 今天一共做了多少次选择
  int correct; // 其中选「认识 / 确定认识」的次数

  DayStat({this.choices = 0, this.correct = 0});

  double get accuracy => choices == 0 ? 0 : correct / choices;

  Map<String, dynamic> toJson() => {'c': choices, 'r': correct};

  factory DayStat.fromJson(Map<String, dynamic> j) => DayStat(
        choices: (j['c'] as num?)?.toInt() ?? 0,
        correct: (j['r'] as num?)?.toInt() ?? 0,
      );
}

/// 外观模式：跟随系统 / 浅色 / 深色
enum ThemeModeSetting { system, light, dark }

class Settings {
  bool onboarded;
  String bank; // core / ext
  int? examYear; // 参加高考的年份，null 表示不参加

  /// 外观模式
  ThemeModeSetting themeMode;

  /// 主题色的 HSL（色轮给 H 和 S，明度单独一根滑杆）
  double seedHue; // 0-360
  double seedSaturation; // 0-1
  double seedLightness; // 0-1

  Settings({
    this.onboarded = false,
    this.bank = 'core',
    this.examYear,
    this.themeMode = ThemeModeSetting.system,
    this.seedHue = 229,
    this.seedSaturation = 1.0,
    this.seedLightness = 0.55,
  });

  Map<String, dynamic> toJson() => {
        'onboarded': onboarded,
        'bank': bank,
        'examYear': examYear,
        'themeMode': themeMode.name,
        'hue': seedHue,
        'sat': seedSaturation,
        'light': seedLightness,
      };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        onboarded: j['onboarded'] as bool? ?? false,
        bank: j['bank'] as String? ?? 'core',
        examYear: (j['examYear'] as num?)?.toInt(),
        themeMode: ThemeModeSetting.values.firstWhere(
          (m) => m.name == j['themeMode'],
          orElse: () => ThemeModeSetting.system,
        ),
        seedHue: (j['hue'] as num?)?.toDouble() ?? 229,
        seedSaturation: (j['sat'] as num?)?.toDouble() ?? 1.0,
        seedLightness: (j['light'] as num?)?.toDouble() ?? 0.55,
      );
}
