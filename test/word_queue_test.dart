import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:langobei/app_state.dart';
import 'package:langobei/bank/bank_registry.dart';
import 'package:langobei/bank/bank_storage.dart';
import 'package:langobei/models/word.dart';
import 'package:langobei/word_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

Word w(String id, String level) => Word(
      id: id,
      word: id,
      phonetic: '/x/',
      pos: 'n.',
      meaning: '释义',
      level: level,
      tier: 'core',
    );

/// 造一个按占比分桶的词表，返回 (桶, 每级词数)
Map<String, List<Word>> bucketsOf(Map<String, int> sizes) => {
      for (final e in sizes.entries)
        e.key: [for (var i = 0; i < e.value; i++) w('${e.key}$i', e.key)],
    };

void main() {
  group('buildBalancedQueue', () {
    const sizes = {'easy': 52, 'normal': 29, 'hard': 19};

    test('任意前缀里各难度都贴着它在词库里的占比（误差不超过 1 张）', () {
      final buckets = bucketsOf(sizes);
      final queue = buildBalancedQueue(buckets, rng: Random(2026));
      expect(queue.length, 100);

      final counts = <String, int>{for (final l in sizes.keys) l: 0};
      for (var i = 0; i < queue.length; i++) {
        final level = queue[i].level;
        counts[level] = counts[level]! + 1;
        for (final l in sizes.keys) {
          final ideal = (i + 1) * sizes[l]! / 100;
          expect((counts[l]! - ideal).abs(), lessThanOrEqualTo(1.0),
              reason: '第 ${i + 1} 张时 $l 出了 ${counts[l]}，按占比应出 ${ideal.toStringAsFixed(2)}');
        }
      }
      expect(counts, sizes, reason: '全部词都要出完，一个不少');
    });

    test('不会连着来一长串同难度', () {
      final queue = buildBalancedQueue(bucketsOf(sizes), rng: Random(7));
      var maxRun = 1;
      var run = 1;
      for (var i = 1; i < queue.length; i++) {
        run = queue[i].level == queue[i - 1].level ? run + 1 : 1;
        if (run > maxRun) maxRun = run;
      }
      expect(maxRun, lessThanOrEqualTo(4), reason: '最长连串 $maxRun 张同难度');
    });

    test('桶内顺序原样保留（桶里已经排好新词在前 / 最久没复习在前）', () {
      final queue = buildBalancedQueue(bucketsOf(sizes), rng: Random(1));
      for (final level in sizes.keys) {
        final got = queue.where((x) => x.level == level).map((x) => x.id).toList();
        final want = [for (var i = 0; i < sizes[level]!; i++) '$level$i'];
        expect(got, want);
      }
    });

    test('空桶、单一级、缺分级都能正常出队', () {
      expect(buildBalancedQueue({'easy': const [], 'normal': const []}), isEmpty);
      final only = buildBalancedQueue({'hard': [w('h1', 'hard'), w('h2', 'hard')]});
      expect(only.map((x) => x.id).toList(), ['h1', 'h2']);
      // 没有 extra 桶时，只出剩下三级
      final noExtra = buildBalancedQueue(bucketsOf({'easy': 2, 'normal': 1}));
      expect(noExtra.length, 3);
      expect(noExtra.where((x) => x.level == 'extra'), isEmpty);
    });

    test('两级一样多时严格交替（并列也优先换难度）', () {
      for (final seed in [1, 2, 3, 4, 5]) {
        final q = buildBalancedQueue(bucketsOf({'easy': 10, 'normal': 10}), rng: Random(seed));
        expect(q.length, 20);
        for (var i = 1; i < q.length; i++) {
          expect(q[i].level, isNot(q[i - 1].level), reason: 'seed=$seed 第 $i 张重复了难度');
        }
      }
    });
  });

  group('bucketByLevel', () {
    test('按分级分桶，未知分级算 normal', () {
      final buckets = bucketByLevel([w('a', 'easy'), w('b', 'normal'), w('c', 'extra'), w('d', '')]);
      expect(buckets['easy']!.map((x) => x.id), ['a']);
      expect(buckets['normal']!.map((x) => x.id), ['b', 'd']);
      expect(buckets['hard'], isEmpty);
      expect(buckets['extra']!.map((x) => x.id), ['c']);
    });
  });

  group('真实词库', () {
    test('菜鸟库前 20 张：难度分布贴近整库占比，而且不是字母序', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});

      final s = AppState.withRegistry(
        await WordBankRegistry.fromAssets(storage: MemoryBankStorage()),
      );
      await s.load();
      expect(s.allWords.length, 3014, reason: '现在只加载当前词库这一份');
      expect(s.bankTotal, 3014, reason: '默认菜鸟库');

      final queue = s.pickStudyWords(size: 20, seed: 1234);
      expect(queue.length, 20);

      final counts = <String, int>{};
      for (final word in queue) {
        counts[word.level] = (counts[word.level] ?? 0) + 1;
      }
      final library = s.levelCounts;
      for (final level in kLevels) {
        final ideal = 20 * (library[level] ?? 0) / s.bankTotal;
        expect((counts[level] ?? 0) - ideal, lessThanOrEqualTo(1.0),
            reason: '$level 实际 ${counts[level] ?? 0} 张，按占比应约 ${ideal.toStringAsFixed(1)} 张');
      }
      expect(s.levelCounts['extra'], 0, reason: '菜鸟库不含 extra');

      // 老实现是纯字母序（abandon → ability → …），新实现不该再是
      final words = [for (final x in queue) x.word];
      final alphabetical = [...words]..sort();
      expect(words, isNot(alphabetical));

      // 同一个种子必须复现同一条队列
      expect([for (final x in s.pickStudyWords(size: 20, seed: 1234)) x.id],
          [for (final x in queue) x.id]);
    });
  });
}
