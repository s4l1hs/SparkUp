import 'dart:ui';

import 'package:flutter/material.dart';

class AnimatedGlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Duration duration;
  final double elevation;

  const AnimatedGlassCard({super.key, required this.child, this.padding, this.borderRadius, this.duration = const Duration(milliseconds: 420), this.elevation = 6});

  @override
  State<AnimatedGlassCard> createState() => _AnimatedGlassCardState();
}

class _AnimatedGlassCardState extends State<AnimatedGlassCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(14);
    return FadeTransition(
      opacity: _anim,
      child: ScaleTransition(
        scale: _anim,
        child: PhysicalModel(
          color: Colors.transparent,
          elevation: widget.elevation,
          borderRadius: radius,
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
              child: AnimatedContainer(
                duration: widget.duration,
                padding: widget.padding ?? const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: radius,
                  border: Border.all(color: Colors.white10),
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
