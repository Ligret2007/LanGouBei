import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/word.dart';

const Color kAccent = Color(0xFFFF8A3D);
const Color kGood = Color(0xFF30A46C);
const Color kWarn = Color(0xFFF5A524);
const Color kBad = Color(0xFFE5484D);

/// 词库分级配色：easy 绿 / normal 黄 / hard 橙 / extra 红
const Color kLevelEasy = Color(0xFF2FA36B);
const Color kLevelNormal = Color(0xFFD9A400);
const Color kLevelHard = Color(0xFFF07C1E);
const Color kLevelExtra = Color(0xFFE5484D);

// 深色下用更亮的一档，避免压在暗底上看不清
const Color kLevelEasyDark = Color(0xFF4CC38A);
const Color kLevelNormalDark = Color(0xFFE9C24B);
const Color kLevelHardDark = Color(0xFFFF9E4D);
const Color kLevelExtraDark = Color(0xFFFF6B70);

Color levelColor(String level, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return switch (level) {
    'easy' => dark ? kLevelEasyDark : kLevelEasy,
    'normal' => dark ? kLevelNormalDark : kLevelNormal,
    'hard' => dark ? kLevelHardDark : kLevelHard,
    'extra' => dark ? kLevelExtraDark : kLevelExtra,
    _ => dark ? kLevelNormalDark : kLevelNormal,
  };
}

/// 由 HSL 得到种子色；预设色值都用 HSL 描述，以后要加自定义取色可以直接复用
Color seedColorFrom(double hue, double saturation, double lightness) {
  return HSLColor.fromAHSL(
    1,
    hue.clamp(0.0, 360.0),
    saturation.clamp(0.0, 1.0),
    lightness.clamp(0.15, 0.85),
  ).toColor();
}

Color seedForPreset(ThemePreset preset) =>
    seedColorFrom(preset.hue, preset.saturation, preset.lightness);

Color get defaultSeedColor => seedForPreset(kThemePresets.first);

/// 中性表面色：跟主题色无关，白色部分永远保持白
const Color kLightScaffold = Color(0xFFF3F4F6);
const Color kLightSurface = Colors.white;
const Color kLightOnSurface = Color(0xFF1B1C1F);
const Color kLightOnSurfaceVariant = Color(0xFF6C6E75);
const Color kLightSurfaceLow = Color(0xFFFAFAFB);
const Color kLightSurfaceHigh = Color(0xFFF0F1F3);
const Color kLightOutline = Color(0xFFD6D8DE);

const Color kDarkScaffold = Color(0xFF0F1013);
const Color kDarkSurface = Color(0xFF191A1D);
const Color kDarkOnSurface = Color(0xFFE9EAEC);
const Color kDarkOnSurfaceVariant = Color(0xFFA7A9AF);
const Color kDarkSurfaceLow = Color(0xFF141518);
const Color kDarkSurfaceHigh = Color(0xFF232428);
const Color kDarkOutline = Color(0xFF3A3C42);

/// 中性灰种子：只用来生成"不带色"的表面与文字色
const Color kNeutralSeed = Color(0xFF7C7D82);

/// 表面色一律走中性色，只有 primary / secondary 这些"醒目位"用主题色
ThemeData buildTheme(Brightness brightness, Color seed) {
  final isDark = brightness == Brightness.dark;

  // 拿主题色生成强调色，拿中性灰生成底色
  final accent = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    secondary: kAccent,
  );
  final neutral = ColorScheme.fromSeed(
    seedColor: kNeutralSeed,
    brightness: brightness,
  );

  final surface = isDark ? kDarkSurface : kLightSurface;

  final scheme = neutral.copyWith(
    // —— 醒目位：跟着主题色走 ——
    primary: accent.primary,
    onPrimary: accent.onPrimary,
    primaryContainer: accent.primaryContainer,
    onPrimaryContainer: accent.onPrimaryContainer,
    inversePrimary: accent.inversePrimary,
    tertiary: accent.tertiary,
    onTertiary: accent.onTertiary,
    secondary: kAccent,
    onSecondary: Colors.white,
    // —— 表面与文字：固定中性，白色永远是白 ——
    surface: surface,
    onSurface: isDark ? kDarkOnSurface : kLightOnSurface,
    onSurfaceVariant: isDark ? kDarkOnSurfaceVariant : kLightOnSurfaceVariant,
    surfaceContainerLowest: isDark ? const Color(0xFF0C0D0F) : Colors.white,
    surfaceContainerLow: isDark ? kDarkSurfaceLow : kLightSurfaceLow,
    surfaceContainer: isDark ? kDarkSurface : kLightSurface,
    surfaceContainerHigh: isDark ? kDarkSurfaceHigh : kLightSurfaceHigh,
    surfaceContainerHighest: isDark ? const Color(0xFF2A2B30) : const Color(0xFFE9EAEE),
    surfaceDim: isDark ? kDarkScaffold : const Color(0xFFE6E7EB),
    surfaceBright: isDark ? const Color(0xFF33353A) : Colors.white,
    outline: isDark ? kDarkOutline : kLightOutline,
    outlineVariant: isDark ? const Color(0xFF2C2E33) : const Color(0xFFE4E6EA),
    scrim: Colors.black,
    shadow: Colors.black,
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? kDarkScaffold : kLightScaffold,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: scheme.primary,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.14),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        );
      }),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      thumbColor: scheme.primary,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedForegroundColor: scheme.onPrimaryContainer,
        selectedBackgroundColor: scheme.primaryContainer,
      ),
    ),
  );
}

/// 统一圆角卡片
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(22), child: card);
  }
}

/// 小标签
class TagChip extends StatelessWidget {
  final String text;
  final Color? color;

  /// 底色浓度；分级标签用得更实一点，让颜色一眼能认出来
  final double strength;

  const TagChip(this.text, {super.key, this.color, this.strength = 0.10});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: strength),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(text,
          style: theme.textTheme.labelSmall?.copyWith(color: c, fontWeight: FontWeight.w600)),
    );
  }
}
