import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:langobei/bank/word_bank.dart';
import 'package:langobei/models/word.dart';

Word word(String id, String text, {String level = 'easy', String meaning = '释义'}) => Word(
      id: id,
      word: text,
      phonetic: '/x/',
      pos: 'n.',
      meaning: meaning,
      level: level,
      tier: 'core',
    );

void main() {
  group('词库格式', () {
    test('导出再导入，内容完全一致', () {
      final bank = WordBank(
        meta: const WordBankMeta(
          id: 'my-bank',
          name: '我的词库',
          subtitle: '2 词',
          description: '手写的一份',
          author: 'Ligret',
        ),
        words: [word('a', 'apple'), word('banana', 'banana')],
      );

      final result = parseWordBank(bank.encode(), fallbackId: 'whatever');

      expect(result.bank.id, 'my-bank');
      expect(result.bank.name, '我的词库');
      expect(result.bank.meta.author, 'Ligret');
      expect(result.bank.wordCount, 2);
      expect(result.bank.words.first.word, 'apple');
      expect(result.bank.words.first.phonetic, '/x/');
      expect(result.bank.words.last.meaning, '释义');
      expect(result.warnings, isEmpty);
    });

    test('导出的文件带格式标识与版本', () {
      final bank = WordBank(
        meta: const WordBankMeta(id: 'b', name: 'B'),
        words: [word('w1', 'word')],
      );
      final json = jsonDecode(bank.encode()) as Map<String, dynamic>;
      expect(json['format'], kBankFormat);
      expect(json['formatVersion'], kBankFormatVersion);
      expect(json['wordCount'], 1);
    });

    test('裸 {words: []} 也能导入，用兜底名字', () {
      final raw = jsonEncode({
        'words': [
          {'word': 'abandon', 'meaning': '放弃'},
          {'word': 'benefit', 'meaning': '好处'},
        ],
      });
      final result = parseWordBank(raw, fallbackId: 'pasted', fallbackName: '粘贴进来的');
      expect(result.bank.id, 'pasted');
      expect(result.bank.name, '粘贴进来的');
      expect(result.bank.wordCount, 2);
      expect(result.bank.meta.subtitle, '2 词');
    });

    test('没有 id 的单词按单词本体派生 id', () {
      final raw = jsonEncode({
        'words': [
          {'word': 'Look Up'},
          {'word': 'look-up'},
        ],
      });
      final result = parseWordBank(raw, fallbackId: 'x');
      expect(result.bank.words.map((w) => w.id), ['look-up']);
      expect(result.bank.wordCount, 1);
      expect(result.warnings.any((w) => w.contains('重复')), isTrue);
    });

    test('重复 id 被跳过并给出提示', () {
      final raw = jsonEncode({
        'words': [
          {'id': 'same', 'word': 'a'},
          {'id': 'same', 'word': 'b'},
          {'id': 'other', 'word': 'c'},
        ],
      });
      final result = parseWordBank(raw, fallbackId: 'x');
      expect(result.bank.wordCount, 2);
      expect(result.warnings.join(), contains('重复'));
    });

    test('不认识的分级按 normal 处理并提示', () {
      final raw = jsonEncode({
        'words': [
          {'word': 'a', 'level': 'legendary'},
          {'word': 'b', 'level': 'hard'},
        ],
      });
      final result = parseWordBank(raw, fallbackId: 'x');
      expect(result.bank.words.first.level, 'normal');
      expect(result.bank.words.last.level, 'hard');
      expect(result.warnings.join(), contains('分级'));
    });

    test('不是 JSON 时报错', () {
      expect(
        () => parseWordBank('not json at all', fallbackId: 'x'),
        throwsA(isA<BankFormatException>()),
      );
    });

    test('没有 words 字段时报错', () {
      expect(
        () => parseWordBank(jsonEncode({'id': 'x', 'words': []}), fallbackId: 'x'),
        throwsA(isA<BankFormatException>()),
      );
    });

    test('格式版本比 App 新时报错', () {
      final raw = jsonEncode({
        'format': kBankFormat,
        'formatVersion': kBankFormatVersion + 1,
        'words': [
          {'word': 'a'},
        ],
      });
      expect(
        () => parseWordBank(raw, fallbackId: 'x'),
        throwsA(isA<BankFormatException>()),
      );
    });

    test('其它 format 的不是本 App 的文件', () {
      final raw = jsonEncode({
        'format': 'anki',
        'words': [
          {'word': 'a'},
        ],
      });
      expect(
        () => parseWordBank(raw, fallbackId: 'x'),
        throwsA(isA<BankFormatException>()),
      );
    });

    test('Word.toJson 省略空字段', () {
      const w = Word(
        id: 'a',
        word: 'apple',
        phonetic: '',
        pos: '',
        meaning: '',
        level: 'easy',
        tier: 'core',
      );
      final json = w.toJson();
      expect(json.containsKey('phonetic'), isFalse);
      expect(json.containsKey('pos'), isFalse);
      expect(json.containsKey('meaning'), isFalse);
      expect(json['word'], 'apple');
    });
  });
}
