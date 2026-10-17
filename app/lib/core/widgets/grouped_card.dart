import 'package:flutter/material.dart';
import 'package:vaultvoice/core/widgets/lumen_card.dart';

/// One rounded [LumenCard] holding several rows separated by hairline
/// dividers (UIX-01): the grouped-list pattern for lists and pickers.
class GroupedCard extends StatelessWidget {
  const GroupedCard({required this.children, this.margin, super.key});

  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Divider(height: 1, indent: 16, endIndent: 16));
      rows.add(children[i]);
    }
    final column = Column(mainAxisSize: MainAxisSize.min, children: rows);
    return margin == null
        ? LumenCard(child: column)
        : LumenCard(margin: margin!, child: column);
  }
}
