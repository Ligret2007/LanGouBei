import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/word.dart';
import '../theme.dart';

/// 错题本：把攒下来的词列出来，随时能翻、能移出。
/// 复习还是走「反思」那一页，这里只负责看和删。
class WrongBookScreen extends StatelessWidget {
  final AppState state;

  const WrongBookScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    child: Text('错题本',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  ListenableBuilder(
                    listenable: state,
                    builder: (context, _) => TagChip('${state.wrongCount} 词', color: kWarn),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: state,
                builder: (context, _) {
                  final words = state.wrongBookWords;
                  if (words.isEmpty) return _empty(theme);
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                    itemCount: words.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _WrongTile(
                      word: words[i],
                      onTap: () => _open(context, words[i]),
                      onRemove: () => state.removeFromWrongBook(words[i].id),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, Word word) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _WrongWordSheet(state: state, word: word),
      ),
    );
  }

  Widget _empty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_outlined,
                size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 14),
            Text('错题本是空的',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('「知新」里选「不认识」，或者在查词页点「加入错题本」，词就会攒到这里',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _WrongTile extends StatelessWidget {
  final Word word;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _WrongTile({required this.word, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(word.word,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        if (word.phonetic.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(formatPhonetic(word.phonetic),
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      word.meaning,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant, height: 1.4),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.bookmark_remove_outlined, size: 20),
                tooltip: '移出错题本',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 错题本里点开一个词：整页显示释义（不依赖词典，错题本里的词可能不在当前词库）
class _WrongWordSheet extends StatelessWidget {
  final AppState state;
  final Word word;

  const _WrongWordSheet({required this.state, required this.word});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = levelColor(word.level, theme.brightness);
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
                    child: Text('错题本',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  TagChip(word.levelLabel, color: color),
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
                              child: Text(word.word,
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                            ),
                            if (word.phonetic.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              Text(formatPhonetic(word.phonetic),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ],
                        ),
                        if (word.pos.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TagChip(word.pos),
                        ],
                        const SizedBox(height: 12),
                        Text(word.meaning,
                            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () {
                      state.removeFromWrongBook(word.id);
                      Navigator.of(context).maybePop();
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('这个记住了，移出错题本'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
