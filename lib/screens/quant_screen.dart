import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';

/// 量化：倒计时、连续天数、正确率、掌握度、错题数、七天柱状图
class QuantScreen extends StatelessWidget {
  final AppState state;

  const QuantScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stat = state.todayStat;
    final days = state.daysToExam;
    final recent = state.recentDays(7);
    final maxChoices = recent.fold<int>(1, (m, e) => e.value.choices > m ? e.value.choices : m);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text('量化',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('把进度看得见，才不容易半途而废',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 18),

            // 倒计时 + 连续天数
            SurfaceCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('距离高考还有',
                            style: theme.textTheme.labelMedium
                                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 6),
                        if (days != null)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text('$days',
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: theme.colorScheme.primary,
                                    height: 1,
                                  )),
                              const SizedBox(width: 4),
                              Text('天',
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(color: theme.colorScheme.primary)),
                            ],
                          )
                        else
                          Text('未设置高考年份',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        if (state.settings.examYear != null)
                          Text('${state.settings.examYear} 年 6 月 7 日',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: theme.colorScheme.outline)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: kAccent, size: 22),
                        const SizedBox(height: 4),
                        Text('${state.streak} 天',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800, color: kAccent)),
                        Text('已连续',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: kAccent.withValues(alpha: 0.9))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: '今日正确率',
                    value: stat.choices == 0 ? '--' : '${(stat.accuracy * 100).round()}%',
                    hint: '今日 ${stat.choices} 次选择',
                    icon: Icons.track_changes_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: '错题本',
                    value: '${state.wrongCount}',
                    hint: '待清出',
                    icon: Icons.menu_book_rounded,
                    color: kWarn,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 掌握度
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('已掌握',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text('${state.masteredCount} / ${state.bankTotal}',
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: state.masteredRatio,
                      minHeight: 16,
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${(state.masteredRatio * 100).toStringAsFixed(1)}%',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      )),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text('最近七天选择次数',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SurfaceCard(
              child: SizedBox(
                height: 180,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: recent.map((e) {
                    final total = e.value.choices;
                    final ratio = maxChoices == 0 ? 0.0 : total / maxChoices;
                    final isToday = e.key == AppState.dayKey();
                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('$total',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              )),
                          const SizedBox(height: 4),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            height: 110 * ratio + 4,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            e.key.substring(5),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isToday
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(hint,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}
