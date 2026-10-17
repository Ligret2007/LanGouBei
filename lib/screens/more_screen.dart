import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/word.dart';
import '../theme.dart';
import '../widgets/hsl_color_wheel.dart';

/// 更多：外观（深浅色 + 主题色）、当前设置、重置入口
class MoreScreen extends StatelessWidget {
  final AppState state;

  const MoreScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = state.settings;
    final seed = seedColorFrom(s.seedHue, s.seedSaturation, s.seedLightness);

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
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: seed,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'HSL ${s.seedHue.round()}° · ${(s.seedSaturation * 100).round()}% · ${(s.seedLightness * 100).round()}%',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: HslColorWheel(
                      hue: s.seedHue,
                      saturation: s.seedSaturation,
                      lightness: s.seedLightness,
                      size: 226,
                      onChanged: (hue, sat) => state.setSeed(hue: hue, saturation: sat),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('明度',
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      Expanded(
                        child: Slider(
                          value: s.seedLightness,
                          min: 0.2,
                          max: 0.8,
                          divisions: 60,
                          label: '${(s.seedLightness * 100).round()}%',
                          onChanged: (v) => state.setSeed(lightness: v),
                          onChangeEnd: (_) => state.flush(),
                        ),
                      ),
                      SizedBox(
                        width: 82,
                        child: Text(
                          _hex(seed),
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: state.resetSeed,
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: const Text('恢复默认色'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
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
