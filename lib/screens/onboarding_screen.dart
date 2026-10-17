import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';

/// 首次启动的四页引导
class OnboardingScreen extends StatefulWidget {
  final AppState state;

  const OnboardingScreen({super.key, required this.state});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  String _bank = 'core';
  bool? _attendingExam;
  int? _examYear;

  static const int _pages = 4;

  bool get _canNext => switch (_page) {
        0 => true,
        1 => true,
        2 => _attendingExam == false || (_attendingExam == true && _examYear != null),
        _ => true,
      };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    } else {
      widget.state.completeOnboarding(
        bank: _bank,
        examYear: _attendingExam == true ? _examYear : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Text('LangoBei',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
                  const Spacer(),
                  if (_page > 0)
                    TextButton(
                      onPressed: () => _controller.animateToPage(
                        _pages - 1,
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      ),
                      child: const Text('跳过'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _introPage(theme),
                  _bankPage(theme),
                  _examPage(theme),
                  _readyPage(theme),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: active
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _canNext ? _next : null,
                    child: Text(_page == _pages - 1 ? '开始背单词' : '下一步'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- 第 1 页：介绍 ----------------
  Widget _introPage(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 28),
          Text('LangoBei',
              style: theme.textTheme.displaySmall
                  ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1, color: theme.colorScheme.primary)),
          const SizedBox(height: 14),
          Text(
            '源于世界上最负责的英语老师\n催促我背单词',
            style: theme.textTheme.titleLarge?.copyWith(height: 1.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          Text('github 开源：LangoBei',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const Spacer(),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('——高三生 Ligret',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---------------- 第 2 页：选词库 ----------------
  Widget _bankPage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('选一个词库',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
          const SizedBox(height: 6),
          Text('之后可以在「我的」里重新设置',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 22),
          _BankOption(
            title: '高考词汇（保底）',
            subtitle: '3014 词 · 基础到进阶，覆盖高考高频',
            selected: _bank == 'core',
            onTap: () => setState(() => _bank = 'core'),
          ),
          const SizedBox(height: 12),
          _BankOption(
            title: '高考词汇（高分）',
            subtitle: '3540 词 · 在保底基础上加 526 个拓展词',
            selected: _bank == 'ext',
            onTap: () => setState(() => _bank = 'ext'),
          ),
          const SizedBox(height: 12),
          _BankOption(
            title: '四级词汇',
            subtitle: '暂未开放',
            selected: false,
            disabled: true,
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _BankOption(
            title: '雅思 6.5 词汇',
            subtitle: '暂未开放',
            selected: false,
            disabled: true,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  // ---------------- 第 3 页：高考 ----------------
  Widget _examPage(ThemeData theme) {
    final now = DateTime.now().year;
    final years = [now + 1, now + 2, now + 3];
    final today = DateTime.now();
    final days = _examYear == null
        ? null
        : DateTime(_examYear!, 6, 7)
            .difference(DateTime(today.year, today.month, today.day))
            .inDays;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('是否即将参加高考？',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
          const SizedBox(height: 6),
          Text('选了「是」之后，加载页会显示倒计时',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _ChoiceTile(
                  label: '是',
                  selected: _attendingExam == true,
                  onTap: () => setState(() => _attendingExam = true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ChoiceTile(
                  label: '否',
                  selected: _attendingExam == false,
                  onTap: () => setState(() {
                    _attendingExam = false;
                    _examYear = null;
                  }),
                ),
              ),
            ],
          ),
          if (_attendingExam == true) ...[
            const SizedBox(height: 28),
            Text('哪一年高考？',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: years.map((y) {
                final selected = _examYear == y;
                return ChoiceChip(
                  label: Text('$y 年'),
                  selected: selected,
                  onSelected: (_) => setState(() => _examYear = y),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (_examYear != null && days != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_rounded, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '距离 $_examYear 年高考还有 $days 天',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ---------------- 第 4 页：就绪 ----------------
  Widget _readyPage(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: kGood.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.rocket_launch_rounded, color: kGood, size: 48),
          ),
          const SizedBox(height: 26),
          Text('一切准备就绪',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          Text('祝你好运',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 26),
          Text(
            _attendingExam == true && _examYear != null
                ? '$_examYear 年高考 · ${_bank == 'ext' ? '高考词汇（高分）' : '高考词汇（保底）'}'
                : '词库：${_bank == 'ext' ? '高考词汇（高分）' : '高考词汇（保底）'}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

class _BankOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _BankOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.7);
    final fg = disabled ? theme.colorScheme.outline : theme.colorScheme.onSurface;

    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary.withValues(alpha: 0.08) : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700, color: fg)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
              else if (disabled)
                TagChip('敬请期待')
              else
                Icon(Icons.circle_outlined, color: theme.colorScheme.outlineVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceTile({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 26),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary.withValues(alpha: 0.10) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(label,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
            )),
      ),
    );
  }
}
