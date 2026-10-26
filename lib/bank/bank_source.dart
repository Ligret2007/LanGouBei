import 'package:flutter/services.dart' show rootBundle;

import '../models/word.dart';
import 'word_bank.dart';

/// 词库来源接口。
///
/// 一个来源只负责「把一份词库读出来」，不关心存在哪、怎么被选中。
/// 目前两种实现：随包内置的资源词库、用户导入的文件词库。
/// 以后要加在线词库或系统分享进来的词库，实现这个接口就行，界面和状态层不用改。
abstract class WordBankSource {
  /// 稳定标识，用于持久化「当前选的哪个库」
  String get id;

  /// 不加载单词就能拿到的元信息
  WordBankMeta get meta;

  /// 真正加载（可能较慢，界面要有加载态）
  Future<WordBank> load();
}

/// 内置词库：从 assets 读。
///
/// 高考词库用一个资源文件装 3540 个词，靠 [WordBankMeta.tierFilter]
/// 拆成「菜鸟（core）」和「大神（全部）」两个库。
class AssetBankSource implements WordBankSource {
  @override
  final WordBankMeta meta;

  const AssetBankSource(this.meta);

  @override
  String get id => meta.id;

  @override
  Future<WordBank> load() async {
    final path = meta.assetPath;
    if (path == null || path.isEmpty) {
      throw BankFormatException('内置词库 ${meta.name} 没有配置资源路径');
    }
    final raw = await rootBundle.loadString(path);
    final result = parseWordBank(raw, fallbackId: meta.id, fallbackName: meta.name);
    final filter = meta.tierFilter;
    final words = filter == null
        ? result.bank.words
        : [
            for (final w in result.bank.words)
              if (w.tier == filter) w,
          ];
    if (words.isEmpty) {
      throw BankFormatException('词库 ${meta.name} 里没有单词');
    }
    return WordBank(meta: meta, words: words);
  }
}

/// 用户导入的词库：内容存在 App 私有目录里，读的时候现取。
class ImportedBankSource implements WordBankSource {
  @override
  final WordBankMeta meta;

  final Future<String?> Function() readRaw;

  ImportedBankSource({required this.meta, required this.readRaw});

  @override
  String get id => meta.id;

  @override
  Future<WordBank> load() async {
    final raw = await readRaw();
    if (raw == null || raw.isEmpty) {
      throw BankFormatException('词库 ${meta.name} 的文件已经不在了');
    }
    final result = parseWordBank(raw, fallbackId: meta.id, fallbackName: meta.name);
    return WordBank(meta: meta, words: result.bank.words);
  }
}

/// 内存里的词库：测试注入用，不读文件、不碰原生通道。
class MemoryBankSource implements WordBankSource {
  @override
  final WordBankMeta meta;

  final List<Word> words;

  MemoryBankSource({required this.meta, required this.words});

  @override
  String get id => meta.id;

  @override
  Future<WordBank> load() async => WordBank(meta: meta, words: words);
}
