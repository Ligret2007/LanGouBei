import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/word.dart';
import '../theme.dart';

/// 更多：外观（深浅色 + 主题色）、当前设置、重置入口
class MoreScreen extends StatelessWidget {
  final AppState state;

  const MoreScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = state.settings;
    final preset = presetById(s.themePreset);
    final seed = seedForPreset(preset);
    final counts = state.levelCounts;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text('更多',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),

            // ---------------- 外观 ----------------
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.palette_outlined, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('外观',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('深色模式',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeModeSetting>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeModeSetting.system,
                          label: Text('跟随系统'),
                          icon: Icon(Icons.brightness_auto_outlined, size: 16),
                        ),
                        ButtonSegment(
                          value: ThemeModeSetting.light,
                          label: Text('浅色'),
                          icon: Icon(Icons.light_mode_outlined, size: 16),
                        ),
                        ButtonSegment(
                          value: ThemeModeSetting.dark,
                          label: Text('深色'),
                          icon: Icon(Icons.dark_mode_outlined, size: 16),
                        ),
                      ],
                      selected: {s.themeMode},
                      onSelectionChanged: (v) => state.setThemeMode(v.first),
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Text('主题色',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      const Spacer(),
                      Text(
                        '${preset.label} · ${_hex(seed)}',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (final p in kThemePresets)
                        Expanded(
                          child: _PresetSwatch(
                            preset: p,
                            selected: p.id == preset.id,
                            onTap: () => _pickPreset(context, p),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ---------------- 当前设置 ----------------
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('当前设置',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _row(theme, '词库', s.bank == 'ext' ? '高考词汇（高分）' : '高考词汇（保底）'),
                  _row(theme, '词数', '${state.bankTotal} 词'),
                  _row(theme, '高考年份', s.examYear == null ? '不参加' : '${s.examYear} 年'),
                  const SizedBox(height: 12),
                  Text('分级',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final level in kLevels)
                        TagChip(
                          '$level ${counts[level] ?? 0}',
                          color: levelColor(level, theme.brightness),
                          strength: 0.18,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('这里先留白',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    '账号同步、发音设置、免打扰时段、导出词表这些还没做，先放着。',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SurfaceCard(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.auto_stories_rounded,
                        size: 22, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LangoBei',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        Text('——高三生 Ligret',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  TagChip('v1.0.0'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _confirmReset(context),
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('清空进度，重新走一遍引导'),
            ),
          ],
        ),
      ),
    );
  }

  static String _hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  Widget _row(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const Spacer(),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _pickPreset(BuildContext context, ThemePreset p) {
    if (p.reserved) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('这一格先留空，想好加什么颜色再放进来'),
          duration: Duration(seconds: 2),
        ));
      return;
    }
    state.setThemePreset(p.id);
  }

  void _confirmReset(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空全部进度？'),
        content: const Text('已掌握、错题本、连续天数和每日统计都会清空，然后回到引导页重新设置。主题外观会保留。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              state.resetAll();
              Navigator.of(ctx).pop();
            },
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
  }
}

/// 主题色色块：留空的那格画成虚线圈，点了只给提示
class _PresetSwatch extends StatelessWidget {
  final ThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _PresetSwatch({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = seedForPreset(preset);

    return Semantics(
      button: true,
      selected: selected,
      label: preset.reserved ? '${preset.label}（未启用）' : '主题色 ${preset.label}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: preset.reserved
                    ? CustomPaint(
                        painter: _DashedCirclePainter(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: selected
                              ? Border.all(color: theme.colorScheme.onSurface, width: 3)
                              : null,
                        ),
                        child: selected
                            ? const Icon(Icons.check_rounded, size: 22, color: Colors.white)
                            : null,
                      ),
              ),
              const SizedBox(height: 6),
              Text(
                preset.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: preset.reserved
                      ? theme.colorScheme.outline
                      : selected
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;

  _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2;
    const dashes = 16;
    for (var i = 0; i < dashes; i++) {
      final start = (i / dashes) * 2 * math.pi;
      final sweep = (2 * math.pi / dashes) * 0.55;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) => old.color != color;
}