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
              // 整屏平移：被选中的回到原位，其余的推到屏幕外一整屏
              // （左页推到左边、右页推到右边），两页同向滑动像翻页
              offset: i == _index ? Offset.zero : Offset(i < _index ? -1.0 : 1.0, 0),
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

/// 一页内容：整屏横向平移——切走时推向一侧，切回时从同侧滑回。
/// 不做淡入淡出，两页同时滑动，接缝处拼成"翻过去"的画面。
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
          curve: Motion.emphasized,
          // 不在前台的页面暂停自己的动画，省电
          child: TickerMode(enabled: active, child: child),
        ),
      ),
    );
  }
}
