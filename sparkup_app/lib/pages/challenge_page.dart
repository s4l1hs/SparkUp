import 'package:flutter/material.dart';

/// Challenge feature removed — simple stub retained so imports elsewhere
/// do not break. Use the Analysis tab for per-category performance.
class ChallengePage extends StatelessWidget {
  final String idToken;
  const ChallengePage({super.key, required this.idToken});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analysis')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('This feature has been removed. Open the Analysis tab.'),
        ),
      ),
    );
  }
}