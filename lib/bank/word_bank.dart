import 'dart:convert';

import '../models/word.dart';

/// 词库文件的格式标识与版本。
///
/// 导出的文件都带这两个字段：以后格式升级时能认出「这个文件比 App 新」，
/// 给出明确提示而不是解析到一半炸掉。
const String kBankFormat = 'langobei-bank';
const int kBankFormatVersion = 1;

/// 词库元信息。内置库的元信息来自 `assets/banks/index.json`，
/// 导入库的元信息来自文件自身（缺省时用文件名兜底）。
class WordBankMeta {
  final String id;
  final String name;
  final String subtitle;
  final String description;
  final String author;
  final String version;

  /// true = 随安装包内置；false = 用户导入
  final bool builtin;

  /// 内置库从哪个资源文件读；导入库为 null
  final String? assetPath;

  /// 只取这个 tier 的词（内置高考词库用它拆成「菜鸟 / 大神」两个库）
  final String? tierFilter;

  const WordBankMeta({
    required this.id,
    required this.name,
    this.subtitle = '',
    this.description = '',
    this.author = '',
    this.version = '1.0.0',
    this.builtin = false,
    this.assetPath,
    this.tierFilter,
  });
}

/// 一个词库 = 元信息 + 单词本体。
class WordBank {
  final WordBankMeta meta;
  final List<Word> words;

  const WordBank({required this.meta, required this.words});

  String get id => meta.id;
  String get name => meta.name;
  int get wordCount => words.length;
  bool get isEmpty => words.isEmpty;

  /// 各分级词数
  Map<String, int> get levelCounts {
    final counts = <String, int>{for (final l in kLevels) l: 0};
    for (final w in words) {
      counts[w.level] = (counts[w.level] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, dynamic> toJson() => {
        'format': kBankFormat,
        'formatVersion': kBankFormatVersion,
        'id': meta.id,
        'name': meta.name,
        if (meta.subtitle.isNotEmpty) 'subtitle': meta.subtitle,
        if (meta.description.isNotEmpty) 'description': meta.description,
        if (meta.author.isNotEmpty) 'author': meta.author,
        'version': meta.version,
        'wordCount': wordCount,
        'words': [for (final w in words) w.toJson()],
      };

  /// 导出用。pretty = true 时带缩进，人也能读。
  String encode({bool pretty = true}) => pretty
      ? const JsonEncoder.withIndent('  ').convert(toJson())
      : jsonEncode(toJson());
}

/// 词库文件有问题时抛这个，[message] 直接给用户看。
class BankFormatException implements Exception {
  final String message;

  const BankFormatException(this.message);

  @override
  String toString() => message;
}

/// 解析结果：除了词库本身，还带「哪些地方被宽容处理了」的说明。
class BankParseResult {
  final WordBank bank;
  final List<String> warnings;

  const BankParseResult(this.bank, this.warnings);

  bool get hasWarnings => warnings.isNotEmpty;
}

String? _text(Object? v) {
  if (v is String) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
  return null;
}

/// 从单词派生一个稳定的 id（导入的文件常常没有 id 字段）
String deriveWordId(String word) {
  final s = word.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-');
  final trimmed = s.replaceAll(RegExp('^-+|-+\$'), '');
  return trimmed.isEmpty ? word : trimmed;
}

/// 解析一份词库文件。
///
/// 宽容但可解释：
/// - 没有 `id` 的单词用单词本体派生 id；
/// - `level` 不认识就按 normal 处理；
/// - 重复 id、缺少 word 的记录会被跳过，并在 warnings 里说明跳过多少条；
/// - 缺 `format` 的裸 `{"words": [...]}` 也接受（方便手写词库）。
///
/// 真正的错误（不是 JSON、没有 words、格式版本比 App 新）直接抛 [BankFormatException]。
BankParseResult parseWordBank(
  String raw, {
  required String fallbackId,
  String? fallbackName,
}) {
  final dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException catch (e) {
    throw BankFormatException('不是合法的 JSON：${e.message}');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const BankFormatException('文件内容不是一个 JSON 对象');
  }

  final format = _text(decoded['format']);
  if (format != null && format != kBankFormat) {
    throw BankFormatException('这不是 LangoBei 词库文件（format = $format）');
  }
  final version = (decoded['formatVersion'] as num?)?.toInt();
  if (version != null && version > kBankFormatVersion) {
    throw BankFormatException(
      '这个文件来自更新的版本（格式 v$version），当前 App 只认到 v$kBankFormatVersion',
    );
  }

  final rawWords = decoded['words'];
  if (rawWords is! List || rawWords.isEmpty) {
    throw const BankFormatException('文件里没有单词（words 为空或缺失）');
  }

  final warnings = <String>[];
  final words = <Word>[];
  final seen = <String>{};
  var broken = 0;
  var duplicates = 0;
  var oddLevels = 0;

  for (final item in rawWords) {
    if (item is! Map<String, dynamic>) {
      broken++;
      continue;
    }
    final text = _text(item['word']);
    if (text == null) {
      broken++;
      continue;
    }
    final id = _text(item['id']) ?? deriveWordId(text);
    if (!seen.add(id)) {
      duplicates++;
      continue;
    }
    final level = _text(item['level']) ?? 'normal';
    if (!kLevels.contains(level)) oddLevels++;
    words.add(Word(
      id: id,
      word: text,
      phonetic: _text(item['phonetic']) ?? '',
      pos: _text(item['pos']) ?? '',
      meaning: _text(item['meaning']) ?? '',
      level: kLevels.contains(level) ? level : 'normal',
      tier: _text(item['tier']) ?? 'core',
    ));
  }

  if (words.isEmpty) {
    throw const BankFormatException('文件里没有可用的单词（每条记录都缺少 word 字段）');
  }
  if (broken > 0) warnings.add('跳过 $broken 条没有单词本体的记录');
  if (duplicates > 0) warnings.add('跳过 $duplicates 条重复的单词');
  if (oddLevels > 0) warnings.add('$oddLevels 个单词的分级不认识，按 normal 处理');

  final id = _text(decoded['id']) ?? fallbackId;
  final name = _text(decoded['name']) ?? fallbackName ?? id;

  return BankParseResult(
    WordBank(
      meta: WordBankMeta(
        id: id,
        name: name,
        subtitle: _text(decoded['subtitle']) ?? '${words.length} 词',
        description: _text(decoded['description']) ?? '',
        author: _text(decoded['author']) ?? '',
        version: _text(decoded['version']) ?? '1.0.0',
      ),
      words: words,
    ),
    warnings,
  );
}
