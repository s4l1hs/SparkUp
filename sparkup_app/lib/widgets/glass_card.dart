import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/widgets.dart';

import 'animated_glass_card.dart';

/// Backwards-compatible wrapper for the newer `AnimatedGlassCard`.
/// Keeps the old API but forwards to the animated implementation so
/// existing imports don't need to change.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final double blurSigma;
  final Color? tintColor;

  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(14.0), this.borderRadius = const BorderRadius.all(Radius.circular(12)), this.blurSigma = 12.0, this.tintColor});

  @override
  Widget build(BuildContext context) {
    // Best-effort: if a BorderRadius was supplied use it, otherwise fallback to a reasonable default.
    final BorderRadius resolvedRadius = (borderRadius is BorderRadius) ? borderRadius as BorderRadius : BorderRadius.circular(12.r);

    return AnimatedGlassCard(
      padding: padding,
      borderRadius: resolvedRadius,
      child: child,
    );
  }
}
