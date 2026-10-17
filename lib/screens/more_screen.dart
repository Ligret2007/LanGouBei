import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../app_state.dart';
import '../export_service.dart';
import '../models/word.dart';
import '../widgets/bank_option.dart';
import '../widgets/year_wheel.dart';
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
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
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

            // ---------------- 词库选择 ----------------
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('词库',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  for (final bank in const [kBankCore, kBankExt]) ...[
                    BankOption(
                      title: bankTitle(bank),
                      subtitle: bankSubtitle(bank),
                      selected: s.bank == bank,
                      onTap: () => _switchBank(context, bank),
                    ),
                    const SizedBox(height: 10),
                  ],
                  for (final planned in kPlannedBanks) ...[
                    BankOption(
                      title: planned.title,
                      subtitle: planned.subtitle,
                      selected: false,
                      disabled: true,
                      onTap: () {},
                    ),
                    const SizedBox(height: 10),
                  ],
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
                  _row(theme, '词库', bankTitle(s.bank)),
                  _row(theme, '词数', '${state.bankTotal} 词'),
                  _editableRow(
                    context,
                    theme,
                    '高考年份',
                    s.examYear == null ? '未设置' : '${s.examYear} 年',
                    () => _editExamYear(context),
                  ),
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

            // ---------------- 数据导出 ----------------
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('数据',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _export(context),
                          icon: const Icon(Icons.save_alt_rounded, size: 18),
                          label: const Text('导出为文件'),
                          style: FilledButton.styleFrom(
                            textStyle: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _copyJson(context),
                          icon: const Icon(Icons.copy_all_rounded, size: 18),
                          label: const Text('复制 JSON'),
                          style: OutlinedButton.styleFrom(
                            textStyle: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _shareJson(context),
                      icon: const Icon(Icons.ios_share_rounded, size: 16),
                      label: const Text('分享文本'),
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

  /// 可点的一行：右边带个「改」的箭头，点开弹年份滚轮
  Widget _editableRow(
    BuildContext context,
    ThemeData theme,
    String label,
    String value,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const Spacer(),
            Text(value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                )),
            const SizedBox(width: 4),
            Icon(Icons.edit_rounded, size: 15, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }

  /// 改高考年份：底部弹出同一个滚轮
  Future<void> _editExamYear(BuildContext context) async {
    final theme = Theme.of(context);
    var picked = clampExamYear(state.settings.examYear);
    final controller =
        FixedExtentScrollController(initialItem: picked - kExamYearMin);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('哪一年参加高考？',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setSheetState) => YearWheel(
                  controller: controller,
                  value: picked,
                  onChanged: (y) => setSheetState(() => picked = y),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    controller.dispose();
    if (ok != true || !context.mounted) return;
    await state.setExamYear(picked);
    if (!context.mounted) return;
    _toast(context, '高考年份已改为 $picked 年');
  }

  /// 切换词库：换完提示一句，已经背过的词仍然是背过的
  Future<void> _switchBank(BuildContext context, String bank) async {
    final before = state.bankTotal;
    await state.setBank(bank);
    if (!context.mounted) return;
    final delta = state.bankTotal - before;
    final tip = delta == 0
        ? '已切到「${bankTitle(bank)}」'
        : '已切到「${bankTitle(bank)}」，${delta > 0 ? '增加' : '减少'} ${delta.abs()} 个词';
    _toast(context, '$tip，知新会按新词库重新排队');
  }

  void _toast(BuildContext context, String text, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 4),
        action: action,
      ));
  }

  /// 导出成文件，落到系统「下载」目录
  Future<void> _export(BuildContext context) async {
    final r = await ExportService.exportToFile(state);
    if (!context.mounted) return;
    if (!r.ok) {
      _toast(context, '导出失败：${r.message}');
      return;
    }
    _toast(
      context,
      '已导出到 ${r.message}',
      action: SnackBarAction(
        label: '复制路径',
        onPressed: () => Clipboard.setData(ClipboardData(text: r.message)),
      ),
    );
  }

  /// 复制整份 JSON 到剪贴板：没有文件系统权限的场合也能用
  Future<void> _copyJson(BuildContext context) async {
    await ExportService.copyToClipboard(state);
    if (!context.mounted) return;
    final kb = utf8.encode(ExportService.json(state)).length / 1024;
    _toast(context, '已复制 ${kb.toStringAsFixed(1)} KB JSON 到剪贴板');
  }

  Future<void> _shareJson(BuildContext context) async {
    final r = await ExportService.share(state);
    if (!context.mounted || r.ok) return;
    _toast(context, '分享失败：${r.message}');
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
