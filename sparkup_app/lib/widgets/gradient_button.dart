import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class GradientButton extends StatefulWidget {
  final Widget child;
  final Widget? icon;
  final VoidCallback? onPressed;
  final BorderRadiusGeometry borderRadius;
  final List<Color>? colors;
  final EdgeInsetsGeometry padding;

  const GradientButton({super.key, required this.child, this.icon, required this.onPressed, this.borderRadius = const BorderRadius.all(Radius.circular(12)), this.colors, this.padding = const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0)});

  // convenience factory for icon + label
  factory GradientButton.icon({Key? key, required Widget icon, required Widget label, required VoidCallback? onPressed, BorderRadiusGeometry borderRadius = const BorderRadius.all(Radius.circular(12)), List<Color>? colors, EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0)}) {
    return GradientButton(key: key, icon: icon, onPressed: onPressed, borderRadius: borderRadius, colors: colors, padding: padding, child: label);
  }

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails _) => setState(() => _scale = 0.97);
  void _onTapUp(TapUpDetails _) => setState(() => _scale = 1.0);
  void _onTapCancel() => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ?? [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary];

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onPressed,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _scale,
        child: Container(
          padding: widget.padding is EdgeInsets ? widget.padding as EdgeInsets : EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: widget.borderRadius,
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12.r, offset: Offset(0, 6.h))],
          ),
          child: DefaultTextStyle(style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [if (widget.icon != null) ...[widget.icon!, SizedBox(width: 8.w)], widget.child])),
        ),
      ),
    );
  }
}
