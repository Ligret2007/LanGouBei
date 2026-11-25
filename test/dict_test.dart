import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:langobei/app_state.dart';
import 'package:langobei/bank/bank_registry.dart';
import 'package:langobei/bank/bank_source.dart';
import 'package:langobei/bank/bank_storage.dart';
import 'package:langobei/bank/word_bank.dart';
import 'package:langobei/dict/dict_entry.dart';
import 'package:langobei/dict/dict_service.dart';
import 'package:langobei/models/word.dart';
import 'package:shared_preferences/shared_preferences.dart';

Word wordOf(String id, String word) => Word(
      id: id,
      word: word,
      phonetic: '',
      pos: '',
      meaning: '释义',
      level: 'easy',
      tier: 'core',
    );

/// 假词典：三四个词，够验证前缀 / 包含 / 变形词三条路径
DictService fakeDict() {
  final data = <String, String>{
    DictService.manifestAsset: '{"total":3}',
    'assets/dict/g.json': jsonEncode([
      {'w': 'give', 't': 'vt. 给；赠送', 'p': 'ɡɪv', 'o': 'v', 'g': ['gk'], 'f': 400},
      {'w': 'given', 't': 'adj. 给定的', 'p': 'ˈɡɪvn'},
      {'w': 'giver', 't': 'n. 给予者'},
    ]),
    'assets/dict/z.json': jsonEncode([
      {'w': 'zeta', 't': 'n. 希腊字母 Z'},
    ]),
    DictService.formsAsset: jsonEncode({'gave': 'give', 'givin': 'give'}),
  };
  return DictService(loader: (asset) async => data[asset]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('词典词条', () {
    test('解析紧凑字段', () {
      final e = DictEntry.fromJson({
        'w': 'give',
        't': 'vt. 给；赠送',
        'p': 'ɡɪv',
        'o': 'v',
        'g': ['gk', 'cet4'],
        'c': 5,
        'x': 1,
        'f': 400,
        'b': 500,
        'e': 'p:gave/d:given/i:giving/3:gives',
      });
      expect(e.word, 'give');
      expect(e.phonetic, 'ɡɪv');
      expect(e.pos, 'v');
      expect(e.collins, 5);
      expect(e.oxford, isTrue);
      expect(e.tagLabels, ['高考', '四级']);
      expect(e.rank, 400);
      expect(e.level, 'easy', reason: '带高考标签的一律当 easy');
    });

    test('词频决定分级', () {
      DictEntry at(int rank) => DictEntry(word: 'x', translation: 'x', frq: rank);
      expect(at(2500).level, 'easy');
      expect(at(5000).level, 'normal');
      expect(at(15000).level, 'hard');
      expect(at(90000).level, 'extra');
    });

    test('词形变化拆成可读行', () {
      final e = DictEntry.fromJson({
        'w': 'give',
        't': '给',
        'e': 'p:gave/d:given/i:giving/3:gives/0:give',
      });
      final labels = e.forms.map((f) => '${f.label}:${f.form}').toList();
      expect(labels, contains('过去式:gave'));
      expect(labels, contains('过去分词:given'));
      expect(labels, contains('现在分词:giving'));
      expect(labels, contains('原形:give'));
    });

    test('转成 Word 时 id 和词库算法一致', () {
      final e = DictEntry.fromJson({'w': 'Look After', 't': '照顾'});
      expect(e.toWord().id, deriveWordId('Look After'));
      expect(dictWordId('Look After'), deriveWordId('Look After'));
    });
  });

  group('查词服务', () {
    test('前缀联想', () async {
      final service = fakeDict();
      await service.loadManifest();
      expect(service.total, 3);
      final hits = await service.suggest('gi');
      expect(hits.map((h) => h.entry.word), ['give', 'given', 'giver']);
    });

    test('完全命中的排第一个', () async {
      final hits = await fakeDict().suggest('give');
      expect(hits.first.entry.word, 'give');
      expect(hits.first.viaForm, isNull);
    });

    test('前缀查不到就退化成包含匹配', () async {
      final hits = await fakeDict().suggest('iv');
      expect(hits.map((h) => h.entry.word), containsAll(['give', 'given', 'giver']));
    });

    test('变形词反查原形', () async {
      final hits = await fakeDict().suggest('gave');
      expect(hits, hasLength(1));
      expect(hits.first.entry.word, 'give');
      expect(hits.first.viaForm, 'gave');
    });

    test('查不到的词返回空', () async {
      expect(await fakeDict().suggest('qqqq'), isEmpty);
      expect(await fakeDict().suggest(''), isEmpty);
      expect(await fakeDict().lookup('nope'), isNull);
    });

    test('资源缺失时安全降级', () async {
      final service = DictService(loader: (asset) async => null);
      await service.loadManifest();
      expect(service.total, 0);
      expect(await service.suggest('give'), isEmpty);
    });
  });

  group('错题本', () {
    WordBankRegistry registryOf(List<Word> bankWords) {
      final meta =
          const WordBankMeta(id: 'core', name: '高考：我是菜鸟', subtitle: '测试库', builtin: true);
      return WordBankRegistry(
        storage: MemoryBankStorage(),
        builtins: [BankSummary(meta: meta, wordCount: bankWords.length)],
        sources: {'core': MemoryBankSource(meta: meta, words: bankWords)},
      );
    }

    Future<AppState> newState(List<Word> bankWords) async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState.withRegistry(registryOf(bankWords));
      await s.load();
      return s;
    }

    test('词库外的词也能加进来，并连释义一起存', () async {
      final s = await newState([wordOf('a', 'apple')]);
      final outside = DictEntry.fromJson({
        'w': 'zeta',
        't': 'n. 希腊字母 Z',
        'p': 'ˈziːtə',
      }).toWord();

      expect(s.wrongCount, 0);
      await s.addToWrongBook(outside);

      expect(s.wrongCount, 1);
      expect(s.isInWrongBook(outside.id), isTrue);
      final saved = s.wrongBookWords.single;
      expect(saved.word, 'zeta');
      expect(saved.meaning, 'n. 希腊字母 Z');
      expect(saved.phonetic, 'ˈziːtə');
      expect((s.toSnapshot()['extra'] as Map), contains(outside.id));
    });

    test('词库内的词加进来不会重复存一份', () async {
      final apple = wordOf('apple', 'apple');
      final s = await newState([apple]);
      await s.addToWrongBook(apple);
      expect(s.wrongCount, 1);
      expect((s.toSnapshot()['extra'] as Map), isEmpty);
      expect(s.wrongBookWords.single.id, 'apple');
    });

    test('移出错题本，进度还在', () async {
      final apple = wordOf('apple', 'apple');
      final s = await newState([apple]);
      await s.addToWrongBook(apple);
      await s.removeFromWrongBook('apple');
      expect(s.wrongCount, 0);
      expect(s.isInWrongBook('apple'), isFalse);
      expect(s.progress['apple'], isNotNull);
    });

    test('重复加入是幂等的', () async {
      final s = await newState([wordOf('a', 'apple')]);
      final w = wordOf('zzz', 'zzz');
      await s.addToWrongBook(w);
      await s.addToWrongBook(w);
      expect(s.wrongCount, 1);
    });

    test('加进错题本的词不再出现在知新队列里', () async {
      final words = [wordOf('a', 'apple'), wordOf('b', 'banana')];
      final s = await newState(words);
      await s.addToWrongBook(words.first);
      final queue = s.pickStudyWords(size: 20, seed: 1).map((w) => w.id).toList();
      expect(queue, isNot(contains('a')));
      expect(queue, contains('b'));
    });
  });
}
