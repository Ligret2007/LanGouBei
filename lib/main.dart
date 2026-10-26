import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'crisp.dart';
import 'models/word.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 只做竖屏：转屏会让背单词的视线流被打断，也不存在横屏布局
  await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  final state = AppState();
  await state.load();
  runApp(LangoBeiApp(state: state));
}

class LangoBeiApp extends StatelessWidget {
  final AppState state;

  const LangoBeiApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final s = state.settings;
        final seed = seedForPreset(presetById(s.themePreset));
        return MaterialApp(
          title: 'LangoBei',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light, seed),
          darkTheme: buildTheme(Brightness.dark, seed),
          themeMode: switch (s.themeMode) {
            ThemeModeSetting.system => ThemeMode.system,
            ThemeModeSetting.light => ThemeMode.light,
            ThemeModeSetting.dark => ThemeMode.dark,
          },
          home: RootGate(state: state),
          builder: (context, child) {
            final content = child ?? const SizedBox.shrink();
            // 字号吸附到整设备像素；内容区收在竖屏宽度内（平板横放也不会变成横屏布局）
            return CrispPixels(
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
                    child: content,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// 决定先给引导页、倒计时加载页，还是主界面
class RootGate extends StatefulWidget {
  final AppState state;

  const RootGate({super.key, required this.state});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> with WidgetsBindingObserver {
  bool _splashDone = false;
  bool _wasOnboarded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wasOnboarded = widget.state.settings.onboarded;
    if (_wasOnboarded) _startSplashTimer();
  }

  void _startSplashTimer() {
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _splashDone = true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.detached) {
      widget.state.flush();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    if (!state.settings.onboarded) return OnboardingScreen(state: state);

    if (!_wasOnboarded) {
      _wasOnboarded = true;
      _startSplashTimer();
    }

    if (!_splashDone) return SplashScreen(state: state);
    return Shell(state: state);
  }
}
