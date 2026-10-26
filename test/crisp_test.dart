import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langobei/crisp.dart';

void main() {
  group('PixelSnappingTextScaler', () {
    test('2.0 像素比 + 1.15 系统字号：吸附后「字号×像素比」是整数', () {
      const dpr = 2.0;
      final s = PixelSnappingTextScaler(const TextScaler.linear(1.15), 1 / dpr);

      // 12×1.15 = 13.8 → 14.0（28px）；16×1.15 = 18.4 → 18.5（37px）
      expect(s.scale(12), 14.0);
      expect(s.scale(16), 18.5);
      expect(s.scale(12) * dpr, 28.0);
      expect(s.scale(16) * dpr, 37.0);

      for (final size in [10.0, 11.0, 12.0, 13.0, 14.0, 16.0, 18.0, 20.0, 22.0, 28.0, 36.0]) {
        final px = s.scale(size) * dpr;
        expect(px, closeTo(px.roundToDouble(), 1e-9), reason: '$size → $px px 不是整像素');
        // 吸附幅度不超过半个设备像素，肉眼看不出来
        expect((s.scale(size) - size * 1.15).abs() * dpr, lessThanOrEqualTo(0.5 + 1e-9));
      }
    });

    test('1.0 缩放 + 整数字号：原样返回', () {
      final s = PixelSnappingTextScaler(TextScaler.noScaling, 1 / 2.0);
      expect(s.scale(16), 16.0);
      expect(s.scale(12), 12.0);
    });

    test('1.5 像素比：吸附后仍是整设备像素（误差不超过半个像素）', () {
      const dpr = 1.5;
      final s = PixelSnappingTextScaler(TextScaler.noScaling, 1 / dpr);
      for (final size in [13.0, 15.0, 17.0]) {
        final px = s.scale(size) * dpr;
        expect(px, closeTo(px.roundToDouble(), 1e-9), reason: '$size → $px px 不是整像素');
        expect((px - size * dpr).abs(), lessThanOrEqualTo(0.5 + 1e-9));
      }
    });

    test('字号为 0 时不炸', () {
      final s = PixelSnappingTextScaler(const TextScaler.linear(1.15), 0.5);
      expect(s.scale(0), 0.0);
    });

    test('相同参数的实例相等（MediaQuery 不会因它反复重建）', () {
      final a = PixelSnappingTextScaler(const TextScaler.linear(1.15), 0.5);
      final b = PixelSnappingTextScaler(const TextScaler.linear(1.15), 0.5);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });
}
