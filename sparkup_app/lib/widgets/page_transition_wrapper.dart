import 'package:flutter/material.dart';

class PageTransitionWrapper {
  static Route<T> fadeThrough<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 420),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final opacity = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        final scale = Tween<double>(begin: 0.98, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack));
        return FadeTransition(opacity: opacity, child: ScaleTransition(scale: scale, child: child));
      },
    );
  }
}
