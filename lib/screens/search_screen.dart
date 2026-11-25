import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../dict/dict_service.dart';
import '../theme.dart';
import 'word_detail_screen.dart';

/// 查词：输入就开始联，点一条看详情。
class SearchScreen extends StatefulWidget {
  final AppState state;
  final String? initialQuery;

  const SearchScreen({super.key, required this.state, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialQuery ?? '');
  final DictService _dict = DictService(loader: _loadAsset);
  Timer? _debounce;
  List<DictHit> _hits = const [];
  bool _searching = false;
  String _query = '';

  static Future<String?> _loadAsset(String asset) async {
    try {
      return await rootBundle.loadString(asset);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _dict.loadManifest();
    if ((widget.initialQuery ?? '').isNotEmpty) _run(widget.initialQuery!);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 160), () => _run(text));
  }

  Future<void> _run(String text) async {
    final q = text.trim();
    setState(() {
      _query = q;
      _searching = q.isNotEmpty;
    });
    if (q.isEmpty) {
      setState(() {
        _hits = const [];
        _searching = false;
      });
      return;
    }
    final hits = await _dict.suggest(q);
    if (!mounted || _query != q) return;
    setState(() {
      _hits = hits;
      _searching = false;
    });
  }

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
                    child: Text('查词',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  TagChip('${_dict.total} 词'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: SurfaceCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded,
                        size: 20, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        onChanged: _onChanged,
                        onSubmitted: _run,
                        textInputAction: TextInputAction.search,
                        style: theme.textTheme.bodyLarge,
                        decoration: const InputDecoration(
                          hintText: '输入单词，前面几个字母也行',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        onPressed: () {
                          _controller.clear();
                          _run('');
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                        visualDensity: VisualDensity.compact,
                        tooltip: '清空',
                      ),
                  ],
                ),
              ),
            ),
            Expanded(child: _body(theme)),
          ],
        ),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    if (_query.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_rounded,
                  size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
              const SizedBox(height: 14),
              Text('查一下不认识的词',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('支持前缀联想、变形词反查（gave → give），查到的词可以直接加入错题本',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    if (_searching && _hits.isEmpty) {
      return const Center(child: SizedBox.shrink());
    }

    if (_hits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded,
                  size: 44, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('没查到 “$_query”',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('试试少输几个字母',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: _hits.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final hit = _hits[i];
        return _HitTile(
          hit: hit,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WordDetailScreen(
                state: widget.state,
                entry: hit.entry,
                viaForm: hit.viaForm,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HitTile extends StatelessWidget {
  final DictHit hit;
  final VoidCallback onTap;

  const _HitTile({required this.hit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = hit.entry;
    final color = levelColor(e.level, theme.brightness);
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(e.word,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  if (e.phonetic.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(formatPhonetic(e.phonetic),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                  const Spacer(),
                  if (hit.viaForm != null)
                    TagChip('${hit.viaForm} 的原形', color: kWarn),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                e.translation,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
              ),
              if (e.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final t in e.tagLabels.take(3)) TagChip(t, color: color)],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
