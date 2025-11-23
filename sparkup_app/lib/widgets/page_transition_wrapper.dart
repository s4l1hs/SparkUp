import 'package:flutter/material.dart';
import '../utils/color_utils.dart';

class PageTransitionWrapper {
  /// A softer "fade through" transition used across the app.
  ///
  /// Uses a longer, eased duration with a very subtle scale and elevation
  /// to create a pleasant, non-jarring motion. Respects platform
  /// `accessibleNavigation` and disables animations when requested.
  static Route<T> fadeThrough<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 600),
      reverseTransitionDuration: const Duration(milliseconds: 420),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final media = MediaQuery.of(context);
        if (media.accessibleNavigation) {
          // Respect reduce-motion / accessible navigation settings.
          return child;
        }

        // Soft eased opacity curve.
        final opacity = CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);

        // Very gentle scale so content feels grounded.
        final scale = Tween<double>(begin: 0.995, end: 1.0).animate(CurvedAnimation(parent: animation, curve: const Cubic(0.22, 1.0, 0.36, 1.0)));

        // Soft elevation lift to give a material feel during transition.
        final elevationTween = Tween<double>(begin: 0.0, end: 6.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuad));

        // Slight upward offset (tiny) to add depth without being distracting.
        final offset = Tween<Offset>(begin: const Offset(0, 0.012), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));

        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final elev = elevationTween.value;
            final bgShadow = colorWithOpacity(Colors.black, 0.12);

            Widget current = FadeTransition(
              opacity: opacity,
              child: SlideTransition(
                position: offset,
                child: ScaleTransition(
                  scale: scale,
                  child: child,
                ),
              ),
            );

            // Apply a subtle PhysicalModel to create animated elevation/shadow.
            return PhysicalModel(
              color: Colors.transparent,
              shadowColor: bgShadow,
              elevation: elev,
              borderRadius: BorderRadius.circular(12.0),
              child: ClipRRect(borderRadius: BorderRadius.circular(12.0), child: current),
            );
          },
        );
      },
    );
  }
}
