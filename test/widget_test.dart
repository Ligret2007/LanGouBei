import 'package:flutter/material.dart' show Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:langobei/theme.dart';
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
    test('默认跟随系统、默认主题蓝', () {
      final s = Settings();
      expect(s.themeMode, ThemeModeSetting.system);
      expect(s.seedHue, 229);
      expect(s.seedSaturation, 1.0);
      expect(s.seedLightness, 0.55);
    });

    test('外观字段能存能读', () {
      final s = Settings(
        themeMode: ThemeModeSetting.dark,
        seedHue: 12.5,
        seedSaturation: 0.42,
        seedLightness: 0.61,
      );
      final back = Settings.fromJson(s.toJson());
      expect(back.themeMode, ThemeModeSetting.dark);
      expect(back.seedHue, closeTo(12.5, 0.001));
      expect(back.seedSaturation, closeTo(0.42, 0.001));
      expect(back.seedLightness, closeTo(0.61, 0.001));
    });

    test('老数据没有外观字段也能读', () {
      final back = Settings.fromJson({'onboarded': true, 'bank': 'ext'});
      expect(back.themeMode, ThemeModeSetting.system);
      expect(back.seedHue, 229);
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
