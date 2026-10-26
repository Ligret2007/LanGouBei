/// 单词与学习状态模型
library;

/// 词库分级：界面上直接用原文展示，配色见 theme.dart 的 [levelColor]
const List<String> kLevels = ['easy', 'normal', 'hard', 'extra'];

/// 两套词库的 id（存盘用）：core = 菜鸟，ext = 大神
const String kBankCore = 'core';
const String kBankExt = 'ext';

/// 高考年份可选范围（滚动式年份选择器）
const int kExamYearMin = 2027;
const int kExamYearMax = 2040;

List<int> get kExamYears =>
    [for (var y = kExamYearMin; y <= kExamYearMax; y++) y];

String bankTitle(String bank) => bank == kBankExt ? '高考：我是大神' : '高考：我是菜鸟';

String bankSubtitle(String bank) =>
    bank == kBankExt ? '3540 词 · 在菜鸟的基础上增加低频词' : '3014 词 · 基础到进阶，覆盖高考高频';

/// 还没开放、先占位的词库（引导页和「更多」都展示，但点不动）
const List<({String title, String subtitle})> kPlannedBanks = [
  (title: '四级词汇', subtitle: '暂未开放'),
  (title: '雅思 6.5 词汇', subtitle: '暂未开放'),
];

/// 高考年份统一收进合法区间，越界或为空都回落到第一年
int clampExamYear(int? year) {
  if (year == null) return kExamYearMin;
  if (year < kExamYearMin) return kExamYearMin;
  if (year > kExamYearMax) return kExamYearMax;
  return year;
}

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

  /// 导出词库时用；空字段直接省略，导出的文件更小也更好读
  Map<String, dynamic> toJson() => {
        'id': id,
        'word': word,
        if (phonetic.isNotEmpty) 'phonetic': phonetic,
        if (pos.isNotEmpty) 'pos': pos,
        if (meaning.isNotEmpty) 'meaning': meaning,
        'level': level,
        'tier': tier,
      };

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

/// 主题色预设：色值仍然用 HSL 描述，方便以后加自定义取色
class ThemePreset {
  final String id;
  final String label;
  final double hue; // 0-360
  final double saturation; // 0-1
  final double lightness; // 0-1

  /// 留空的格子：占位用，不能选中
  final bool reserved;

  const ThemePreset({
    required this.id,
    required this.label,
    required this.hue,
    required this.saturation,
    required this.lightness,
    this.reserved = false,
  });
}

/// 四选一：默认 / 深绿 / 紫色 /（留空）
const List<ThemePreset> kThemePresets = [
  ThemePreset(id: 'default', label: '默认', hue: 229, saturation: 1.00, lightness: 0.55),
  ThemePreset(id: 'green', label: '深绿', hue: 152, saturation: 0.62, lightness: 0.36),
  ThemePreset(id: 'purple', label: '紫色', hue: 272, saturation: 0.70, lightness: 0.52),
  ThemePreset(
    id: 'reserved',
    label: '待定',
    hue: 0,
    saturation: 0,
    lightness: 0.5,
    reserved: true,
  ),
];

ThemePreset presetById(String id) => kThemePresets.firstWhere(
      (p) => p.id == id && !p.reserved,
      orElse: () => kThemePresets.first,
    );

/// 老数据里存的是自由 HSL，迁移时找色相最接近的预设
ThemePreset nearestPreset(double hue) {
  ThemePreset best = kThemePresets.first;
  var bestGap = 361.0;
  for (final p in kThemePresets) {
    if (p.reserved) continue;
    final gap = (p.hue - hue).abs();
    final wrapped = gap > 180 ? 360 - gap : gap;
    if (wrapped < bestGap) {
      bestGap = wrapped;
      best = p;
    }
  }
  // 差距太大就认为是随手拖的，回到默认
  return bestGap <= 24 ? best : kThemePresets.first;
}

class Settings {
  bool onboarded;
  String bank; // core / ext
  int? examYear; // 参加高考的年份，null 表示不参加

  /// 外观模式
  ThemeModeSetting themeMode;

  /// 主题色预设 id（default / green / purple）
  String themePreset;

  Settings({
    this.onboarded = false,
    this.bank = 'core',
    this.examYear,
    this.themeMode = ThemeModeSetting.system,
    this.themePreset = 'default',
  });

  Map<String, dynamic> toJson() => {
        'onboarded': onboarded,
        'bank': bank,
        'examYear': examYear,
        'themeMode': themeMode.name,
        'preset': themePreset,
      };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        onboarded: j['onboarded'] as bool? ?? false,
        bank: j['bank'] as String? ?? 'core',
        examYear: (j['examYear'] as num?)?.toInt(),
        themeMode: ThemeModeSetting.values.firstWhere(
          (m) => m.name == j['themeMode'],
          orElse: () => ThemeModeSetting.system,
        ),
        themePreset: _migratePreset(j),
      );

  /// 新字段直接用 preset；老数据只有自由 HSL，就迁到最接近的预设
  static String _migratePreset(Map<String, dynamic> j) {
    final saved = j['preset'] as String?;
    if (saved != null) return presetById(saved).id;
    final legacyHue = (j['hue'] as num?)?.toDouble();
    if (legacyHue == null) return 'default';
    return nearestPreset(legacyHue).id;
  }
}
