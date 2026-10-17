import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/word.dart';
import '../theme.dart';
import '../widgets/flip_card.dart';

/// 反思：只练错题本里的词，认得出来就移出
class ReflectScreen extends StatefulWidget {
  final AppState state;

  const ReflectScreen({super.key, required this.state});

  @override
  State<ReflectScreen> createState() => ReflectScreenState();
}

class ReflectScreenState extends State<ReflectScreen> {
  List<StudyItem> _queue = const [];
  int _index = 0;
  bool _revealed = false;
  bool _finished = false;
  int _answered = 0;
  int _removed = 0;
  DateTime _shownAt = DateTime.now();

  AppState get _state => widget.state;

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  void _regenerate() {
    _queue = _state.buildReflectQueue();
    _index = 0;
    _answered = 0;
    _removed = 0;
    _revealed = false;
    _finished = _queue.isEmpty;
    _shownAt = DateTime.now();
  }

/// 切回这个 tab 时调用：错题本变了就重建队列，避免显示已经被移出的卡片
  void refreshIfStale() {
    final stale = _queue.isEmpty
        ? _state.wrongCount > 0
        : _queue.any((i) => !(_state.progress[i.word.id]?.inWrongBook ?? false));
    if (stale) setState(_regenerate);
  }

  void _reveal() {
    if (!_revealed) setState(() => _revealed = true);
  }

  void _answer(Rating choice) {
    if (_finished || _queue.isEmpty) return;
    final item = _queue[_index];
    final elapsed = DateTime.now().difference(_shownAt).inMilliseconds;

    _state.answer(
      item.word,
      choice,
      elapsedMs: elapsed,
      fromReflect: true,
      isReviewCard: true,
    );

    setState(() {
      _answered++;
      if (choice == Rating.know) _removed++;
      if (_index + 1 >= _queue.length) {
        _finished = true;
      } else {
        _index++;
        _revealed = false;
        _shownAt = DateTime.now();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(theme),
            Expanded(child: _finished ? _finishedView(theme) : _cardArea(theme)),
            if (!_finished) _options(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('反思',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
              const SizedBox(width: 10),
              TagChip('错题本 ${_state.wrongCount}', color: kWarn),
              const Spacer(),
              if (!_finished)
                Text('${_index + 1} / ${_queue.length}',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 10),
          Text('认出来就移出错题本，认不出就留着',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _queue.isEmpty ? 0 : (_index + (_finished ? 1 : 0)) / _queue.length,
              minHeight: 6,
              backgroundColor: kWarn.withValues(alpha: 0.14),
              valueColor: const AlwaysStoppedAnimation(kWarn),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardArea(ThemeData theme) {
    final item = _queue[_index];
    return GestureDetector(
      onTap: _reveal,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) {
              final slide = Tween<Offset>(
                begin: const Offset(0.22, 0),
                end: Offset.zero,
              ).animate(anim);
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: FlipWordCard(
              key: ValueKey('r-${item.word.id}-$_index'),
              word: item.word,
              revealed: _revealed,
              isReview: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _options() {
    if (!_revealed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        child: OutlinedButton.icon(
          onPressed: _reveal,
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('点击卡片 / 显示释义'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: () => _answer(Rating.unknown),
                style: FilledButton.styleFrom(
                  backgroundColor: kBad.withValues(alpha: 0.14),
                  foregroundColor: kBad,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('不认识', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: () => _answer(Rating.know),
                style: FilledButton.styleFrom(
                  backgroundColor: kGood.withValues(alpha: 0.14),
                  foregroundColor: kGood,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('认识', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _finishedView(ThemeData theme) {
    final empty = _queue.isEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: (empty ? theme.colorScheme.primary : kGood).withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(empty ? Icons.inbox_outlined : Icons.cleaning_services_rounded,
                  size: 42,
                  color: empty ? theme.colorScheme.primary : kGood),
            ),
            const SizedBox(height: 20),
            Text(empty ? '错题本是空的' : '这一轮反思完成',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
            const SizedBox(height: 8),
            Text(
              empty ? '先去「知新」学几个词，选「不认识」就会进这里' : '移出错题本 $_removed 个 · 作答 $_answered 次',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => setState(_regenerate),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('再刷一轮'),
            ),
          ],
        ),
      ),
    );
  }
}
