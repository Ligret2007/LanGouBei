import 'package:flutter/widgets.dart';

/// 把字号与布局吸附到「整设备像素」。
///
/// 起因：2K 平板上部分字发虚。屏幕像素比 × 系统字号缩放之后，字号常常变成
/// 27.6px、36.8px 这种小数，字形按小数尺寸栅格化，边缘就糊；同一行字里
/// 有的字号正好落在整像素上（清晰），有的没有（发虚），所以看起来是「部分字体」。
///
/// 这里做两件事：
/// 1. 逻辑尺寸吸附到整设备像素（误差不到 1px，肉眼无感，且只向上取整不裁切）；
/// 2. 每次字号缩放的结果吸附到 1/像素比 的整数倍 —— 于是 `字号 × 像素比` 必为整数，
///    字形按整像素尺寸渲染。
///
/// 系统字号缩放本身保留（无障碍设置照常生效），只是把结果对齐到像素网格。
class CrispPixels extends StatelessWidget {
  final Widget child;

  const CrispPixels({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final dpr = mq.devicePixelRatio;
    if (dpr <= 0) return child;

    // 只向上取整：宽度多出不到 1px，不会把右边裁掉
    final size = Size(
      (mq.size.width * dpr).ceilToDouble() / dpr,
      (mq.size.height * dpr).ceilToDouble() / dpr,
    );

    return MediaQuery(
      data: mq.copyWith(
        size: size,
        textScaler: PixelSnappingTextScaler(mq.textScaler, 1 / dpr),
      ),
      child: child,
    );
  }
}

/// 把缩放后的字号吸附到 [step]（= 1/像素比）的整数倍。
class PixelSnappingTextScaler extends TextScaler {
  final TextScaler _inner;

  /// 一个设备像素对应的逻辑尺寸，即 1 / devicePixelRatio
  final double _step;

  const PixelSnappingTextScaler(this._inner, this._step);

  @override
  double scale(double fontSize) {
    final scaled = _inner.scale(fontSize);
    if (scaled <= 0) return scaled;
    return (scaled / _step).roundToDouble() * _step;
  }

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => _inner.textScaleFactor;

  @override
  bool operator ==(Object other) =>
      other is PixelSnappingTextScaler && other._inner == _inner && other._step == _step;

  @override
  int get hashCode => Object.hash(_inner, _step);
}
