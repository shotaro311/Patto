import 'package:flutter/material.dart';

import '../theme/patto_theme.dart';

class PattoSurface extends StatelessWidget {
  const PattoSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.radius = 24,
    this.color,
    this.gradient,
    this.borderColor,
    this.onTap,
    this.onSecondaryTapDown,
    this.alignment,
    this.muted = false,
    this.selected = false,
    this.floating = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final VoidCallback? onTap;
  final GestureTapDownCallback? onSecondaryTapDown;
  final AlignmentGeometry? alignment;
  final bool muted;
  final bool selected;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final content = padding == null
        ? child
        : Padding(padding: padding!, child: child);
    final decoration = pattoSurfaceDecoration(
      context,
      radius: radius,
      color: color,
      gradient: gradient,
      borderColor: borderColor,
      muted: muted,
      selected: selected,
      floating: floating,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: margin,
      alignment: alignment,
      decoration: decoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
          child: Material(
          color: Colors.transparent,
          child: onTap == null && onSecondaryTapDown == null
              ? content
              : InkWell(
                  onTap: onTap,
                  onSecondaryTapDown: onSecondaryTapDown,
                  borderRadius: BorderRadius.circular(radius),
                  child: content,
                ),
        ),
      ),
    );
  }
}
