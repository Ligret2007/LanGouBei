import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show FramePhase;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../app_state.dart';
import '../bank/bank_registry.dart';
import '../bank/bank_storage.dart';
import '../bank/word_bank.dart';
import '../export_service.dart';
import '../models/word.dart';
import '../widgets/bank_option.dart';
import '../widgets/year_wheel.dart';
import '../theme.dart';
import '../version.dart';

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
                  const SizedBox(height: 20),
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
                  Row(
                    children: [
                      Text('词库',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _importBank(context),
                        icon: const Icon(Icons.file_open_rounded, size: 18),
                        label: const Text('导入词库'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final bank in state.availableBanks) ...[
                    BankOption(
                      title: bank.name,
                      subtitle: bank.detail,
                      selected: state.activeBank?.id == bank.id,
                      onTap: () => _switchBank(context, bank),
                      trailing: IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: '导出或删除',
                        icon: const Icon(Icons.more_horiz_rounded, size: 20),
                        onPressed: () => _bankActions(context, bank),
                      ),
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
                  Text(
                    state.importedBanks.isEmpty
                        ? '导入的词库存在 App 里，随时能切回来'
                        : '已导入 ${state.importedBanks.length} 个词库',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline),
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
                  _row(theme, '词库', state.activeBank?.name ?? '—'),
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
                        const SizedBox(height: 2),
                        // 渲染参数 + 实测帧率：排查字发虚/掉帧时先看这一行
                        const _Diagnostics(),
                      ],
                    ),
                  ),
                  TagChip('v$kAppVersion'),
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
  Future<void> _switchBank(BuildContext context, BankSummary bank) async {
    if (state.activeBank?.id == bank.id) return;
    final before = state.bankTotal;
    await _busy(context, () => state.setBank(bank.id));
    if (!context.mounted) return;
    final delta = state.bankTotal - before;
    final tail = delta == 0
        ? ''
        : '，${delta > 0 ? '增加' : '减少'} ${delta.abs()} 个词';
    _toast(context, '已切到「${bank.name}」$tail，知新会按新词库重新排队');
  }

  /// 导入词库：问一下从文件还是粘贴
  Future<void> _importBank(BuildContext context) async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open_rounded),
              title: const Text('从文件选择'),
              subtitle: const Text('选一个 .json 词库文件'),
              onTap: () => Navigator.pop(sheet, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.content_paste_rounded),
              title: const Text('粘贴 JSON'),
              subtitle: const Text('把词库文本直接贴进来'),
              onTap: () => Navigator.pop(sheet, 'paste'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (mode == null || !context.mounted) return;

    String? raw;
    String? filename;
    if (mode == 'file') {
      final PickedBankFile? picked =
          await _busy(context, () => const PlatformBankStorage().pickFile());
      if (picked == null || !context.mounted) return;
      raw = picked.content;
      filename = picked.name;
    } else {
      raw = await _pasteDialog(context);
      if (raw == null || !context.mounted) return;
    }
    await _importText(context, raw, filename: filename);
  }

  Future<void> _importText(BuildContext context, String raw, {String? filename}) async {
    try {
      final result = await _busy(context, () => state.importBank(raw, filename: filename));
      if (!context.mounted) return;
      final extra = result.warnings.isEmpty ? '' : '（${result.warnings.join('；')}）';
      _toast(context, '已导入「${result.bank.name}」，${result.bank.wordCount} 词$extra');
    } on BankFormatException catch (e) {
      if (context.mounted) _toast(context, '导入失败：${e.message}');
    } catch (e) {
      if (context.mounted) _toast(context, '导入失败：$e');
    }
  }

  Future<String?> _pasteDialog(BuildContext context) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _PasteBankDialog(),
    );
    final trimmed = text?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// 词库的更多操作：导出成文件 / 复制 JSON / 删除（仅导入库）
  Future<void> _bankActions(BuildContext context, BankSummary bank) async {
    final scheme = Theme.of(context).colorScheme;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(bank.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(bank.detail),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.save_alt_rounded),
              title: const Text('导出为文件'),
              subtitle: const Text('存到系统「下载」目录'),
              onTap: () => Navigator.pop(sheet, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.content_copy_rounded),
              title: const Text('复制 JSON'),
              onTap: () => Navigator.pop(sheet, 'copy'),
            ),
            if (!bank.builtin)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: scheme.error),
                title: Text('删除这个词库', style: TextStyle(color: scheme.error)),
                onTap: () => Navigator.pop(sheet, 'delete'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case 'file':
        await _exportBankFile(context, bank);
      case 'copy':
        await _copyBankJson(context, bank);
      case 'delete':
        await _deleteBank(context, bank);
    }
  }

  Future<void> _exportBankFile(BuildContext context, BankSummary bank) async {
    final json = await _busy(context, () => state.exportBankJson(bank.id));
    if (!context.mounted) return;
    final r = await ExportService.saveText('langobei-bank-${bank.id}.json', json);
    if (!context.mounted) return;
    _toast(context, r.ok ? '已导出到 ${r.message}' : '导出失败：${r.message}');
  }

  Future<void> _copyBankJson(BuildContext context, BankSummary bank) async {
    final json = await _busy(context, () => state.exportBankJson(bank.id));
    await Clipboard.setData(ClipboardData(text: json));
    if (!context.mounted) return;
    _toast(context, '已复制「${bank.name}」的 JSON（${(json.length / 1024).toStringAsFixed(0)} KB）');
  }

  Future<void> _deleteBank(BuildContext context, BankSummary bank) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('删除词库'),
        content: Text('删掉「${bank.name}」？词库文件会一并删除，学习进度不受影响。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await state.removeBank(bank.id);
      if (!context.mounted) return;
      _toast(context, '已删除「${bank.name}」');
    } catch (e) {
      if (context.mounted) _toast(context, '删除失败：$e');
    }
  }

  /// 跑可能有点慢的异步任务：盖一层不可点的遮罩挡住连点。
  ///
  /// 这里故意不用 CircularProgressIndicator：它一直在动，会让
  /// 「等界面稳定下来」的 widget 测试永远等不到头，换成静态提示。
  Future<T> _busy<T>(BuildContext context, Future<T> Function() task) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => const AbsorbPointer(
        child: ColoredBox(
          color: Color(0x30000000),
          child: Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                child: Text('处理中…'),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    try {
      return await task();
    } finally {
      entry.remove();
    }
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

/// 「关于」里的诊断行：屏幕物理像素、像素比、字号缩放、最近实测帧率。
///
/// 帧率用相邻帧的 vsync 间隔算，反映的是屏幕真正给了多少帧；
/// 高刷屏上应该看到 ~120，如果只有 ~60，说明系统把这 App 限到了 60Hz。
class _Diagnostics extends StatefulWidget {
  const _Diagnostics();

  @override
  State<_Diagnostics> createState() => _DiagnosticsState();
}

class _DiagnosticsState extends State<_Diagnostics> {
  double _fps = 0;
  double _fpsMin = 0;
  int _frames = 0;
  int _intervalTotalUs = 0;
  int _maxIntervalUs = 0;
  int _lastVsyncUs = 0;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      final us = t.timestampInMicroseconds(FramePhase.vsyncStart);
      if (_lastVsyncUs != 0) {
        final d = us - _lastVsyncUs;
        // 丢掉异常间隔（刚从后台回来、或者卡了一大下）
        if (d > 1000 && d < 100000) {
          _intervalTotalUs += d;
          if (d > _maxIntervalUs) _maxIntervalUs = d;
          _frames++;
        }
      }
      _lastVsyncUs = us;
    }
    if (_frames >= 20) {
      final avg = _intervalTotalUs / _frames;
      final worst = _maxIntervalUs;
      _frames = 0;
      _intervalTotalUs = 0;
      _maxIntervalUs = 0;
      final fps = avg <= 0 ? 0.0 : (1000000 / avg).clamp(0.0, 240.0);
      final minFps = worst <= 0 ? 0.0 : (1000000 / worst).clamp(0.0, 240.0);
      // 只有明显变化才刷新，否则稳定后每一帧都在重建
      if (mounted && ((fps - _fps).abs() >= 1 || (minFps - _fpsMin).abs() >= 1)) {
        setState(() {
          _fps = fps;
          _fpsMin = minFps;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final dpr = mq.devicePixelRatio;
    final w = (mq.size.width * dpr).round();
    final h = (mq.size.height * dpr).round();
    final scale = mq.textScaler.scale(14) / 14;
    final fpsText = _fps <= 0 ? '—' : _fps.toStringAsFixed(0);
    final minText = _fpsMin <= 0 ? '—' : _fpsMin.toStringAsFixed(0);
    return Text(
      '屏幕 $w×$h @${dpr.toStringAsFixed(2)} · 字号 ${scale.toStringAsFixed(2)}× · '
      '~$fpsText fps（最低 $minText）',
      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline, fontSize: 10),
    );
  }
}

/// 粘贴词库 JSON 的对话框。
///
/// 单独做成 StatefulWidget 是为了让 TextEditingController 跟着对话框自己的生命周期走：
/// 之前放在外面、showDialog 一返回就 dispose，退场动画还在重建 TextField 时会碰已销毁的
/// controller，整页直接变成 Flutter 的红屏。
class _PasteBankDialog extends StatefulWidget {
  const _PasteBankDialog();

  @override
  State<_PasteBankDialog> createState() => _PasteBankDialogState();
}

class _PasteBankDialogState extends State<_PasteBankDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('粘贴词库 JSON'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('有一段 {"words": [...]} 就够，id 和 name 可以省略。'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            minLines: 5,
            maxLines: 9,
            decoration: const InputDecoration(
              hintText: '{"words": [{"word": "apple", "meaning": "苹果"}]}',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('导入'),
        ),
      ],
    );
  }
}
