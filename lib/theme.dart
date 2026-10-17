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

ThemeData buildTheme(Brightness brightness, Color seed) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    secondary: kAccent,
  );
  final isDark = brightness == Brightness.dark;
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? scheme.surface : const Color(0xFFF5F6FA),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
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
      backgroundColor: isDark ? scheme.surface : Colors.white,
      indicatorColor: scheme.primary.withValues(alpha: 0.14),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5), thickness: 1),
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
