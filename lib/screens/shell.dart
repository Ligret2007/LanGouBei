import 'package:flutter/material.dart';

import '../app_state.dart';
import '../motion.dart';
import 'more_screen.dart';
import 'quant_screen.dart';
import 'reflect_screen.dart';
import 'study_screen.dart';

class Shell extends StatefulWidget {
  final AppState state;

  const Shell({super.key, required this.state});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;
  final GlobalKey<ReflectScreenState> _reflectKey = GlobalKey<ReflectScreenState>();

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    // 从「知新」清掉的错题，切到「反思」时要同步
    if (i == 1) _reflectKey.currentState?.refreshIfStale();
  }

  Widget _page(int i) {
    return switch (i) {
      0 => StudyScreen(state: widget.state),
      1 => ReflectScreen(key: _reflectKey, state: widget.state),
      2 => QuantScreen(state: widget.state),
      _ => MoreScreen(state: widget.state),
    };
  }

  @override
  Widget build(BuildContext context) {
    // 当前页放最上层，其余页在下面待命：切页时新页从一侧滑入、旧页向反侧淡出。
    // 四页都一直装着（不清状态），只是非当前页不响应触摸、不进语义树。
    final order = <int>[for (var i = 0; i < 4; i++) if (i != _index) i, _index];

    return Scaffold(
      body: Stack(
        children: [
          for (final i in order)
            _TabLayer(
              // 必须带 key：切页时当前页会被提到最上层（顺序变了），
              // 没有 key 的话 Flutter 按位置复用元素，整页会被当成换了控件直接替换，
              // 过渡动画就不会跑。
              key: ValueKey(i),
              active: i == _index,
              // 目标位置：左边来的往左退、右边来的往右等，被选中的回到原位
              offset: i == _index ? Offset.zero : Offset(i < _index ? -0.09 : 0.09, 0),
              child: _page(i),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt),
            label: '知新',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_edu_outlined),
            selectedIcon: Icon(Icons.history_edu),
            label: '反思',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: '量化',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: '更多',
          ),
        ],
      ),
    );
  }
}

/// 一页内容：切走时淡出并向一侧退开，切回时淡入滑回原位。
class _TabLayer extends StatelessWidget {
  final bool active;
  final Offset offset;
  final Widget child;

  const _TabLayer({super.key, required this.active, required this.offset, required this.child});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !active,
      child: ExcludeSemantics(
        excluding: !active,
        child: AnimatedSlide(
          offset: offset,
          duration: Motion.page,
          // 大块位移用强调曲线：收尾更长，像被"吸"到位置上
          curve: Motion.emphasized,
          child: AnimatedOpacity(
            opacity: active ? 1 : 0,
            duration: Motion.page,
            curve: Motion.standard,
            // 不在前台的页面暂停自己的动画，省电
            child: TickerMode(enabled: active, child: child),
          ),
        ),
      ),
    );
  }
}
