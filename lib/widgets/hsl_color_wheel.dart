import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// HSL 色轮：角度取色相（0-360），半径取饱和度（0-1），明度在外部单独调
class HslColorWheel extends StatelessWidget {
  final double hue;
  final double saturation;
  final double lightness;
  final double size;
  final void Function(double hue, double saturation) onChanged;

  const HslColorWheel({
    super.key,
    required this.hue,
    required this.saturation,
    required this.lightness,
    required this.onChanged,
    this.size = 220,
  });

  /// 把本地坐标换算成 色相 / 饱和度
  void _emit(Offset local, Size box) {
    final center = Offset(box.width / 2, box.height / 2);
    final radius = box.width / 2 - 14;
    final d = local - center;
    final sat = (d.distance / radius).clamp(0.0, 1.0);
    var deg = math.atan2(d.dy, d.dx) * 180 / math.pi; // 0° 在右侧，顺时针为正
    deg = (deg + 360) % 360;
    onChanged(deg, sat);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final box = Size(size, size);

    return Semantics(
      label: 'HSL 色轮',
      value: '色相 ${hue.round()} 度，饱和度 ${(saturation * 100).round()}%',
      child: SizedBox(
        width: size,
        height: size,
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          // 色轮嵌在可滚动页面里，必须自己不放手势，否则竖直拖动会被列表抢走
          gestures: <Type, GestureRecognizerFactory>{
            _EagerPanRecognizer: GestureRecognizerFactoryWithHandlers<_EagerPanRecognizer>(
              _EagerPanRecognizer.new,
              (instance) {
                instance.onStart = (d) => _emit(d.localPosition, box);
                instance.onUpdate = (d) => _emit(d.localPosition, box);
              },
            ),
          },
          child: Listener(
            // 轻点立刻取色，不用等手势判定
            onPointerDown: (e) => _emit(e.localPosition, box),
            child: CustomPaint(
              painter: _WheelPainter(
                hue: hue,
                saturation: saturation,
                lightness: lightness,
                trackColor: theme.colorScheme.outlineVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 输了也不认输的拖动识别器：保证色轮在滚动容器里依然能拖动
class _EagerPanRecognizer extends PanGestureRecognizer {
  @override
  void rejectGesture(int pointer) => acceptGesture(pointer);
}

class _WheelPainter extends CustomPainter {
  final double hue;
  final double saturation;
  final double lightness;
  final Color trackColor;

  _WheelPainter({
    required this.hue,
    required this.saturation,
    required this.lightness,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 14;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 外圈轨道
    canvas.drawCircle(
      center,
      radius + 7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = trackColor.withValues(alpha: 0.7),
    );

    // 色相环
    final hueColors = <Color>[
      for (var h = 0; h <= 360; h += 20)
        HSLColor.fromAHSL(1, (h % 360).toDouble(), 1, 0.5).toColor(),
    ];

    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    canvas.drawCircle(
      center,
      radius,
      Paint()..shader = SweepGradient(colors: hueColors).createShader(rect),
    );
    // 饱和度：中心灰 → 边缘纯色
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF808080), Color(0x00808080)],
        ).createShader(rect),
    );
    canvas.restore();

    // 当前选择点
    final rad = hue * math.pi / 180;
    final pos = center + Offset(math.cos(rad), math.sin(rad)) * (saturation * radius);
    canvas.drawCircle(pos, 11, Paint()..color = Colors.white.withValues(alpha: 0.9));
    canvas.drawCircle(
      pos,
      9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
    canvas.drawCircle(
      pos,
      6,
      Paint()..color = HSLColor.fromAHSL(1, hue, saturation, lightness).toColor(),
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) =>
      old.hue != hue ||
      old.saturation != saturation ||
      old.lightness != lightness ||
      old.trackColor != trackColor;
}
