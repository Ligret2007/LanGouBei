import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';

/// 打开软件时的加载页：显示高考倒计时
class SplashScreen extends StatefulWidget {
  final AppState state;

  const SplashScreen({super.key, required this.state});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = widget.state.daysToExam;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.14),
              theme.scaffoldBackgroundColor,
              theme.colorScheme.secondary.withValues(alpha: 0.10),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
            child: Column(
              children: [
                const Spacer(flex: 3),
                ScaleTransition(
                  scale: Tween<double>(begin: 0.85, end: 1).animate(
                    CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
                  ),
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 44),
                  ),
                ),
                const SizedBox(height: 20),
                Text('LangoBei',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text('把单词变成你的',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const Spacer(flex: 2),
                if (days != null) ...[
                  Text('距离高考仅有',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$days',
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.primary,
                            height: 1,
                          )),
                      const SizedBox(width: 8),
                      Text('天',
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(color: theme.colorScheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('${widget.state.settings.examYear} 年 6 月 7 日',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ] else
                  Text('今天也要背单词',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const Spacer(flex: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_rounded, size: 12, color: kAccent.withValues(alpha: 0.9)),
                    const SizedBox(width: 6),
                    Text('——高三生 Ligret',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
