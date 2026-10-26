import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/word.dart';
import '../widgets/bank_option.dart';
import '../widgets/year_wheel.dart';
import '../motion.dart';
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

  /// 年份滚轮（2027-2040）的控制器，初值停在第一年
  final FixedExtentScrollController _yearController =
      FixedExtentScrollController(initialItem: 0);
  int _page = 0;

  String _bank = kBankCore;
  int _examYear = kExamYearMin;

  static const int _pages = 4;

  bool get _canNext => switch (_page) {
        0 => true,
        1 => true,
        2 => true,
        _ => true,
      };

  @override
  void dispose() {
    _controller.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages - 1) {
      _controller.nextPage(duration: Motion.page, curve: Motion.standard);
    } else {
      widget.state.completeOnboarding(bank: _bank, examYear: _examYear);
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
                        duration: Motion.fade,
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
          Text('开源地址：github.com/Ligret2007/LanGouBei',
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
          Text('之后可以在「更多」里随时切换，已经背过的词不会丢',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 22),
          for (final bank in const [kBankCore, kBankExt]) ...[
            BankOption(
              title: bankTitle(bank),
              subtitle: bankSubtitle(bank),
              selected: _bank == bank,
              onTap: () => setState(() => _bank = bank),
            ),
            const SizedBox(height: 12),
          ],
          // 还没开放、先占位
          for (final planned in kPlannedBanks) ...[
            BankOption(
              title: planned.title,
              subtitle: planned.subtitle,
              selected: false,
              disabled: true,
              onTap: () {},
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  // ---------------- 第 3 页：高考年份（滚动选择） ----------------
  Widget _examPage(ThemeData theme) {
    final today = DateTime.now();
    final days = DateTime(_examYear, 6, 7)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('哪一年参加高考？',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
          const SizedBox(height: 6),
          Text('上下滚动选年份，加载页会按它显示倒计时',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          YearWheel(
            controller: _yearController,
            value: _examYear,
            onChanged: (y) => setState(() => _examYear = y),
          ),
          const SizedBox(height: 18),
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
                  '距离 $_examYear 年高考还有 ${days < 0 ? 0 : days} 天',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
            ),
          ),
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
            '$_examYear 年高考 · ${bankTitle(_bank)}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
