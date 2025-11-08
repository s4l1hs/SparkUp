import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A lightweight glassmorphism card used across the app.
/// Provides a blurred backdrop, subtle gradient, border and padding.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final double blurSigma;
  final Color? tintColor;

  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(14.0), this.borderRadius = const BorderRadius.all(Radius.circular(12)), this.blurSigma = 12.0, this.tintColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
  final baseSurface = theme.colorScheme.surface;
  // Extract RGB components without using the deprecated .red/.green/.blue getters.
  // Use toARGB32() for a stable int representation (avoids deprecated .value).
  final int base = baseSurface.toARGB32();
  final int r = (base >> 16) & 0xFF;
  final int g = (base >> 8) & 0xFF;
  final int b = base & 0xFF;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding is EdgeInsets ? padding as EdgeInsets : EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.fromARGB((0.95 * 255).round(), r, g, b), Color.fromARGB((0.6 * 255).round(), r, g, b)],
            ),
            borderRadius: borderRadius,
            border: Border.all(color: Color.fromARGB((0.06 * 255).round(), 255, 255, 255)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12.r, offset: Offset(0, 6.h))],
          ),
          child: child,
        ),
      ),
    );
  }
}
