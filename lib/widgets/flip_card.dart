import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/word.dart';
import '../theme.dart';

/// 3D 翻转单词卡：正面只给单词，翻面看释义
class FlipWordCard extends StatefulWidget {
  final Word word;
  final bool revealed;
  final bool isReview;

  const FlipWordCard({
    super.key,
    required this.word,
    required this.revealed,
    this.isReview = false,
  });

  @override
  State<FlipWordCard> createState() => _FlipWordCardState();
}

class _FlipWordCardState extends State<FlipWordCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: widget.revealed ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant FlipWordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revealed != widget.revealed) {
      _controller.animateTo(widget.revealed ? 1 : 0, curve: Curves.easeInOutCubic);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final angle = _controller.value * math.pi;
        final showBack = _controller.value > 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle),
          child: showBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: _back(theme),
                )
              : _front(theme),
        );
      },
    );
  }

  Widget _front(ThemeData theme) {
    final w = widget.word;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: SizedBox(
        width: double.infinity,
        height: 330,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TagChip(w.levelLabel, color: levelColor(w.level, theme.brightness), strength: 0.18),
                if (widget.isReview) ...[
                  const SizedBox(width: 6),
                  TagChip('错题复习', color: kWarn),
                ],
              ],
            ),
            const SizedBox(height: 26),
            Text(
              w.word,
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(w.phonetic,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 34),
            Text('轻点卡片查看释义',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }

  Widget _back(ThemeData theme) {
    final w = widget.word;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      child: SizedBox(
        width: double.infinity,
        height: 330,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(w.word,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ),
                TagChip(w.levelLabel, color: levelColor(w.level, theme.brightness), strength: 0.18),
              ],
            ),
            const SizedBox(height: 2),
            Text(w.phonetic,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (w.pos.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(w.pos,
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        w.meaning,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600, height: 1.55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
