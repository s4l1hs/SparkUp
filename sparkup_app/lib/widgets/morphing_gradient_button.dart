import 'package:flutter/material.dart';
import '../utils/color_utils.dart';

class MorphingGradientButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final List<Color> colors;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final double elevation;

  const MorphingGradientButton({super.key, required this.child, required this.colors, this.onPressed, this.padding = const EdgeInsets.symmetric(vertical: 14.0, horizontal: 18.0), this.borderRadius = const BorderRadius.all(Radius.circular(12)), this.elevation = 6});

  factory MorphingGradientButton.icon({required Widget icon, required Widget label, required List<Color> colors, VoidCallback? onPressed, EdgeInsetsGeometry padding = const EdgeInsets.symmetric(vertical: 14.0, horizontal: 18.0), BorderRadiusGeometry borderRadius = const BorderRadius.all(Radius.circular(12)), double elevation = 6}) {
    return MorphingGradientButton(
      colors: colors,
      onPressed: onPressed,
      padding: padding,
      borderRadius: borderRadius,
      elevation: elevation,
      child: Row(mainAxisSize: MainAxisSize.min, children: [icon, const SizedBox(width: 8), label]),
    );
  }

  @override
  State<MorphingGradientButton> createState() => _MorphingGradientButtonState();
}

class _MorphingGradientButtonState extends State<MorphingGradientButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    // Longer, smoother loop and an easeInOut curve for pleasant motion
    // Start repeating only when we know the user's reduced-motion preference.
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final media = MediaQuery.of(context);
      final animate = !media.accessibleNavigation;
      if (animate) {
        _ctrl.repeat(reverse: true);
      } else {
        _ctrl.value = 0.0;
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final media = MediaQuery.of(context);
    final animate = !media.accessibleNavigation;
    return GestureDetector(
      onTapDown: (_) { setState(() => _pressed = true); },
      onTapUp: (_) { setState(() => _pressed = false); widget.onPressed?.call(); },
      onTapCancel: () { setState(() => _pressed = false); },
      child: AnimatedScale(
        scale: _pressed ? 0.987 : 1.0,
        duration: animate ? const Duration(milliseconds: 160) : Duration.zero,
        curve: Curves.easeOutCubic,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            // Smooth morph: compute a fractional shift and lerp between adjacent colors
            final t = (animate ? _pulse.value : 0.0) * colors.length;
            final base = t.floor();
            final frac = t - base;
            final shifted = List<Color>.generate(colors.length, (i) {
              final a = colors[(i + base) % colors.length];
              final b = colors[(i + base + 1) % colors.length];
              return Color.lerp(a, b, frac) ?? a;
            });

            // compute a gentle, softer glow that follows the pulse; respects reduced-motion
            // bias the pulse a bit for a gentler minimum and more visible peak
            final glowStrength = animate ? (0.18 + 0.82 * Curves.easeInOut.transform(_pulse.value)) : 0.0;
            final glowColor = colorWithOpacity(shifted.last, 0.26 * glowStrength);
            // larger, softer blur and slightly more spread for an aesthetic halo
            final blur = 18.0 + 28.0 * glowStrength;
            final spread = 1.0 + 6.0 * glowStrength;

            return AnimatedPhysicalModel(
              duration: animate ? const Duration(milliseconds: 480) : Duration.zero,
              curve: Curves.easeOutCubic,
              shape: BoxShape.rectangle,
              elevation: widget.elevation * (_pressed ? 1.4 : 1.0),
              color: Colors.transparent,
              borderRadius: widget.borderRadius as BorderRadius? ?? BorderRadius.circular(12),
              shadowColor: colorWithOpacity(Colors.black, 0.20),
              child: Container(
                padding: widget.padding,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: shifted, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: widget.borderRadius,
                  boxShadow: [
                    BoxShadow(color: colorWithOpacity(Colors.black, 0.08), blurRadius: 10, offset: const Offset(0, 6)),
                    BoxShadow(color: glowColor, blurRadius: blur, spreadRadius: spread, offset: const Offset(0, 8)),
                  ],
                ),
                child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: Center(child: widget.child)),
              ),
            );
          },
        ),
      ),
    );
  }
}
