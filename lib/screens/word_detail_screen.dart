import 'package:flutter/material.dart';

import '../app_state.dart';
import '../dict/dict_entry.dart';
import '../theme.dart';

/// 词典词条详情：释义、音标、标签、词形变化，底部是「加入错题本」。
class WordDetailScreen extends StatelessWidget {
  final AppState state;
  final DictEntry entry;

  /// 用户搜的是变形词时不为空，比如搜 gave 命中 give
  final String? viaForm;

  const WordDetailScreen({
    super.key,
    required this.state,
    required this.entry,
    this.viaForm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final word = entry.toWord();
    final color = levelColor(entry.level, theme.brightness);
    final senses = entry.translation
        .split('；')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: '返回',
                  ),
                  Expanded(
                    child: Text('查词',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  TagChip('来自 ECDICT'),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: Text(entry.word,
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                            ),
                            if (entry.phonetic.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              Text(formatPhonetic(entry.phonetic),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ],
                        ),
                        if (viaForm != null) ...[
                          const SizedBox(height: 6),
                          Text('“$viaForm” 是 ${entry.word} 的变化形式',
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(color: kWarn)),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (entry.pos.isNotEmpty) TagChip(entry.pos),
                            for (final t in entry.tagLabels) TagChip(t, color: color),
                            if (entry.oxford) const TagChip('牛津 3000'),
                            if (entry.collins > 0) TagChip('柯林斯 ${entry.collins}★'),
                            if (entry.rank < (1 << 30)) TagChip('词频 ${entry.rank}'),
                          ],
                        ),
                        const SizedBox(height: 14),
                        for (final s in senses)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 7, right: 8),
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Text(s,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(height: 1.5)),
                                ),
                              ],
                            ),
                          ),
                        if (entry.forms.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final f in entry.forms)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('${f.label} ${f.form}',
                                      style: theme.textTheme.labelMedium),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ListenableBuilder(
                    listenable: state,
                    builder: (context, _) {
                      final inBook = state.isInWrongBook(word.id);
                      return SizedBox(
                        height: 50,
                        child: inBook
                            ? OutlinedButton.icon(
                                onPressed: () => state.removeFromWrongBook(word.id),
                                icon: const Icon(Icons.bookmark_remove_outlined, size: 18),
                                label: const Text('已在错题本，点一下移出'),
                              )
                            : FilledButton.icon(
                                onPressed: () => state.addToWrongBook(word),
                                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                                label: const Text('加入错题本'),
                              ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Text('释义与音标来自 ECDICT（MIT）',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
