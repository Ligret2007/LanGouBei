import 'package:flutter/material.dart';

import '../motion.dart';

/// 卡片区换内容（认识/不认识、上一张下一张、错题复习）时的过渡。
///
/// 新卡从侧面推入、淡入，并轻微"长"到原尺寸；旧卡向同侧退出并淡出。
/// 两张卡在过渡期间重叠，所以观感是"换了一张"而不是"页面跳了一下"。
///
/// 用 AnimatedSwitcher 而不是 PageView：卡片是同一位置换内容，
/// 换页语义应该是"内容替换"，不该有横向滚动的位置记忆。
///
/// 过渡期间整张卡包在 RepaintBoundary 里：位移和透明度只走合成器，
/// 不会因为动画每帧重画卡片内容（120Hz 下这一点很明显）。
class CardSwitch extends StatelessWidget {
  final Widget child;

  const CardSwitch({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.content,
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, anim) {
        // 只在淡入淡出期间缩放，所以 3% 的缩放看不出模糊，只留下"厚度感"
        final scale = Tween<double>(begin: 0.97, end: 1.0).animate(anim);
        final slide = Tween<Offset>(
          begin: const Offset(0.26, 0),
          end: Offset.zero,
        ).animate(anim);
        return RepaintBoundary(
          child: FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: slide,
              child: ScaleTransition(scale: scale, child: child),
            ),
          ),
        );
      },
      child: child,
    );
  }
}
