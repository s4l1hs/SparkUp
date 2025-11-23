import 'package:flutter/material.dart';
// lightweight animated background painter — intentionally minimal imports

class AppBackground extends StatefulWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 25))..repeat();
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
            animation: _ctrl,
            builder: (context, child) {
              final a = _ctrl.value;
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

    // big soft blob
    paint.shader = RadialGradient(colors: [c1.withOpacity(0.12), Colors.transparent]).createShader(Rect.fromCircle(center: Offset(w * (0.2 + 0.1 * (t - 0.5)), h * 0.15), radius: w * 0.5));
    canvas.drawCircle(Offset(w * (0.2 + 0.1 * (t - 0.5)), h * 0.15), w * 0.5, paint);

    // secondary blob
    paint.shader = RadialGradient(colors: [c2.withOpacity(0.10), Colors.transparent]).createShader(Rect.fromCircle(center: Offset(w * (0.8 - 0.1 * (t - 0.5)), h * 0.85), radius: w * 0.45));
    canvas.drawCircle(Offset(w * (0.8 - 0.1 * (t - 0.5)), h * 0.85), w * 0.45, paint);
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) => oldDelegate.t != t || oldDelegate.c1 != c1 || oldDelegate.c2 != c2;
}
