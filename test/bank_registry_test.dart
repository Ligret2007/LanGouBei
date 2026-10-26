import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:langobei/bank/bank_registry.dart';
import 'package:langobei/bank/bank_source.dart';
import 'package:langobei/bank/bank_storage.dart';
import 'package:langobei/bank/word_bank.dart';

String bankJson(String id, String name, List<String> words) => jsonEncode({
      'format': kBankFormat,
      'formatVersion': kBankFormatVersion,
      'id': id,
      'name': name,
      'subtitle': '${words.length} 词',
      'words': [
        for (final w in words) {'word': w, 'meaning': '$w 的释义'},
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('词库注册表', () {
    test('内置清单能读出两个高考词库', () async {
      final storage = MemoryBankStorage();
      final registry = await WordBankRegistry.fromAssets(storage: storage);

      expect(registry.builtins.map((b) => b.id), ['core', 'ext']);
      expect(registry.builtins.first.name, '高考：我是菜鸟');
      expect(registry.builtins.first.wordCount, 3014);
      expect(registry.builtins.last.wordCount, 3540);
      expect(registry.builtins.first.detail, '3014 词 · 基础到进阶，覆盖高考高频');
      expect(registry.imported, isEmpty);
      expect(registry.all.length, 2);
    });

    test('内置词库真能加载，且 tier 过滤正确', () async {
      final registry = await WordBankRegistry.fromAssets(storage: MemoryBankStorage());

      final core = await registry.sourceOf('core')!.load();
      final ext = await registry.sourceOf('ext')!.load();

      expect(core.wordCount, 3014);
      expect(ext.wordCount, 3540);
      expect(core.words.every((w) => w.tier == 'core'), isTrue);
      expect(core.words.first.word.isNotEmpty, isTrue);
      expect(core.words.first.meaning.isNotEmpty, isTrue);
      // 菜鸟是大神的子集
      final coreIds = core.words.map((w) => w.id).toSet();
      expect(ext.words.map((w) => w.id).toSet().containsAll(coreIds), isTrue);
    });

    test('导入后能列出、能加载、能持久化', () async {
      final storage = MemoryBankStorage();
      final registry = await WordBankRegistry.fromAssets(storage: storage);

      final result = await registry.import(
        bankJson('my', '我的四级词', ['abandon', 'benefit', 'crucial']),
        filename: 'cet4.json',
      );
      expect(result.bank.id, 'my');
      expect(result.bank.wordCount, 3);
      expect(result.warnings, isEmpty);

      expect(registry.imported.length, 1);
      expect(registry.all.length, 3);
      expect(storage.banks.containsKey('my'), isTrue);
      expect(storage.index, contains('我的四级词'));

      final loaded = await registry.sourceOf('my')!.load();
      expect(loaded.wordCount, 3);
      expect(loaded.words[1].word, 'benefit');
      expect(loaded.words[1].meaning, 'benefit 的释义');
    });

    test('重建注册表后导入库还在（走同一份存储）', () async {
      final storage = MemoryBankStorage();
      final first = await WordBankRegistry.fromAssets(storage: storage);
      await first.import(bankJson('my', '我的词库', ['alpha']));

      final second = WordBankRegistry(
        storage: storage,
        builtins: first.builtins,
      );
      await second.reloadIndex();

      expect(second.imported.map((b) => b.id), ['my']);
      expect(second.byId('my')!.wordCount, 1);
    });

    test('导入的 id 撞内置库时自动改名', () async {
      final storage = MemoryBankStorage();
      final registry = await WordBankRegistry.fromAssets(storage: storage);

      final result = await registry.import(bankJson('core', '山寨菜鸟', ['x']));
      expect(result.bank.id, isNot('core'));
      expect(registry.byId('core')!.name, '高考：我是菜鸟');
      expect(registry.imported.single.name, '山寨菜鸟');
    });

    test('同名文件导入两次会拿到不同 id', () async {
      final storage = MemoryBankStorage();
      final registry = await WordBankRegistry.fromAssets(storage: storage);

      final a = await registry.import(bankJson('imported', 'A', ['x']), filename: 'words.json');
      final b = await registry.import(bankJson('imported', 'B', ['y']), filename: 'words.json');
      expect(a.bank.id, isNot(b.bank.id));
      expect(registry.imported.length, 2);
    });

    test('删除导入库后加载会报错，内置库删不掉', () async {
      final storage = MemoryBankStorage();
      final registry = await WordBankRegistry.fromAssets(storage: storage);
      await registry.import(bankJson('tmp', '临时', ['x']));

      await registry.remove('tmp');
      expect(registry.imported, isEmpty);
      expect(storage.banks.containsKey('tmp'), isFalse);
      expect(registry.sourceOf('tmp'), isNull);
      expect(() => registry.remove('core'), throwsStateError);
    });

    test('索引坏掉时只丢导入库，内置库照常', () async {
      final storage = MemoryBankStorage();
      storage.index = '{ 这不是 JSON';
      final registry = await WordBankRegistry.fromAssets(storage: storage);

      expect(registry.builtins.length, 2);
      expect(registry.imported, isEmpty);
    });

    test('没有 id 和 name 的文件用文件名兜底', () async {
      final storage = MemoryBankStorage();
      final registry = await WordBankRegistry.fromAssets(storage: storage);

      final raw = jsonEncode({
        'words': [
          {'word': 'alpha'},
        ],
      });
      final result = await registry.import(raw, filename: 'My Words v2.json');
      expect(result.bank.id, 'my-words-v2');
      expect(result.bank.name, 'My Words v2');
    });

    test('summary 的加载器类型：内置是 Asset，导入是 Imported', () async {
      final storage = MemoryBankStorage();
      final registry = await WordBankRegistry.fromAssets(storage: storage);
      await registry.import(bankJson('mine', '我的', ['x']));

      expect(registry.sourceOf('core'), isA<AssetBankSource>());
      expect(registry.sourceOf('mine'), isA<ImportedBankSource>());
      expect(registry.sourceOf('nope'), isNull);
    });
  });
}
