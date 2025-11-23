import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'morphing_gradient_button.dart';

/// Backwards-compatible wrapper that forwards to `MorphingGradientButton`.
/// Keeps the old `GradientButton` API but uses the new animated component under the hood.
class GradientButton extends StatelessWidget {
  final Widget child;
  final Widget? icon;
  final VoidCallback? onPressed;
  final BorderRadiusGeometry borderRadius;
  final List<Color>? colors;
  final EdgeInsetsGeometry padding;

  const GradientButton({super.key, required this.child, this.icon, required this.onPressed, this.borderRadius = const BorderRadius.all(Radius.circular(12)), this.colors, this.padding = const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0)});

  factory GradientButton.icon({Key? key, required Widget icon, required Widget label, required VoidCallback? onPressed, BorderRadiusGeometry borderRadius = const BorderRadius.all(Radius.circular(12)), List<Color>? colors, EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0)}) {
    return GradientButton(key: key, icon: icon, onPressed: onPressed, borderRadius: borderRadius, colors: colors, padding: padding, child: label);
  }

  @override
  Widget build(BuildContext context) {
    final resolvedColors = colors ?? [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary];
    final content = icon != null ? Row(mainAxisSize: MainAxisSize.min, children: [icon!, SizedBox(width: 8.w), child]) : child;

    return MorphingGradientButton(
      onPressed: onPressed,
      colors: resolvedColors,
      padding: padding,
      borderRadius: borderRadius is BorderRadius ? borderRadius as BorderRadius : BorderRadius.circular(12.r),
      child: content,
    );
  }
}
