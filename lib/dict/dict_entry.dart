import 'dart:math' as math;

import '../bank/word_bank.dart';
import '../models/word.dart';

/// 一条 ECDICT 词条。
///
/// 字段名为了省体积在 JSON 里做了缩写（见 tool/build_dict.py）：
/// w=word / t=translation / p=phonetic / o=pos / g=tags / c=collins / x=oxford
/// f=frq / b=bnc / e=exchange
class DictEntry {
  final String word;
  final String translation;
  final String phonetic;
  final String pos;
  final String exchange;
  final bool oxford;
  final int collins;
  final int frq;
  final int bnc;
  final List<String> tags;

  const DictEntry({
    required this.word,
    required this.translation,
    this.phonetic = '',
    this.pos = '',
    this.exchange = '',
    this.oxford = false,
    this.collins = 0,
    this.frq = 0,
    this.bnc = 0,
    this.tags = const [],
  });

  factory DictEntry.fromJson(Map<String, dynamic> j) => DictEntry(
        word: j['w'] as String? ?? '',
        translation: j['t'] as String? ?? '',
        phonetic: j['p'] as String? ?? '',
        pos: j['o'] as String? ?? '',
        exchange: j['e'] as String? ?? '',
        oxford: (j['x'] as num?)?.toInt() == 1,
        collins: (j['c'] as num?)?.toInt() ?? 0,
        frq: (j['f'] as num?)?.toInt() ?? 0,
        bnc: (j['b'] as num?)?.toInt() ?? 0,
        tags: ((j['g'] as List?) ?? const []).map((e) => e as String).toList(),
      );

  /// 词频名次：两个语料库取靠前的那个，没有就排到最后
  int get rank {
    final f = frq > 0 ? frq : 1 << 30;
    final b = bnc > 0 ? bnc : 1 << 30;
    return math.min(f, b);
  }

  /// 和词库里的 easy / normal / hard / extra 对齐，错题本和词库共用配色
  String get level {
    if (tags.contains('gk') || tags.contains('zk')) return 'easy';
    final r = rank;
    if (r <= 3000) return 'easy';
    if (r <= 8000) return 'normal';
    if (r <= 20000) return 'hard';
    return 'extra';
  }

  /// 考试标签转成中文短标，界面上当小胶囊用
  List<String> get tagLabels {
    final out = <String>[];
    for (final t in tags) {
      final label = switch (t) {
        'zk' => '中考',
        'gk' => '高考',
        'cet4' => '四级',
        'cet6' => '六级',
        'ky' => '考研',
        'toefl' => '托福',
        'ielts' => '雅思',
        'gre' => 'GRE',
        _ => null,
      };
      if (label != null) out.add(label);
    }
    return out;
  }

  /// 词形变化拆成「过去式: xxx」这样的可读行
  List<({String label, String form})> get forms {
    if (exchange.isEmpty) return const [];
    final out = <({String label, String form})>[];
    for (final item in exchange.split('/')) {
      final i = item.indexOf(':');
      if (i <= 0) continue;
      final kind = item.substring(0, i);
      final form = item.substring(i + 1).trim();
      if (form.isEmpty) continue;
      final label = switch (kind) {
        'p' => '过去式',
        'd' => '过去分词',
        'i' => '现在分词',
        '3' => '第三人称',
        'r' => '比较级',
        't' => '最高级',
        's' => '复数',
        '0' => '原形',
        '1' => '原形变形',
        _ => null,
      };
      if (label != null) out.add((label: label, form: form));
    }
    return out;
  }

  /// 转成词库里的 Word，加入错题本 / 学习时用
  Word toWord() => Word(
        id: dictWordId(word),
        word: word,
        phonetic: phonetic,
        pos: pos,
        meaning: translation,
        level: level,
        tier: 'core',
      );
}

/// 词条 id：和词库里算出来的 id 一致，这样同一个词跨词库、跨查词都是同一条记录
String dictWordId(String word) => deriveWordId(word);
