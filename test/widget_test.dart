import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langobei/theme.dart';
import 'package:langobei/export_service.dart';
import 'package:langobei/screens/more_screen.dart';
import 'package:langobei/screens/study_screen.dart';
import 'package:langobei/screens/onboarding_screen.dart';
import 'package:langobei/widgets/bank_option.dart';
import 'package:langobei/widgets/year_wheel.dart';
import 'package:langobei/widgets/flip_card.dart';
import 'package:langobei/app_state.dart';
import 'package:langobei/bank/bank_registry.dart';
import 'package:langobei/bank/bank_source.dart';
import 'package:langobei/bank/word_bank.dart';
import 'package:langobei/bank/bank_storage.dart';
import 'package:langobei/models/word.dart';

void main() {
  group('WordProgress', () {
    test('最近三次全部认识才算掌握', () {
      final p = WordProgress();
      p.push(2);
      p.push(2);
      expect(p.mastered, isFalse, reason: '只有两次');
      p.push(2);
      expect(p.mastered, isTrue);
    });

    test('中间夹一次模糊就不算掌握', () {
      final p = WordProgress();
      p.push(2);
      p.push(1);
      p.push(2);
      expect(p.mastered, isFalse);
      p.push(2);
      expect(p.mastered, isFalse, reason: '最近三次是 1,2,2');
      p.push(2);
      expect(p.mastered, isTrue, reason: '最近三次是 2,2,2');
    });

    test('只保留最近三次', () {
      final p = WordProgress();
      for (var i = 0; i < 6; i++) {
        p.push(2);
      }
      expect(p.recent.length, 3);
    });

    test('确定认识强制掌握', () {
      final p = WordProgress()..forceMastered();
      expect(p.mastered, isTrue);
    });

    test('json 往返', () {
      final p = WordProgress(knowCount: 2, fuzzyCount: 1, unknownCount: 3, inWrongBook: true)
        ..push(2)
        ..push(0);
      final back = WordProgress.fromJson(p.toJson());
      expect(back.knowCount, 2);
      expect(back.unknownCount, 3);
      expect(back.inWrongBook, isTrue);
      expect(back.recent, [2, 0]);
    });
  });

  group('DayStat / Settings', () {
    test('正确率', () {
      expect(DayStat().accuracy, 0);
      expect(DayStat(choices: 4, correct: 3).accuracy, 0.75);
    });

    test('Settings json 往返', () {
      final s = Settings(onboarded: true, bank: 'ext', examYear: 2027);
      final back = Settings.fromJson(s.toJson());
      expect(back.onboarded, isTrue);
      expect(back.bank, 'ext');
      expect(back.examYear, 2027);
    });
  });

  test('dayKey 补零', () {
    expect(AppState.dayKey(DateTime(2026, 1, 5)), '2026-01-05');
  });

  group('外观设置', () {
    test('默认跟随系统、主题色是默认蓝', () {
      final s = Settings();
      expect(s.themeMode, ThemeModeSetting.system);
      expect(s.themePreset, 'default');
      expect(seedForPreset(presetById(s.themePreset)), defaultSeedColor);
    });

    test('外观字段能存能读', () {
      final s = Settings(themeMode: ThemeModeSetting.dark, themePreset: 'purple');
      final back = Settings.fromJson(s.toJson());
      expect(back.themeMode, ThemeModeSetting.dark);
      expect(back.themePreset, 'purple');
    });

    test('老数据没有外观字段也能读', () {
      final back = Settings.fromJson({'onboarded': true, 'bank': 'ext'});
      expect(back.themeMode, ThemeModeSetting.system);
      expect(back.themePreset, 'default');
    });

    test('四选一：默认 / 深绿 / 紫色，外加一个留空', () {
      expect(kThemePresets.length, 4);
      expect(kThemePresets.where((p) => p.reserved).length, 1);
      expect(
        kThemePresets.where((p) => !p.reserved).map((p) => p.label).toList(),
        ['默认', '深绿', '紫色'],
      );
      expect(kThemePresets.last.reserved, isTrue);
    });

    test('留空的格子选不中，未知 id 也退回默认', () {
      expect(presetById('reserved').id, 'default', reason: '留空格不能成为当前主题');
      expect(presetById('不存在的').id, 'default');
      expect(presetById('green').id, 'green');
    });

    test('每个预设的颜色就是它声明的 HSL', () {
      for (final p in kThemePresets) {
        if (p.reserved) continue;
        final hsv = HSVColor.fromColor(seedForPreset(p));
        expect(hsv.hue, closeTo(p.hue, 1.0), reason: '${p.label} 的色相');
      }
    });

    test('深绿更绿，紫色蓝红都压过绿', () {
      final green = seedForPreset(presetById('green'));
      final blue = seedForPreset(presetById('default'));
      final purple = seedForPreset(presetById('purple'));

      expect(green.g, greaterThan(green.b), reason: '深绿：绿分量最高');
      expect(blue.b, greaterThan(blue.r), reason: '默认：偏蓝');
      expect(purple.b, greaterThan(purple.g), reason: '紫色：蓝分量压过绿');
      expect(purple.r, greaterThan(purple.g), reason: '紫色：红分量也压过绿');
    });

    test('老数据的自由 HSL 会迁到最接近的预设', () {
      expect(Settings.fromJson({'hue': 150.0}).themePreset, 'green');
      expect(Settings.fromJson({'hue': 268.0}).themePreset, 'purple');
      // 随手拖到的橙色离三个预设都远，回到默认
      expect(Settings.fromJson({'hue': 30.0}).themePreset, 'default');
    });

    test('HSL 229° 是蓝色系，0° 是红色系', () {
      final blue = seedColorFrom(229, 1, 0.55);
      expect(blue.b, greaterThan(blue.r));
      final red = seedColorFrom(0, 1, 0.55);
      expect(red.r, greaterThan(red.b));
    });

    test('明度会被夹在安全区间', () {
      final tooBright = seedColorFrom(200, 1, 1.0);
      final tooDark = seedColorFrom(200, 1, 0.0);
      expect(tooBright, isNot(equals(Colors.white)));
      expect(tooDark, isNot(equals(Colors.black)));
    });
  });

  group('词库分级标签', () {
    Word word(String level) => Word(
          id: 'w-$level',
          word: 'demo',
          phonetic: '/x/',
          pos: 'n.',
          meaning: '释义',
          level: level,
          tier: 'core',
        );

    test('标签直接显示原文 easy / normal / hard / extra', () {
      expect(word('easy').levelLabel, 'easy');
      expect(word('normal').levelLabel, 'normal');
      expect(word('hard').levelLabel, 'hard');
      expect(word('extra').levelLabel, 'extra');
    });

    test('四个分级颜色互不相同，深浅色各一套', () {
      final light = kLevels.map((l) => levelColor(l, Brightness.light)).toSet();
      final dark = kLevels.map((l) => levelColor(l, Brightness.dark)).toSet();
      expect(light.length, kLevels.length);
      expect(dark.length, kLevels.length);
      for (final l in kLevels) {
        expect(levelColor(l, Brightness.dark), isNot(levelColor(l, Brightness.light)));
      }
    });

    test('颜色语义：easy 绿、normal 黄、hard 橙、extra 红', () {
      double hue(String level) => HSVColor.fromColor(levelColor(level, Brightness.light)).hue;
      expect(hue('easy'), inInclusiveRange(120, 170), reason: '绿');
      expect(hue('normal'), inInclusiveRange(40, 60), reason: '黄');
      expect(hue('hard'), inInclusiveRange(20, 40), reason: '橙');
      // 红色色相在 0 附近，HSV 会回绕成 358 左右，两头都要认
      final red = hue('extra');
      expect(red < 15 || red > 345, isTrue, reason: '红，实际 $red');
    });

    test('未知分级退回黄，不会崩', () {
      expect(levelColor('unknown-level', Brightness.light), kLevelNormal);
    });
  });

  group('卡片上的分级标签', () {
    Word word(String level) => Word(
          id: 'x-$level',
          word: 'demo',
          phonetic: '/x/',
          pos: 'n.',
          meaning: '释义',
          level: level,
          tier: 'core',
        );

    testWidgets('四个分级都显示原文，颜色跟着分级走', (tester) async {
      for (final level in kLevels) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(Brightness.light, defaultSeedColor),
            home: Scaffold(body: FlipWordCard(word: word(level), revealed: false)),
          ),
        );
        await tester.pumpAndSettle();
        final chip = tester.widget<TagChip>(find.byType(TagChip).first);
        expect(chip.text, level, reason: '$level 的标签应该是原文');
        expect(chip.color, levelColor(level, Brightness.light));
      }
    });

    testWidgets('深色模式换成更亮的那一套', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark, defaultSeedColor),
          home: Scaffold(body: FlipWordCard(word: word('extra'), revealed: false)),
        ),
      );
      await tester.pumpAndSettle();
      final chip = tester.widget<TagChip>(find.byType(TagChip).first);
      expect(chip.text, 'extra');
      expect(chip.color, kLevelExtraDark);
    });

    testWidgets('翻面后的释义面同样带分级色', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light, defaultSeedColor),
          home: Scaffold(body: FlipWordCard(word: word('hard'), revealed: true)),
        ),
      );
      await tester.pumpAndSettle();
      final chip = tester.widget<TagChip>(find.byType(TagChip).first);
      expect(chip.text, 'hard');
      expect(chip.color, kLevelHard);
    });
  });

  group('主题色只动醒目位，白色部分不变', () {
    final seeds = {
      for (final p in kThemePresets)
        if (!p.reserved) p.id: seedForPreset(p),
    };

    test('三个预设的主色确实不一样', () {
      final primaries = seeds.values
          .map((s) => buildTheme(Brightness.light, s).colorScheme.primary)
          .toSet();
      expect(primaries.length, seeds.length);
    });

    test('主色跟着预设的色相走', () {
      for (final entry in seeds.entries) {
        final primary = buildTheme(Brightness.light, entry.value).colorScheme.primary;
        expect(
          HSVColor.fromColor(primary).hue,
          closeTo(HSVColor.fromColor(entry.value).hue, 16),
          reason: '${entry.key} 的主色',
        );
      }
    });

    test('浅色下白色部分与主题色无关', () {
      final themes = seeds.values.map((s) => buildTheme(Brightness.light, s)).toList();
      final first = themes.first.colorScheme;
      expect(first.surface, Colors.white);
      expect(themes.map((t) => t.scaffoldBackgroundColor).toSet().length, 1);
      for (final t in themes.skip(1)) {
        final c = t.colorScheme;
        expect(c.surface, first.surface);
        expect(c.surfaceContainer, first.surfaceContainer);
        expect(c.surfaceContainerLow, first.surfaceContainerLow);
        expect(c.surfaceContainerHigh, first.surfaceContainerHigh);
        expect(c.surfaceContainerHighest, first.surfaceContainerHighest);
        expect(c.onSurface, first.onSurface);
        expect(c.onSurfaceVariant, first.onSurfaceVariant);
        expect(c.outline, first.outline);
        expect(c.outlineVariant, first.outlineVariant);
      }
    });

    test('深色下白色部分同样与主题色无关', () {
      final themes = seeds.values.map((s) => buildTheme(Brightness.dark, s)).toList();
      final first = themes.first;
      for (final t in themes.skip(1)) {
        expect(t.colorScheme.surface, first.colorScheme.surface);
        expect(t.colorScheme.surfaceContainerHighest, first.colorScheme.surfaceContainerHighest);
        expect(t.colorScheme.onSurface, first.colorScheme.onSurface);
        expect(t.scaffoldBackgroundColor, first.scaffoldBackgroundColor);
      }
    });

    testWidgets('知新页标题用的是主题色', (tester) async {
      final theme = buildTheme(Brightness.light, seedForPreset(presetById('purple')));
      await tester.pumpWidget(
        MaterialApp(theme: theme, home: StudyScreen(state: AppState())),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('知新')).style?.color,
        theme.colorScheme.primary,
      );
    });
  });

  group('词库与引导', () {
    test('两套词库的名字与解释', () {
      expect(bankTitle(kBankCore), '高考：我是菜鸟');
      expect(bankTitle(kBankExt), '高考：我是大神');
      expect(bankSubtitle(kBankCore), '3014 词 · 基础到进阶，覆盖高考高频');
      expect(bankSubtitle(kBankExt), '3540 词 · 在菜鸟的基础上增加低频词');
    });

    test('年份滚轮的范围是 2027-2040', () {
      expect(kExamYearMin, 2027);
      expect(kExamYearMax, 2040);
      expect(kExamYears.first, 2027);
      expect(kExamYears.last, 2040);
      expect(kExamYears.length, 14);
    });

    test('越界的年份会被收回区间', () {
      expect(clampExamYear(null), 2027);
      expect(clampExamYear(2026), 2027);
      expect(clampExamYear(2033), 2033);
      expect(clampExamYear(2041), 2040);
    });

    test('切换词库会改设置并通知', () async {
      final s = AppState.withRegistry(
        await WordBankRegistry.fromAssets(storage: MemoryBankStorage()),
      );
      await s.setBank(kBankCore);
      var notified = 0;
      s.addListener(() => notified++);

      await s.setBank(kBankExt);
      expect(s.settings.bank, kBankExt);
      expect(s.bankTotal, 3540, reason: '大神库是全量');
      await s.setBank(kBankExt);
      expect(notified, 1, reason: '同一套词库重复选不该再通知');
      await s.setBank('乱七八糟');
      expect(s.settings.bank, kBankCore, reason: '非法值回落到菜鸟');
      expect(s.bankTotal, 3014);
    });

    testWidgets('引导四页必须逐页点下一步', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light, defaultSeedColor),
        home: OnboardingScreen(state: AppState()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('跳过'), findsNothing);
      expect(find.text('下一步'), findsOneWidget);
    });

    testWidgets('第二页是两套高考词库，选大神会带上年份走完引导', (tester) async {
      final state = AppState();
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light, defaultSeedColor),
        home: OnboardingScreen(state: state),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(find.text('高考：我是菜鸟'), findsOneWidget);
      expect(find.text('高考：我是大神'), findsOneWidget);
      // 四级 / 雅思继续占位，但是点不动
      expect(find.text('四级词汇'), findsOneWidget);
      expect(find.text('雅思 6.5 词汇'), findsOneWidget);
      expect(find.text('敬请期待'), findsNWidgets(2));

      await tester.tap(find.text('高考：我是大神'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      // 第三页：年份滚轮，默认第一年
      expect(find.text('哪一年参加高考？'), findsOneWidget);
      expect(find.byType(ListWheelScrollView), findsOneWidget);
      expect(find.text('2027 年'), findsWidgets);

      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('开始背单词'));
      await tester.pumpAndSettle();

      expect(state.settings.onboarded, isTrue);
      expect(state.settings.bank, kBankExt);
      expect(state.settings.examYear, 2027);
    });

    testWidgets('年份滚轮能滑到更晚的年份并带进设置', (tester) async {
      final state = AppState();
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light, defaultSeedColor),
        home: OnboardingScreen(state: state),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(find.textContaining('距离 2027 年高考'), findsOneWidget);

      // 往上滑 = 往后选，一次拖三个刻度
      await tester.drag(find.byType(ListWheelScrollView), const Offset(0, -168));
      await tester.pumpAndSettle();

      final chip = tester.widget<Text>(find.textContaining('年高考还有')).data!;
      final picked = int.parse(RegExp(r'距离 (\d+) 年高考').firstMatch(chip)!.group(1)!);
      expect(picked, greaterThan(2027), reason: '滑动之后不该还停在 2027');

      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('开始背单词'));
      await tester.pumpAndSettle();
      expect(state.settings.examYear, picked);
    });

    testWidgets('滚轮只有 2027-2040，往回滑不会跑出范围', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light, defaultSeedColor),
        home: OnboardingScreen(state: AppState()),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      final wheel = tester.widget<ListWheelScrollView>(find.byType(ListWheelScrollView));
      expect(wheel.childDelegate.estimatedChildCount, 14);

      await tester.drag(find.byType(ListWheelScrollView), const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(find.text('2026 年'), findsNothing);
      expect(find.textContaining('距离 2027 年高考'), findsOneWidget, reason: '到顶就停在 2027');
    });
  });

  group('知新队列（伪随机 + 难度均匀）', () {
    Word word(String id, String level, {String tier = 'core'}) => Word(
          id: id,
          word: id,
          phonetic: '/x/',
          pos: 'n.',
          meaning: '释义',
          level: level,
          tier: tier,
        );

    /// 一套按占比的迷你词库：easy 52 / normal 29 / hard 19（和菜鸟库的比例一致）
    AppState bank() {
      final s = AppState();
      s.settings = Settings(bank: kBankCore, onboarded: true);
      s.allWords = [
        for (var i = 0; i < 52; i++) word('e${i.toString().padLeft(2, '0')}', 'easy'),
        for (var i = 0; i < 29; i++) word('n${i.toString().padLeft(2, '0')}', 'normal'),
        for (var i = 0; i < 19; i++) word('h${i.toString().padLeft(2, '0')}', 'hard'),
      ];
      return s;
    }

    List<String> idsOf(List<Word> ws) => [for (final w in ws) w.id];

    test('不再按字母顺序；同一个种子必然给出同一条队列', () {
      final s = bank();
      final a = s.pickStudyWords(seed: 2026);
      final b = s.pickStudyWords(seed: 2026);
      expect(idsOf(a), idsOf(b), reason: '同种子可复现');

      final alphabetical = [...s.allWords]..sort((x, y) => x.id.compareTo(y.id));
      expect(idsOf(a), isNot(idsOf(alphabetical.take(20).toList())), reason: '不能还是 abc 排下来');
      expect(idsOf(s.pickStudyWords(seed: 7)), isNot(idsOf(a)), reason: '换个种子顺序就不同');
    });

    test('20 张里各难度的数量贴近整库占比', () {
      final s = bank();
      final queue = s.pickStudyWords(size: 20, seed: 42);
      expect(queue.length, 20);
      final counts = <String, int>{};
      for (final w in queue) {
        counts[w.level] = (counts[w.level] ?? 0) + 1;
      }
      expect((counts['easy']! - 10.4).abs(), lessThanOrEqualTo(1), reason: '实际 ${counts['easy']}');
      expect((counts['normal']! - 5.8).abs(), lessThanOrEqualTo(1), reason: '实际 ${counts['normal']}');
      expect((counts['hard']! - 3.8).abs(), lessThanOrEqualTo(1), reason: '实际 ${counts['hard']}');
      expect(counts['extra'], isNull, reason: '菜鸟库里没有 extra');
    });

    test('每个难度都在队列里，且打散开（不连续堆在一起）', () {
      final s = bank();
      final levels = [for (final w in s.pickStudyWords(size: 20, seed: 11)) w.level];
      for (final l in ['easy', 'normal', 'hard']) {
        expect(levels.contains(l), isTrue, reason: '$l 应该露面');
      }
      var maxRun = 1;
      var run = 1;
      for (var i = 1; i < levels.length; i++) {
        run = levels[i] == levels[i - 1] ? run + 1 : 1;
        if (run > maxRun) maxRun = run;
      }
      expect(maxRun, lessThanOrEqualTo(4), reason: '最长连串 $maxRun：$levels');
    });

    test('没见过的词优先，见过的词按最久没复习排在本级后面', () {
      final s = bank();
      s.progress['h18'] = WordProgress()
        ..knowCount = 1
        ..lastSeenMs = 1; // 很久没复习
      s.progress['h17'] = WordProgress()
        ..knowCount = 1
        ..lastSeenMs = 9999999999; // 刚复习过

      final ids = idsOf(s.pickStudyWords(size: 100, seed: 5));
      expect(ids.indexOf('h18'), greaterThan(ids.indexOf('h00')), reason: '见过的排在没见过的后面');
      expect(ids.indexOf('h18'), lessThan(ids.indexOf('h17')), reason: '越久没复习越靠前');
    });

    test('已掌握和错题本里的词都不进队列', () {
      final s = bank();
      s.progress['e00'] = WordProgress()..forceMastered();
      s.progress['n00'] = WordProgress()..inWrongBook = true;

      final ids = idsOf(s.pickStudyWords(size: 100, seed: 9));
      expect(ids, isNot(contains('e00')));
      expect(ids, isNot(contains('n00')));
      expect(ids.length, 98);
    });

    test('换词库后队列按新词库重排，进度仍然认得', () async {
      final s = AppState.withRegistry(
        await WordBankRegistry.fromAssets(storage: MemoryBankStorage()),
      );
      await s.setBank(kBankCore);

      final seenId = s.allWords.first.id;
      s.progress[seenId] = WordProgress()..forceMastered();
      final core = idsOf(s.pickStudyWords(size: 4000, seed: 3));
      expect(core, isNot(contains(seenId)), reason: '已掌握的不进队列');

      await s.setBank(kBankExt);
      final ext = idsOf(s.pickStudyWords(size: 4000, seed: 3));
      expect(ext.length, greaterThan(core.length), reason: '大全库队列更长');
      expect(ext, isNot(contains(seenId)), reason: '背过的词换库也还是背过的');
    });
  });

  group('更多页', () {
    /// 假词库：不读 assets、不碰原生通道，切库在微任务里就完成
    WordBankRegistry fakeRegistry() {
      WordBankMeta meta(String id, String name, String subtitle) => WordBankMeta(
            id: id,
            name: name,
            subtitle: subtitle,
            builtin: true,
          );
      Word w(String id, String level) => Word(
            id: id,
            word: id,
            phonetic: '/x/',
            pos: 'n.',
            meaning: '释义',
            level: level,
            tier: 'core',
          );
      return WordBankRegistry(
        storage: MemoryBankStorage(),
        builtins: [
          BankSummary(meta: meta('core', '高考：我是菜鸟', '基础到进阶，覆盖高考高频'), wordCount: 3),
          BankSummary(meta: meta('ext', '高考：我是大神', '全部 3540 词'), wordCount: 4),
        ],
        sources: {
          'core': MemoryBankSource(
            meta: meta('core', '高考：我是菜鸟', '基础到进阶，覆盖高考高频'),
            words: [w('a', 'easy'), w('b', 'normal'), w('c', 'hard')],
          ),
          'ext': MemoryBankSource(
            meta: meta('ext', '高考：我是大神', '全部 3540 词'),
            words: [w('a', 'easy'), w('b', 'normal'), w('c', 'hard'), w('d', 'extra')],
          ),
        },
      );
    }

    Future<AppState> pumpMore(WidgetTester tester, {AppState? state}) async {
      final s = state ?? AppState.withRegistry(fakeRegistry());
      // App 里是外层 Shell 监听状态后重建页面，这里补上同样的监听
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light, defaultSeedColor),
        home: ListenableBuilder(
          listenable: s,
          builder: (context, _) => MoreScreen(state: s),
        ),
      ));
      await tester.pumpAndSettle();
      return s;
    }

    /// 页面比测试视口长，列表懒加载；没构建出来就先滚到它出现
    Future<void> scrollTo(WidgetTester tester, Finder finder) async {
      if (finder.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          finder,
          220,
          scrollable: find.byType(Scrollable).first,
        );
      } else {
        await tester.ensureVisible(finder);
      }
      await tester.pumpAndSettle();
    }

    testWidgets('更多页只有功能卡片，没有留白卡片与数据说明', (tester) async {
      await pumpMore(tester);
      expect(find.text('这里先留白'), findsNothing);
      expect(find.textContaining('账号同步'), findsNothing);
      expect(find.textContaining('把学习进度、每日记录和外观设置导出成一个 JSON 文件'), findsNothing);
    });

    testWidgets('更多里能切词库', (tester) async {
      final s = await pumpMore(tester);
      expect(s.settings.bank, kBankCore);

      await tester.ensureVisible(find.text('高考：我是大神'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('高考：我是大神'));
      await tester.pumpAndSettle();

      expect(s.settings.bank, kBankExt);
      expect(find.textContaining('已切到「高考：我是大神」'), findsOneWidget);
    });

    testWidgets('粘贴 JSON 导入：坏文本只提示，不崩', (tester) async {
      final s = await pumpMore(tester);

      await tester.tap(find.text('导入词库'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('粘贴 JSON'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '这不是 JSON');
      await tester.tap(find.text('导入'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('导入失败'), findsOneWidget);
      expect(s.importedBanks, isEmpty);
      expect(s.activeBank?.id, isNot('imported'));
    });

    testWidgets('粘贴 JSON 导入：好文本进列表并切过去', (tester) async {
      final s = await pumpMore(tester);

      await tester.tap(find.text('导入词库'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('粘贴 JSON'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        '{"name":"我的小词库","words":[{"word":"alpha","meaning":"第一个"},{"word":"beta"}]}',
      );
      await tester.tap(find.text('导入'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(s.activeBank?.name, '我的小词库');
      expect(s.bankTotal, 2);
      expect(find.text('我的小词库'), findsWidgets);
      expect(find.textContaining('已导入「我的小词库」'), findsOneWidget);
      expect(find.textContaining('已导入 1 个词库'), findsOneWidget);
    });

    testWidgets('四级与雅思词库为占位，点了不动作', (tester) async {
      final s = await pumpMore(tester);

      final options = tester.widgetList<BankOption>(find.byType(BankOption)).toList();
      expect(options.length, 4, reason: '菜鸟 / 大神 + 四级 / 雅思占位');
      expect(options.map((o) => o.title).toList(), [
        '高考：我是菜鸟',
        '高考：我是大神',
        '四级词汇',
        '雅思 6.5 词汇',
      ]);
      expect(options[0].disabled, isFalse);
      expect(options[1].disabled, isFalse);
      expect(options[2].disabled, isTrue);
      expect(options[3].disabled, isTrue);
      expect(find.text('敬请期待'), findsNWidgets(2));

      // 点占位不会改词库
      await tester.ensureVisible(find.text('四级词汇'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('四级词汇'));
      await tester.pumpAndSettle();
      expect(s.settings.bank, kBankCore);
    });

    testWidgets('点高考年份能弹滚轮改年份', (tester) async {
      final s = await pumpMore(tester);
      expect(s.settings.examYear, isNull);

      await scrollTo(tester, find.text('高考年份'));
      expect(find.text('未设置'), findsOneWidget);

      await tester.tap(find.text('高考年份'));
      await tester.pumpAndSettle();
      expect(find.byType(YearWheel), findsOneWidget);
      expect(find.text('2027 年'), findsWidgets);

      await tester.drag(find.byType(YearWheel), const Offset(0, -168));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(s.settings.examYear, greaterThan(2027));
      expect(find.textContaining('高考年份已改为'), findsOneWidget);

      // 关掉弹窗后列表可能又滚走了，滚回来再看这一行
      await scrollTo(tester, find.text('高考年份'));
      expect(find.text('${s.settings.examYear} 年'), findsOneWidget);
      expect(find.text('未设置'), findsNothing);
    });

    testWidgets('弹窗点取消不改年份', (tester) async {
      final s = await pumpMore(tester);

      await scrollTo(tester, find.text('高考年份'));
      await tester.tap(find.text('高考年份'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(YearWheel), const Offset(0, -168));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(s.settings.examYear, isNull);
      expect(find.text('未设置'), findsOneWidget);
    });
  });

  group('导出用户数据', () {
    AppState sample() {
      final s = AppState();
      s.allWords = const [
        Word(
          id: 'apple-easy-1',
          word: 'apple',
          phonetic: '/aepl/',
          pos: 'n.',
          meaning: '苹果',
          level: 'easy',
          tier: 'ext',
        ),
        Word(
          id: 'book-normal-2',
          word: 'book',
          phonetic: '/buk/',
          pos: 'n.',
          meaning: '书',
          level: 'normal',
          tier: 'ext',
        ),
      ];
      s.progress['apple-easy-1'] = WordProgress()
        ..knowCount = 3
        ..fuzzyCount = 1
        ..inWrongBook = true;
      s.progress['book-normal-2'] = WordProgress()..knowCount = 1;
      s.daily['2026-10-17'] = DayStat(choices: 10, correct: 6);
      s.streak = 4;
      s.lastStudyDay = '2026-10-17';
      s.settings = Settings(bank: 'ext', examYear: 2027, themePreset: 'green');
      return s;
    }

    /// 按钮在长页面下半部分，测试视口装不下；列表是懒加载的，
    /// 所以还没构建出来时要先滚到它出现为止
    Future<void> tapButton(WidgetTester tester, String label) async {
      final finder = find.text(label);
      if (finder.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          finder,
          260,
          scrollable: find.byType(Scrollable).first,
        );
      } else {
        await tester.ensureVisible(finder);
      }
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    test('文件名带时间戳且是 .json', () {
      expect(ExportService.fileName(DateTime(2026, 10, 17, 22, 30, 45)),
          'langobei-20261017-223045.json');
      expect(ExportService.fileName(DateTime(2026, 1, 2, 3, 4, 5)),
          'langobei-20260102-030405.json');
    });

    test('导出内容带上元信息与统计', () {
      final s = sample();
      final out = ExportService.payload(s, now: DateTime(2026, 10, 17, 22, 30));
      expect(out['app'], 'LangoBei');
      expect(out['format'], ExportService.format);
      expect(out['exportedAt'], startsWith('2026-10-17T22:30'));
      expect(out['utcOffsetMinutes'], isA<int>());

      final summary = out['summary'] as Map<String, dynamic>;
      expect(summary['know'], 4, reason: '两个词各 3 次和 1 次认识');
      expect(summary['fuzzy'], 1);
      expect(summary['wrong'], 1);
      expect(summary['streak'], 4);
      expect(summary['themePreset'], 'green');
      expect(summary['examYear'], 2027);
      expect(summary['today'], containsPair('choices', 10));
    });

    test('data 段与落盘存档完全一致，可直接用来恢复', () {
      final s = sample();
      final out = ExportService.payload(s);
      expect(out['data'], s.toSnapshot());

      final back = jsonDecode(ExportService.json(s)) as Map<String, dynamic>;
      final data = back['data'] as Map<String, dynamic>;
      expect((data['progress'] as Map).length, 2);
      expect((data['daily'] as Map)['2026-10-17'], {'c': 10, 'r': 6});
      expect((data['settings'] as Map)['preset'], 'green');
      expect(data['streak'], 4);
    });

    test('导出的 JSON 是格式化过的，能直接打开看', () {
      final text = ExportService.json(sample());
      expect(text, contains('\n  '));
      expect(jsonDecode(text), isA<Map<String, dynamic>>());
    });

    testWidgets('点「导出为文件」把 JSON 交给原生通道', (tester) async {
      String? sentName;
      String? sentContent;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('langobei/export'),
        (call) async {
          if (call.method == 'saveToDownloads') {
            final args = Map<String, Object?>.from(call.arguments as Map);
            sentName = args['filename'] as String?;
            sentContent = args['content'] as String?;
            return '下载/$sentName';
          }
          return null;
        },
      );

      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light, defaultSeedColor),
        home: MoreScreen(state: sample()),
      ));
      await tester.pumpAndSettle();
      await tapButton(tester, '导出为文件');

      expect(sentName, endsWith('.json'));
      expect(sentContent, contains('"app": "LangoBei"'));
      expect(sentContent, contains('apple-easy-1'));
      expect(find.textContaining('已导出到 下载/'), findsOneWidget);
    });

    testWidgets('点「复制 JSON」写进剪贴板', (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );

      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light, defaultSeedColor),
        home: MoreScreen(state: sample()),
      ));
      await tester.pumpAndSettle();
      await tapButton(tester, '复制 JSON');

      final set = calls.firstWhere((c) => c.method == 'Clipboard.setData');
      expect((set.arguments as Map)['text'], contains('"format": 1'));
      expect(find.textContaining('已复制'), findsOneWidget);
    });

    testWidgets('原生报错时给出失败提示而不是崩溃', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('langobei/export'),
        (call) async => throw PlatformException(code: 'save_failed', message: '磁盘满了'),
      );

      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light, defaultSeedColor),
        home: MoreScreen(state: sample()),
      ));
      await tester.pumpAndSettle();
      await tapButton(tester, '导出为文件');

      expect(find.text('导出失败：磁盘满了'), findsOneWidget);
    });
  });

  group('更多页的主题色四选一', () {
    Future<AppState> pumpMore(WidgetTester tester) async {
      final state = AppState();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light, defaultSeedColor),
          home: MoreScreen(state: state),
        ),
      );
      await tester.pumpAndSettle();
      return state;
    }

    testWidgets('四格都在，留空格标着待定', (tester) async {
      await pumpMore(tester);
      expect(find.text('默认'), findsOneWidget);
      expect(find.text('深绿'), findsOneWidget);
      expect(find.text('紫色'), findsOneWidget);
      expect(find.text('待定'), findsOneWidget);
    });

    testWidgets('点深绿就换主题，落盘值跟着变', (tester) async {
      final state = await pumpMore(tester);
      await tester.tap(find.text('深绿'));
      await tester.pumpAndSettle();
      expect(state.settings.themePreset, 'green');
    });

    testWidgets('点留空的格子只弹提示，主题不动', (tester) async {
      final state = await pumpMore(tester);
      await tester.tap(find.text('待定'));
      await tester.pump();
      expect(find.text('这一格先留空，想好加什么颜色再放进来'), findsOneWidget);
      expect(state.settings.themePreset, 'default');
    });
  });

  test('Rating 编码', () {
    expect(Rating.unknown.code, 0);
    expect(Rating.fuzzy.code, 1);
    expect(Rating.know.code, 2);
    expect(Rating.confirm.code, 2);
  });

  group('AppState.answer', () {
    Word word(String id) => Word(
          id: id,
          word: id,
          phonetic: '/x/',
          pos: 'n.',
          meaning: '释义',
          level: 'easy',
          tier: 'core',
        );

    test('超过 3 秒会悄悄降级成模糊', () {
      final s = AppState();
      s.answer(word('slow'), Rating.know, elapsedMs: 3200, fromReflect: false);
      final p = s.progress['slow']!;
      expect(p.recent, [1], reason: '选了认识，但停留超 3 秒，只记模糊');
      expect(p.knowCount, 1, reason: '明面上的选择次数照常统计');
    });

    test('3 秒内正常记为认识', () {
      final s = AppState();
      s.answer(word('fast'), Rating.know, elapsedMs: 1200, fromReflect: false);
      expect(s.progress['fast']!.recent, [2]);
    });

    test('选不认识就进错题本', () {
      final s = AppState();
      s.answer(word('bad'), Rating.unknown, elapsedMs: 800, fromReflect: false);
      expect(s.progress['bad']!.inWrongBook, isTrue);
    });

    test('反思里选认识移出错题本', () {
      final s = AppState();
      s.answer(word('w'), Rating.unknown, elapsedMs: 800, fromReflect: false);
      expect(s.progress['w']!.inWrongBook, isTrue);
      s.answer(word('w'), Rating.know, elapsedMs: 800, fromReflect: true);
      expect(s.progress['w']!.inWrongBook, isFalse);
    });

    test('反思里选不认识仍然留在错题本', () {
      final s = AppState();
      s.answer(word('w2'), Rating.unknown, elapsedMs: 800, fromReflect: false);
      s.answer(word('w2'), Rating.unknown, elapsedMs: 800, fromReflect: true);
      expect(s.progress['w2']!.inWrongBook, isTrue);
    });

    test('确定认识直接掌握并移出错题本', () {
      final s = AppState();
      s.answer(word('c'), Rating.unknown, elapsedMs: 500, fromReflect: false);
      s.answer(word('c'), Rating.confirm, elapsedMs: 500, fromReflect: false);
      final p = s.progress['c']!;
      expect(p.mastered, isTrue);
      expect(p.inWrongBook, isFalse);
    });

    test('连续三次认识才掌握', () {
      final s = AppState();
      for (var i = 0; i < 2; i++) {
        s.answer(word('e'), Rating.know, elapsedMs: 900, fromReflect: false);
      }
      expect(s.progress['e']!.mastered, isFalse);
      s.answer(word('e'), Rating.know, elapsedMs: 900, fromReflect: false);
      expect(s.progress['e']!.mastered, isTrue);
    });

    test('每日选择次数与正确率会累计', () {
      final s = AppState();
      s.answer(word('a1'), Rating.know, elapsedMs: 500, fromReflect: false);
      s.answer(word('a2'), Rating.unknown, elapsedMs: 500, fromReflect: false);
      final stat = s.todayStat;
      expect(stat.choices, 2);
      expect(stat.correct, 1);
      expect(stat.accuracy, 0.5);
    });
  });
}
