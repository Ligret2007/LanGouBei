import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langobei/theme.dart';
import 'package:langobei/screens/more_screen.dart';
import 'package:langobei/widgets/flip_card.dart';
import 'package:langobei/app_state.dart';
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
