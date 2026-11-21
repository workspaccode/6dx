import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Desktop-friendly scrolling: the mouse can drag a scrollable, which is what
/// users of native desktop lists expect. Wheel and trackpad scrolling already
/// work through the default behaviour.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
  };
}
