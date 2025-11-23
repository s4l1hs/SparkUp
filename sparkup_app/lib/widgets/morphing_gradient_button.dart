import 'package:flutter/material.dart';

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
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return GestureDetector(
      onTapDown: (_) { setState(() => _pressed = true); },
      onTapUp: (_) { setState(() => _pressed = false); widget.onPressed?.call(); },
      onTapCancel: () { setState(() => _pressed = false); },
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          // morph gradient by shifting stops with animation value
          final t = _pulse.value;
          final shifted = [for (int i = 0; i < colors.length; i++) colors[(i + (t * colors.length).floor()) % colors.length]];
          return PhysicalModel(
            color: Colors.transparent,
            elevation: widget.elevation * (_pressed ? 1.5 : 1.0),
            borderRadius: widget.borderRadius as BorderRadius?,
            child: Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: shifted, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: widget.borderRadius,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.28), blurRadius: 10, offset: Offset(0, 6))],
              ),
              child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: Center(child: widget.child)),
            ),
          );
        },
      ),
    );
  }
}
