/// 知新队列的排法：伪随机 + 按分级占比均匀交错
///
/// 解决的问题：以前队列是按字母排的（`abandon` → `ability` → …），既好猜，也容易
/// 连着好几张都是同一个难度。现在改成「按各难度在词库里的占比，均匀地摊开」。
library;

import 'dart:math';

import 'models/word.dart';

/// 按分级把词分桶；分级不在 [kLevels] 里的（老数据 / 脏数据）算 normal
Map<String, List<Word>> bucketByLevel(Iterable<Word> words) {
  final buckets = <String, List<Word>>{for (final l in kLevels) l: <Word>[]};
  for (final w in words) {
    final level = buckets.containsKey(w.level) ? w.level : 'normal';
    buckets[level]!.add(w);
  }
  return buckets;
}

/// 把分好桶（桶内已排好序）的词交错成一条队列，让各分级均匀出现。
///
/// 每一步都挑「欠账最多」的那一级：按它在候选词里的占比摊到当前位置，理论上该出几个
/// 减去实际出了几个，差值最大的先出。这样**任意前缀**里各分级的比例都贴着它们在词库
/// 里的占比 —— 既不会连着来一串同难度，也不会为了「四种难度都露面」把低频词硬塞进来。
///
/// 并列时优先换一个别的难度（避免刚出过的难度立刻再来一张），仍有多个可选才用 [rng]
/// 随机挑一个，所以顺序看起来是随机的，但同一个种子必然得到同一条队列。
List<Word> buildBalancedQueue(Map<String, List<Word>> buckets, {Random? rng}) {
  final random = rng ?? Random();
  final sizes = <String, int>{};
  final cursor = <String, int>{};
  var total = 0;
  for (final level in kLevels) {
    final n = buckets[level]?.length ?? 0;
    sizes[level] = n;
    cursor[level] = 0;
    total += n;
  }

  final out = <Word>[];
  while (out.length < total) {
    String? pick;
    var best = double.negativeInfinity;
    var tied = <String>[];
    for (final level in kLevels) {
      final n = sizes[level]!;
      final used = cursor[level]!;
      if (n == 0 || used >= n) continue;
      final due = (out.length + 1) * n / total - used;
      if (due > best + 1e-9) {
        best = due;
        tied = [level];
      } else if ((due - best).abs() <= 1e-9) {
        tied.add(level);
      }
    }
    if (tied.isEmpty) break;

    // 并列时先换难度：刚出过的这一级能往后放就往后放
    var choices = tied;
    if (tied.length > 1 && out.isNotEmpty) {
      final previous = out.last.level;
      final others = tied.where((l) => l != previous).toList();
      if (others.isNotEmpty) choices = others;
    }
    pick = choices.length == 1 ? choices.first : choices[random.nextInt(choices.length)];
    out.add(buckets[pick]![cursor[pick]!]);
    cursor[pick] = cursor[pick]! + 1;
  }
  return out;
}
