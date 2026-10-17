import 'package:flutter/material.dart';

import '../models/word.dart';

/// 滚动式年份选择：中间高亮，上下露出相邻年份。
/// 引导页和「更多 → 修改高考年份」共用。
class YearWheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int value;
  final ValueChanged<int> onChanged;

  const YearWheel({
    super.key,
    required this.controller,
    required this.value,
    required this.onChanged,
  });

  static const double itemExtent = 56;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final years = kExamYears;

    return SizedBox(
      height: itemExtent * 4,
      child: Stack(
        children: [
          // 中间那条高亮带
          Center(
            child: Container(
              height: itemExtent,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: itemExtent,
            diameterRatio: 1.7,
            perspective: 0.002,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (i) => onChanged(years[i]),
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: years.length,
              builder: (context, i) {
                final selected = years[i] == value;
                return Center(
                  child: Text(
                    '${years[i]} 年',
                    style: (selected
                            ? theme.textTheme.headlineSmall
                            : theme.textTheme.titleLarge)
                        ?.copyWith(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
