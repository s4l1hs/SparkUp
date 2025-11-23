import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../utils/color_utils.dart';
// lightweight animated background painter — intentionally minimal imports

class AppBackground extends StatefulWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    // Longer, eased loop so ambient motion feels organic and not mechanical
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 30));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _anim,
            builder: (context, child) {
              final a = _anim.value;
              return CustomPaint(
                painter: _BlobPainter(a, theme.colorScheme.primary, theme.colorScheme.secondary),
                child: Container(),
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _BlobPainter extends CustomPainter {
  final double t;
  final Color c1;
  final Color c2;
  _BlobPainter(this.t, this.c1, this.c2);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final w = size.width;
    final h = size.height;
    // use smooth sine-based offsets for organic motion
    final theta = t * 2 * 3.141592653589793;
    final s = math.sin(theta);
    final c = math.cos(theta);

    final cx1 = 0.2 + 0.08 * s; // horizontal wobble
    final cy1 = 0.15 + 0.03 * c; // vertical subtle shift
    final r1 = w * (0.45 + 0.04 * s.abs());
    paint.shader = RadialGradient(colors: [colorWithOpacity(c1, 0.12), Colors.transparent]).createShader(Rect.fromCircle(center: Offset(w * cx1, h * cy1), radius: r1));
    canvas.drawCircle(Offset(w * cx1, h * cy1), r1, paint);

    final cx2 = 0.8 - 0.08 * s;
    final cy2 = 0.85 - 0.03 * c;
    final r2 = w * (0.40 + 0.03 * c.abs());
    paint.shader = RadialGradient(colors: [colorWithOpacity(c2, 0.10), Colors.transparent]).createShader(Rect.fromCircle(center: Offset(w * cx2, h * cy2), radius: r2));
    canvas.drawCircle(Offset(w * cx2, h * cy2), r2, paint);
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) => oldDelegate.t != t || oldDelegate.c1 != c1 || oldDelegate.c2 != c2;
}
