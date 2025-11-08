import 'package:flutter/material.dart';

/// Small helper to create a color with opacity without using deprecated
/// component getters like .red/.green/.blue or .withOpacity.
Color colorWithOpacity(Color color, double opacity) {
  final int argb = color.toARGB32();
  final int r = (argb >> 16) & 0xFF;
  final int g = (argb >> 8) & 0xFF;
  final int b = argb & 0xFF;
  return Color.fromARGB((opacity * 255).round(), r, g, b);
}
