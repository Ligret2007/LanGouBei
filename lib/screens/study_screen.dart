import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/word.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets/flip_card.dart';

/// 知新：按队列过词，选「不认识」进错题本；每答 5 个词实时插一张错题卡
class StudyScreen extends StatefulWidget {
  final AppState state;

  const StudyScreen({super.key, required this.state});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  List<Word> _base = const [];
  int _baseIndex = 0;
  Word? _reviewWord;
  int _sinceReview = 0;
  final Set<String> _reviewedIds = {};

  int _answered = 0;
  bool _revealed = false;
  bool _finished = true;
  DateTime _shownAt = DateTime.now();

  AppState get _state => widget.state;

  StudyItem? get _current {
    final r = _reviewWord;
    if (r != null) return StudyItem(r, fromWrongBook: true);
    if (_baseIndex < _base.length) return StudyItem(_base[_baseIndex]);
    return null;
  }

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  void _regenerate() {
    _base = _state.pickStudyWords();
    _baseIndex = 0;
    _reviewWord = null;
    _sinceReview = 0;
    _reviewedIds.clear();
    _answered = 0;
    _revealed = false;
    _shownAt = DateTime.now();
    _finished = _current == null;
  }

  void _reveal() {
    if (!_revealed) setState(() => _revealed = true);
  }

  void _answer(Rating choice) {
    final item = _current;
    if (item == null || _finished) return;
    final elapsed = DateTime.now().difference(_shownAt).inMilliseconds;

    _state.answer(
      item.word,
      choice,
      elapsedMs: elapsed,
      fromReflect: false,
      isReviewCard: item.fromWrongBook,
    );

    setState(() {
      _answered++;
      if (item.fromWrongBook) {
        _reviewWord = null;
      } else {
        _baseIndex++;
        _sinceReview++;
      }

      // 每 5 个基础词插一张错题；错题本是空的就等下次再试
      if (_reviewWord == null && _sinceReview >= 5) {
        final w = _state.pickWrongBookWord(exclude: _reviewedIds);
        if (w != null) {
          _reviewWord = w;
          _reviewedIds.add(w.id);
          _sinceReview = 0;
        }
      }

      _finished = _current == null;
      if (!_finished) {
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
            if (!_finished) _options(theme),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme) {
    final stat = _state.todayStat;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('知新',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
              const SizedBox(width: 10),
              TagChip(_state.settings.bank == 'ext' ? '高分词库' : '保底词库'),
              const Spacer(),
              Text('今日 ${stat.choices} 次',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniStat(label: '错题本', value: '${_state.wrongCount}'),
              const SizedBox(width: 16),
              _MiniStat(label: '已掌握', value: '${_state.masteredCount}'),
              const Spacer(),
              if (!_finished)
                Text('第 ${_answered + 1} 张',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _base.isEmpty ? 0 : (_baseIndex / _base.length).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardArea(ThemeData theme) {
    final item = _current!;
    return GestureDetector(
      onTap: _reveal,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Center(
          child: AnimatedSwitcher(
            duration: Motion.content,
            switchInCurve: Motion.enter,
            switchOutCurve: Motion.exit,
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
              key: ValueKey('${item.word.id}-$_answered'),
              word: item.word,
              revealed: _revealed,
              isReview: item.fromWrongBook,
            ),
          ),
        ),
      ),
    );
  }

  Widget _options(ThemeData theme) {
    final item = _current!;
    final isFresh = _state.progress[item.word.id] == null;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFresh) ...[
            SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () => _answer(Rating.confirm),
                icon: const Icon(Icons.verified_outlined, size: 18),
                label: const Text('确定认识（直接加入已掌握）'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: _RateButton(
                  label: '不认识',
                  color: kBad,
                  onTap: () => _answer(Rating.unknown),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RateButton(
                  label: '模糊',
                  color: kWarn,
                  onTap: () => _answer(Rating.fuzzy),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RateButton(
                  label: '认识',
                  color: kGood,
                  onTap: () => _answer(Rating.know),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _finishedView(ThemeData theme) {
    final empty = _base.isEmpty;
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
                color: (empty ? kWarn : kGood).withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(empty ? Icons.emoji_events_outlined : Icons.check_rounded,
                  size: 44, color: empty ? kWarn : kGood),
            ),
            const SizedBox(height: 20),
            Text(empty ? '这一轮没有待学的词' : '这一组学完了',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
            const SizedBox(height: 8),
            Text(
              empty ? '待复习的词都在错题本里，去「反思」清一清' : '本轮做了 $_answered 次选择',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => setState(_regenerate),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(empty ? '重新生成一组' : '再来一组'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RichText(
      text: TextSpan(
        style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        children: [
          TextSpan(text: '$label '),
          TextSpan(
            text: value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RateButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _RateButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.14),
          foregroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
