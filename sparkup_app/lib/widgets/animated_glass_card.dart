import 'dart:ui';

import 'package:flutter/material.dart';
import '../utils/color_utils.dart';

class AnimatedGlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Duration duration;
  final double elevation;

  const AnimatedGlassCard(
      {super.key,
      required this.child,
      this.padding,
      this.borderRadius,
      this.duration = const Duration(milliseconds: 420),
      this.elevation = 6});

  @override
  State<AnimatedGlassCard> createState() => _AnimatedGlassCardState();
}

class _AnimatedGlassCardState extends State<AnimatedGlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  late final Animation<double> _blurAnim;
  late final Animation<double> _elevationAnim;

  @override
  void initState() {
    super.initState();
    // Slightly longer and softer entrance for a more pleasant feel.
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    // Animate blur and elevation for a subtle material-like pop.
    _blurAnim = Tween<double>(begin: 6.0, end: 10.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _elevationAnim =
        Tween<double>(begin: widget.elevation * 0.6, end: widget.elevation)
            .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final animate = !media.accessibleNavigation;
    final radius = widget.borderRadius ?? BorderRadius.circular(14);
    if (!animate) {
      // Reduced-motion: render the final visual state without animations.
      return AnimatedPhysicalModel(
        duration: const Duration(milliseconds: 0),
        shape: BoxShape.rectangle,
        elevation: widget.elevation,
        color: Colors.transparent,
        borderRadius: radius,
        shadowColor: colorWithOpacity(Colors.black, 0.14),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 9.0, sigmaY: 9.0),
            child: Container(
              padding: widget.padding ?? const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorWithOpacity(Colors.white, 0.03),
                borderRadius: radius,
                border: Border.all(color: Colors.white10),
              ),
              child: widget.child,
            ),
          ),
        ),
      );
    }

    final effectiveContainerDuration = widget.duration;
    final effectivePhysicalDuration =
        Duration(milliseconds: (widget.duration.inMilliseconds * 6 ~/ 5));

    return FadeTransition(
      opacity: _anim,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.99, end: 1.0).animate(
            CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic)),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            return AnimatedPhysicalModel(
              duration: effectivePhysicalDuration,
              curve: Curves.easeOutCubic,
              shape: BoxShape.rectangle,
              elevation: _elevationAnim.value,
              color: Colors.transparent,
              borderRadius: radius,
              shadowColor: colorWithOpacity(Colors.black, 0.14),
              child: ClipRRect(
                borderRadius: radius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                      sigmaX: _blurAnim.value, sigmaY: _blurAnim.value),
                  child: AnimatedContainer(
                    duration: effectiveContainerDuration,
                    padding: widget.padding ?? const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorWithOpacity(Colors.white, 0.03),
                      borderRadius: radius,
                      border: Border.all(color: Colors.white10),
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
