
import 'package:flutter/material.dart';

class CustomIconButton extends StatelessWidget {

  final double? iconSize;
  final VisualDensity? visualDensity;
  final EdgeInsetsGeometry padding = const EdgeInsets.all(8.0);
  final AlignmentGeometry alignment = Alignment.center;
  final double? splashRadius;
  final Color? color;
  final Color? focusColor;
  final Color? hoverColor;
  final Color? highlightColor;
  final Color? splashColor;
  final Color? disabledColor;
  final MouseCursor? mouseCursor;
  final FocusNode? focusNode;
  final bool autofocus = false;
  final String? tooltip;
  final bool enableFeedback = true;
  final BoxConstraints? constraints;
  final Widget icon;
  final Function(BuildContext context)? onPressed;

  const CustomIconButton({Key? key, this.iconSize, this.visualDensity, this.splashRadius, this.color, this.focusColor, this.hoverColor, this.highlightColor, this.splashColor, this.disabledColor, this.mouseCursor, this.focusNode, this.tooltip, this.constraints, required this.icon, this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(icon: icon, onPressed: () {
      if (onPressed != null) onPressed!(context);
    });
  }

}
