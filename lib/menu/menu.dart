import 'dart:async';

import 'package:eso/menu/menu_item.dart';
import 'package:flutter/cupertino.dart' hide MenuItem;
import 'package:flutter/material.dart' hide MenuItem;
import 'package:outline_material_icons/outline_material_icons.dart';

void voidValueFunction(_) {}

class Menu<T> extends StatelessWidget {
  final List<MenuItem<T>> items;
  final IconData icon;
  final Color color;
  final String tooltip;
  final FutureOr Function(T value) onSelect;
  final Widget child;
  final double iconSize;

  const Menu({
    Key key,
    this.icon = OMIcons.moreVert,
    this.iconSize = 20,
    this.color,
    this.tooltip = "更多",
    this.child,
    this.items,
    this.onSelect = voidValueFunction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: child ??
          IconButton(
            tooltip: tooltip,
            icon: Icon(icon, color: color),
            onPressed: null,
            padding: EdgeInsets.zero,
            iconSize: this.iconSize,
          ),
      onTapDown: (TapDownDetails details) {
        showMenu<T>(
          context: context,
          elevation: 500,
          // color: CupertinoColors.systemGrey6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
            side: BorderSide(
              color: Colors.grey.withOpacity(0.1),
            ),
          ),
          position: RelativeRect.fromLTRB(details.globalPosition.dx,
              details.globalPosition.dy, details.globalPosition.dx + 60, 0),
          items: [
            for (final item in items)
              PopupMenuItem<T>(
                value: item.value,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.text,
                      style: TextStyle(color: item.textColor),
                    ),
                    Icon(item.icon, color: item.color),
                  ],
                ),
              ),
          ],
        ).then(onSelect);
      },
    );
  }
}
