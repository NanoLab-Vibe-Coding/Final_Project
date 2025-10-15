// lib/ui/widgets/card_grid.dart
// 카드 그리드: GlobalKey로 Rect 수집 후 콜백 제공. 대비/아이콘/텍스트 병행.

import 'package:flutter/material.dart';

import '../../core/a11y.dart';
import '../../domain/models/board_model.dart';
import '../../domain/models/card_model.dart';

typedef RectsCallback = void Function(Map<String, Rect> rects);

class CardGrid extends StatefulWidget {
  final BoardPage page;
  final double fontScale;
  final bool highContrast;
  final RectsCallback onRectsReady;
  final void Function(CardItem) onCardTap;
  const CardGrid({super.key, required this.page, required this.fontScale, required this.highContrast, required this.onRectsReady, required this.onCardTap});

  @override
  State<CardGrid> createState() => _CardGridState();
}

class _CardGridState extends State<CardGrid> {
  final Map<String, GlobalKey> _keys = {};

  @override
  void initState() {
    super.initState();
    for (final c in widget.page.cards) {
      _keys[c.id] = GlobalKey(debugLabel: 'card_${c.id}');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _collectRects());
  }

  @override
  void didUpdateWidget(covariant CardGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _collectRects());
  }

  void _collectRects() {
    final Map<String, Rect> rects = {};
    _keys.forEach((id, key) {
      final ctx = key.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final pos = box.localToGlobal(Offset.zero);
          rects[id] = pos & box.size;
        }
      }
    });
    if (rects.isNotEmpty) widget.onRectsReady(rects);
  }

  @override
  Widget build(BuildContext context) {
    final parts = widget.page.grid.split('x');
    final cols = int.tryParse(parts.first) ?? 3;
    final rows = int.tryParse(parts.last) ?? 2;
    final theme = Theme.of(context);
    final bg = widget.highContrast ? Colors.black : theme.colorScheme.surface;
    final fg = widget.highContrast ? Colors.yellow : theme.colorScheme.onSurface;

    return LayoutBuilder(builder: (context, constraints) {
      // 올바른 childAspectRatio = (cellWidth/cellHeight) = (W/cols)/(H/rows)
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      final aspect = (width / cols) / (height / rows);
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: aspect,
        ),
        itemCount: widget.page.cards.length,
        itemBuilder: (context, i) {
          final c = widget.page.cards[i];
          final isSos = c.sos;
          final gradient = isSos
              ? [Colors.redAccent, Colors.deepOrange]
              : [theme.colorScheme.primaryContainer, theme.colorScheme.secondaryContainer];
          final textColor = isSos ? Colors.white : theme.colorScheme.onPrimaryContainer;
          return Semantics(
            button: true,
            label: c.label,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: kMinTouchTarget, minHeight: kMinTouchTarget),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => widget.onCardTap(c),
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    key: _keys[c.id],
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradient),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isSos ? Icons.warning_amber_rounded : Icons.record_voice_over, size: 28, color: textColor),
                          const SizedBox(height: 6),
                          Flexible(
                            child: Text(
                              c.label,
                              textAlign: TextAlign.center,
                              softWrap: true,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 18 * widget.fontScale,
                                color: textColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }
}
