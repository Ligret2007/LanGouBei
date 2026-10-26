import 'package:flutter/animation.dart';

/// 全站动效节奏。
///
/// 时长和曲线都集中在这里：想整体调慢、调柔和，只改这一个文件，
/// 不用去各页面里翻 `Duration(milliseconds: ...)` 和 `Curves.xxx`。
///
/// 取值参考 iOS 的动效语言（26/27 这一代更明显）：
/// - 时长 0.6–0.7s，比 Material 默认（200–300ms）长一截，位移过程看得见；
/// - 曲线带一点缓入、收尾极长（默认那条就是 iOS 的 `(0.25, 0.1, 0.25, 1.0)`）：
///   起步不"弹"出去，最后 1/5 的时间只挪几个像素，落位是"化"进去的；
/// - 进出两段交叉重叠，不会先停住再开始。
class Motion {
  Motion._();

  // ———————————————————— 时长 ————————————————————

  /// 卡片翻面：慢到能看清翻过去的过程，中段最慢
  static const Duration flip = Duration(milliseconds: 640);

  /// 卡片区内换内容（换题、空状态、列表刷新）
  static const Duration content = Duration(milliseconds: 560);

  /// 整页切换（底部板块、引导翻页）
  static const Duration page = Duration(milliseconds: 700);

  /// 小元素淡入 / 尺寸变化（指示点、提示条）
  static const Duration fade = Duration(milliseconds: 420);

  /// 启动页
  static const Duration splash = Duration(milliseconds: 1300);

  // ———————————————————— 曲线 ————————————————————

  /// 默认曲线 = iOS 的 timing function：(0.25, 0.1, 0.25, 1.0)
  static const Curve standard = Cubic(0.25, 0.10, 0.25, 1.0);

  /// 强调曲线：起步再缓一点、收尾更长，大块位移（切页）用它
  static const Curve emphasized = Cubic(0.32, 0.02, 0.18, 1.0);

  /// 翻面专用：两头缓、中间快，翻到一半时像"停一下"
  static const Curve flipCurve = Cubic(0.45, 0.05, 0.20, 1.0);

  /// 进入（淡入 + 轻微位移）
  static const Curve enter = Cubic(0.22, 0.12, 0.26, 1.0);

  /// 离开：比进入快，避免退场拖沓
  static const Curve exit = Cubic(0.30, 0.00, 0.22, 1.0);

  /// 轻微回弹（启动页图标落位）：只冲过头 24%，克制
  static const Curve overshoot = Cubic(0.34, 1.24, 0.64, 1.0);
}
