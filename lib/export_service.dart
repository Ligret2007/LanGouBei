import 'dart:convert';

import 'package:flutter/services.dart';

import 'app_state.dart';
import 'models/word.dart';

/// 导出结果
class ExportResult {
  final bool ok;

  /// 成功时是「下载/langobei-xxx.json」这样的位置；失败时是错误说明
  final String message;

  const ExportResult(this.ok, this.message);
}

/// 学习数据导出：生成一个 JSON 文件，内容与本地存档同构，
/// 所以将来要写「导入」时可以直接把 data 段喂回 AppState。
class ExportService {
  static const MethodChannel _channel = MethodChannel('langobei/export');

  /// 导出格式版本；以后改字段就往上加
  static const int format = 1;

  static String fileName([DateTime? now]) {
    final t = now ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'langobei-${t.year}${two(t.month)}${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}.json';
  }

  /// 组装导出内容：痕迹、统计、外观设置
  static Map<String, dynamic> payload(AppState state, {DateTime? now}) {
    final t = now ?? DateTime.now();
    // 「今日」这一段跟着传入的时间走，不读真实时钟：这样导出内容是确定性的，测试也不受跨零点影响
    final todayKey = AppState.dayKey(t);
    final todayStat = state.daily[todayKey];
    final p = state.progress.values;
    int sum(int Function(WordProgress) f) => p.fold<int>(0, (s, e) => s + f(e));

    return {
      'app': 'LangoBei',
      'format': format,
      'exportedAt': t.toIso8601String(),
      'utcOffsetMinutes': t.timeZoneOffset.inMinutes,
      'summary': {
        'bank': state.settings.bank,
        'examYear': state.settings.examYear,
        'bankTotal': state.bankTotal,
        'studied': state.studiedCount,
        'mastered': state.masteredCount,
        'wrong': state.wrongCount,
        'accuracy': double.parse(state.overallAccuracy.toStringAsFixed(4)),
        'know': sum((e) => e.knowCount),
        'fuzzy': sum((e) => e.fuzzyCount),
        'unknown': sum((e) => e.unknownCount),
        'streak': state.streak,
        'levelCounts': state.levelCounts,
        'themeMode': state.settings.themeMode.name,
        'themePreset': state.settings.themePreset,
        'today': {
          'date': todayKey,
          'choices': todayStat?.choices ?? 0,
          'correct': todayStat?.correct ?? 0,
        },
      },
      'data': state.toSnapshot(),
    };
  }

  /// 缩进过的 JSON，方便直接打开看
  static String json(AppState state, {DateTime? now}) =>
      const JsonEncoder.withIndent('  ').convert(payload(state, now: now));

  /// 写进系统「下载」目录，返回可读位置
  static Future<ExportResult> exportToFile(AppState state, {DateTime? now}) async {
    final name = fileName(now);
    final content = json(state, now: now);
    try {
      final location = await _channel.invokeMethod<String>('saveToDownloads', {
        'filename': name,
        'content': content,
      });
      return ExportResult(true, location ?? name);
    } on PlatformException catch (e) {
      return ExportResult(false, e.message ?? '导出失败');
    } on MissingPluginException {
      return const ExportResult(false, '当前平台不支持导出到文件');
    }
  }

  /// 走系统分享面板把 JSON 文本发出去（长文本用这个比文件方便）
  static Future<ExportResult> share(AppState state, {DateTime? now}) async {
    try {
      await _channel.invokeMethod<void>('shareText', {
        'subject': 'LangoBei 学习数据',
        'text': json(state, now: now),
      });
      return const ExportResult(true, '已打开分享面板');
    } on PlatformException catch (e) {
      return ExportResult(false, e.message ?? '分享失败');
    } on MissingPluginException {
      return const ExportResult(false, '当前平台不支持分享');
    }
  }

  /// 兜底：复制到剪贴板，任何平台都能用
  static Future<void> copyToClipboard(AppState state, {DateTime? now}) async {
    await Clipboard.setData(ClipboardData(text: json(state, now: now)));
  }
}
