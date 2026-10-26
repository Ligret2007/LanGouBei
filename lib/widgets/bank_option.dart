import 'package:flutter/material.dart';

import '../theme.dart';

/// 词库选项卡片：引导页和「更多 → 词库」共用
class BankOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const BankOption({
    super.key,
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
      child: Semantics(
        button: true,
        selected: selected,
        label: title,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.08)
                  : theme.colorScheme.surface,
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
      ),
    );
  }
}
