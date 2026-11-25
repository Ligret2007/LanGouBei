import 'dart:convert';

import 'dict_entry.dart';

/// 字典资源加载器：正式环境从 assets 读，测试里换成内存数据
typedef DictAssetLoader = Future<String?> Function(String asset);

/// 一次搜索命中的结果。[viaForm] 不为空表示用户搜的是变形词（gave），
/// 命中的是它的原形（give）。
class DictHit {
  final DictEntry entry;
  final String? viaForm;

  const DictHit(this.entry, {this.viaForm});
}

/// 内置词典：按首字母分片，用哪片加载哪片，搜一个字母不会把整个词典读进内存。
class DictService {
  DictService({required this.loader});

  static const String manifestAsset = 'assets/dict/manifest.json';
  static const String formsAsset = 'assets/dict/forms.json';
  static const String shardDir = 'assets/dict';

  final DictAssetLoader loader;

  final Map<String, Future<List<DictEntry>>> _shardFutures = {};
  Future<List<DictEntry>>? _allFuture;
  Future<Map<String, String>>? _formsFuture;
  int _total = 0;
  bool _manifestLoaded = false;

  /// 词典总词条数（manifest 里的），没加载出来是 0
  int get total => _total;

  bool get ready => _manifestLoaded;

  Future<void> loadManifest() async {
    if (_manifestLoaded) return;
    final raw = await loader(manifestAsset);
    if (raw != null && raw.isNotEmpty) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _total = (j['total'] as num?)?.toInt() ?? 0;
      } catch (_) {
        _total = 0;
      }
    }
    _manifestLoaded = true;
  }

  static String shardOf(String word) {
    if (word.isEmpty) return '_';
    final c = word[0].toLowerCase();
    return (c.codeUnitAt(0) >= 97 && c.codeUnitAt(0) <= 122) ? c : '_';
  }

  Future<List<DictEntry>> _shard(String letter) {
    return _shardFutures.putIfAbsent(letter, () async {
      final raw = await loader('$shardDir/$letter.json');
      if (raw == null || raw.isEmpty) return const <DictEntry>[];
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        return [
          for (final item in list) DictEntry.fromJson(item as Map<String, dynamic>),
        ];
      } catch (_) {
        return const <DictEntry>[];
      }
    });
  }

  Future<Map<String, String>> _forms() {
    return _formsFuture ??= () async {
      final raw = await loader(formsAsset);
      if (raw == null || raw.isEmpty) return <String, String>{};
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        return j.map((k, v) => MapEntry(k.toLowerCase(), v as String));
      } catch (_) {
        return <String, String>{};
      }
    }();
  }

  /// 精确查一个词；查不到再看它是不是某个词的变形
  Future<DictHit?> lookup(String word) async {
    final q = word.trim().toLowerCase();
    if (q.isEmpty) return null;
    final entries = await _shard(shardOf(q));
    for (final e in entries) {
      if (e.word.toLowerCase() == q) return DictHit(e);
    }
    final forms = await _forms();
    final base = forms[q];
    if (base == null) return null;
    final baseEntries = await _shard(shardOf(base));
    for (final e in baseEntries) {
      if (e.word.toLowerCase() == base) return DictHit(e, viaForm: q);
    }
    return null;
  }

  /// 全部词条（把所有分片拼起来）。只在「前缀没结果要找包含」时才用，代价是一次全量解析。
  Future<List<DictEntry>> _allEntries() {
    return _allFuture ??= () async {
      final out = <DictEntry>[];
      for (final c in 'abcdefghijklmnopqrstuvwxyz'.split('')) {
        out.addAll(await _shard(c));
      }
      out.addAll(await _shard('_'));
      return out;
    }();
  }

  /// 输入联想：先按前缀，前缀没结果再认变形词、退化成「包含」。
  Future<List<DictHit>> suggest(String query, {int limit = 40}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final entries = await _shard(shardOf(q));
    final prefix = <DictEntry>[];
    for (final e in entries) {
      final w = e.word.toLowerCase();
      if (w == q) {
        prefix.insert(0, e); // 完全命中的排第一
        continue;
      }
      if (w.startsWith(q)) prefix.add(e);
      if (prefix.length >= limit) break;
    }
    if (prefix.isNotEmpty) {
      return [for (final e in prefix.take(limit)) DictHit(e)];
    }

    // 前缀没结果：先看是不是变形词（gave / children），再退化成包含匹配
    final hits = <DictHit>[];
    final base = (await _forms())[q];
    if (base != null) {
      final hit = await lookup(base);
      if (hit != null) hits.add(DictHit(hit.entry, viaForm: q));
    }
    if (hits.length < limit) {
      for (final e in await _allEntries()) {
        if (e.word.toLowerCase() == q) continue;
        if (e.word.toLowerCase().contains(q)) hits.add(DictHit(e));
        if (hits.length >= limit) break;
      }
    }
    return hits;
  }

  /// 首字母导航用：这个字母下有多少词条（没加载的返回 -1）
  Future<int> countOf(String letter) async => (await _shard(letter)).length;
}
