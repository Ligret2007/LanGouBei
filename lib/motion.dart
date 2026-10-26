import 'package:flutter/animation.dart';

/// 全站动效节奏。
///
/// 时长和曲线都集中在这里：想整体调慢、调柔和，只改这一个文件，
/// 不用去各页面里翻 `Duration(milliseconds: ...)` 和 `Curves.xxx`。
///
/// 取值原则：
/// - 时长比 Material 默认值长 30% 左右（默认 200–300ms 太快，"翻过去"看不清）；
/// - 曲线一律用「起步快、收尾长」的四次贝塞尔，收尾段占一半以上的时间，落位才不突兀。
class Motion {
  Motion._();

  // ———————————————————— 时长 ————————————————————

  /// 卡片翻面：要慢到能看清翻过去的过程
  static const Duration flip = Duration(milliseconds: 520);

  /// 卡片区内换内容（换题、空状态、列表刷新）
  static const Duration content = Duration(milliseconds: 420);

  /// 整页切换（引导翻页）
  static const Duration page = Duration(milliseconds: 460);

  /// 小元素淡入 / 尺寸变化（指示点、提示条）
  static const Duration fade = Duration(milliseconds: 300);

  /// 启动页
  static const Duration splash = Duration(milliseconds: 1100);

  // ———————————————————— 曲线 ————————————————————

  /// 默认曲线：起步快、收尾长，落位柔和
  static const Curve standard = Cubic(0.16, 1.0, 0.30, 1.0);

  /// 强调曲线：收尾比 standard 还长，惯性更明显（翻面、大块内容切换）
  static const Curve emphasized = Cubic(0.22, 1.0, 0.36, 1.0);

  /// 翻面专用：中段最慢，翻到一半时像"停一下"
  static const Curve flipCurve = Cubic(0.45, 0.05, 0.25, 1.0);

  /// 进入（淡入 + 轻微上移）
  static const Curve enter = Cubic(0.18, 1.0, 0.32, 1.0);

  /// 离开（比进入快一点，避免退场拖沓）
  static const Curve exit = Cubic(0.38, 0.0, 0.22, 1.0);

  /// 轻微回弹（启动页图标落位）
  static const Curve overshoot = Cubic(0.34, 1.56, 0.64, 1.0);
}
