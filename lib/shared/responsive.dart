import 'package:flutter/material.dart';

/// Responsive breakpoints (Material window classes).
class FrBreakpoints {
  static const double compact = 700;
  static const double medium = 1100;

  static bool isCompact(double width) => width < compact;
  static bool isMedium(double width) => width >= compact && width < medium;
  static bool isExpanded(double width) => width >= medium;
}

/// Rebuilds on breakpoint change.
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext, BoxConstraints) builder;
  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: builder);
  }
}
