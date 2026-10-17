import 'package:flutter/material.dart';

import '../app_state.dart';
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
    setState(() => _index = i);
    // 从「知新」清掉的错题，切到「反思」时要同步
    if (i == 1) _reflectKey.currentState?.refreshIfStale();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          StudyScreen(state: widget.state),
          ReflectScreen(key: _reflectKey, state: widget.state),
          QuantScreen(state: widget.state),
          MoreScreen(state: widget.state),
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
