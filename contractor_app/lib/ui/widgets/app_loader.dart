import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Standard full-screen loading indicator used everywhere a page is fetching
/// data. Always centered, always `kYellow`, no overrides — that consistency
/// is the whole point of this widget.
class AppLoader extends StatelessWidget {
  const AppLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: kYellow),
    );
  }
}
