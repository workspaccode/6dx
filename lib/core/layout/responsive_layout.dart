import 'package:flutter/material.dart';

import 'app_breakpoints.dart';

/// Publishes the [WindowSizeClass] the app shell resolved for this frame.
class ResponsiveLayout extends InheritedWidget {
  const ResponsiveLayout({
    super.key,
    required this.sizeClass,
    required super.child,
  });

  final WindowSizeClass sizeClass;

  /// Never throws: outside the shell (a widget test, a preview) the class is
  /// derived from the ambient [MediaQuery].
  static WindowSizeClass of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ResponsiveLayout>();
    return scope?.sizeClass ?? WindowSizeClass.of(context);
  }

  @override
  bool updateShouldNotify(ResponsiveLayout oldWidget) =>
      oldWidget.sizeClass != sizeClass;
}

extension ResponsiveLayoutContext on BuildContext {
  WindowSizeClass get sizeClass => ResponsiveLayout.of(this);
}

/// Keeps page content readable on wide windows by centring it and capping the
/// width. On narrow windows the cap is never reached, so it is a no-op.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
