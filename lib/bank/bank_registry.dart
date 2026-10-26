import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'bank_source.dart';
import 'bank_storage.dart';
import 'word_bank.dart';

/// 内置词库清单。新增一个随包词库只要在这里加一条，不用改 Dart 代码。
const String kBankManifestAsset = 'assets/banks/index.json';

/// 界面用的词库摘要：不加载单词就能显示名字、词数
class BankSummary {
  final WordBankMeta meta;

  /// 词数（内置库来自清单，导入库来自索引）
  final int wordCount;

  const BankSummary({required this.meta, required this.wordCount});

  String get id => meta.id;
  String get name => meta.name;
  bool get builtin => meta.builtin;

  /// 「3014 词 · 基础到进阶，覆盖高考高频」
  String get detail {
    final count = wordCount > 0 ? '$wordCount 词' : '';
    if (count.isEmpty) return meta.subtitle;
    return meta.subtitle.isEmpty ? count : '$count · ${meta.subtitle}';
  }
}

/// 词库注册表：把「内置」和「用户导入」两类来源合成一份对界面呈现的列表，
/// 并负责导入、删除时的落盘。
///
/// 启动时只读两个小文件（资源清单 + 导入索引），不会把所有词库都解析一遍；
/// 只有真正切到某个库时才加载它的单词。
class WordBankRegistry {
  final BankStorage storage;
  final List<BankSummary> builtins;
  final Map<String, BankSummary> _imported = {};

  /// 测试注入用：给某些 id 指定现成的来源，绕开资源文件
  final Map<String, WordBankSource> sources;

  WordBankRegistry({
    required this.storage,
    required this.builtins,
    this.sources = const {},
  });

  /// 从 assets/banks/index.json 建注册表，并读入已导入词库的索引
  static Future<WordBankRegistry> fromAssets({
    BankStorage storage = const PlatformBankStorage(),
  }) async {
    final raw = await rootBundle.loadString(kBankManifestAsset);
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final builtins = <BankSummary>[];
    for (final item in (data['banks'] as List<dynamic>? ?? const [])) {
      if (item is! Map<String, dynamic>) continue;
      final id = (item['id'] as String?)?.trim();
      final asset = (item['asset'] as String?)?.trim();
      if (id == null || id.isEmpty || asset == null || asset.isEmpty) continue;
      builtins.add(BankSummary(
        meta: WordBankMeta(
          id: id,
          name: (item['name'] as String?)?.trim() ?? id,
          subtitle: (item['subtitle'] as String?)?.trim() ?? '',
          description: (item['description'] as String?)?.trim() ?? '',
          author: (item['author'] as String?)?.trim() ?? '',
          version: (item['version'] as String?)?.trim() ?? '1.0.0',
          builtin: true,
          assetPath: asset,
          tierFilter: (item['tier'] as String?)?.trim(),
        ),
        wordCount: (item['wordCount'] as num?)?.toInt() ?? 0,
      ));
    }
    final registry = WordBankRegistry(storage: storage, builtins: builtins);
    await registry.reloadIndex();
    return registry;
  }

  /// 重读导入库索引（索引坏了就当作没有导入库，不影响内置库）
  Future<void> reloadIndex() async {
    _imported.clear();
    final raw = await storage.readIndex();
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      for (final item in (data['banks'] as List<dynamic>? ?? const [])) {
        if (item is! Map<String, dynamic>) continue;
        final id = (item['id'] as String?)?.trim();
        if (id == null || id.isEmpty) continue;
        _imported[id] = BankSummary(
          meta: WordBankMeta(
            id: id,
            name: (item['name'] as String?)?.trim() ?? id,
            subtitle: (item['subtitle'] as String?)?.trim() ?? '',
            description: (item['description'] as String?)?.trim() ?? '',
            author: (item['author'] as String?)?.trim() ?? '',
            version: (item['version'] as String?)?.trim() ?? '1.0.0',
          ),
          wordCount: (item['wordCount'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (_) {
      _imported.clear();
    }
  }

  /// 全部词库：内置在前，导入的按导入顺序
  List<BankSummary> get all => [...builtins, ..._imported.values];

  List<BankSummary> get imported => _imported.values.toList();

  BankSummary? byId(String id) {
    for (final b in all) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// 取加载器；id 不存在返回 null
  WordBankSource? sourceOf(String id) {
    final injected = sources[id];
    if (injected != null) return injected;
    final summary = byId(id);
    if (summary == null) return null;
    if (summary.builtin) return AssetBankSource(summary.meta);
    return ImportedBankSource(meta: summary.meta, readRaw: () => storage.read(id));
  }

  /// 导入一份词库文本（从文件或粘贴）。成功后已落盘并更新索引。
  ///
  /// [filename] 只用来给「没写 id / 没写 name」的文件兜底取名。
  Future<BankParseResult> import(String raw, {String? filename}) async {
    final base = _filenameBase(filename);
    final result = parseWordBank(
      raw,
      fallbackId: _uniqueId(base ?? 'imported'),
      fallbackName: base,
    );

    // id 不能和已有库（含内置库）撞
    var id = _sanitizeId(result.bank.id);
    if (byId(id) != null) id = _uniqueId(id);

    final bank = WordBank(
      meta: WordBankMeta(
        id: id,
        name: result.bank.name,
        subtitle: result.bank.meta.subtitle,
        description: result.bank.meta.description,
        author: result.bank.meta.author,
        version: result.bank.meta.version,
      ),
      words: result.bank.words,
    );

    await storage.write(id, bank.encode(pretty: false));
    _imported[id] = BankSummary(meta: bank.meta, wordCount: bank.wordCount);
    await _saveIndex();
    return BankParseResult(bank, result.warnings);
  }

  /// 删除导入的词库；内置库不能删
  Future<void> remove(String id) async {
    if (!_imported.containsKey(id)) {
      throw StateError('内置词库不能删除');
    }
    await storage.delete(id);
    _imported.remove(id);
    await _saveIndex();
  }

  Future<void> _saveIndex() async {
    final data = <String, dynamic>{
      'format': 'langobei-bank-index',
      'formatVersion': 1,
      'banks': [
        for (final b in _imported.values)
          {
            'id': b.id,
            'name': b.name,
            'subtitle': b.meta.subtitle,
            'description': b.meta.description,
            'author': b.meta.author,
            'version': b.meta.version,
            'wordCount': b.wordCount,
          },
      ],
    };
    await storage.writeIndex(jsonEncode(data));
  }

  static String _sanitizeId(String id) {
    final s = id
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9_-]+'), '-')
        .replaceAll(RegExp('^-+|-+\$'), '');
    return s.isEmpty ? 'imported' : s;
  }

  String _uniqueId(String base) {
    final clean = _sanitizeId(base);
    var candidate = clean;
    var n = 2;
    while (byId(candidate) != null) {
      candidate = '$clean-$n';
      n++;
    }
    return candidate;
  }

  static String? _filenameBase(String? filename) {
    if (filename == null) return null;
    final name = filename.split(RegExp(r'[/\\]')).last;
    final dot = name.lastIndexOf('.');
    final base = (dot > 0 ? name.substring(0, dot) : name).trim();
    return base.isEmpty ? null : base;
  }
}
