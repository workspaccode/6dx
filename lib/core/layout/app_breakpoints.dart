import 'package:flutter/widgets.dart';

/// Layout breakpoints shared by the adaptive shells.
class AppBreakpoints {
  AppBreakpoints._();

  /// Below this the phone layout is used: bottom navigation, 20px gutters.
  static const double compactMaxWidth = 700;

  /// From here on the sidebar shows its labels next to the icons.
  static const double expandedMinWidth = 1100;

  /// Page content wider than this is centred instead of stretched.
  static const double maxContentWidth = 1180;

  static const double sidebarCollapsedWidth = 88;
  static const double sidebarExpandedWidth = 264;

  /// Size the desktop runners open with (see `windows/`, `linux/`, `macos/`).
  static const Size defaultWindowSize = Size(1280, 800);

  /// The window never shrinks below this, so the shell always stays usable.
  static const Size minimumWindowSize = Size(900, 600);
}

/// The three window layouts 6DX ships: phone, small desktop window and a full
/// desktop window.
enum WindowSizeClass {
  compact,
  medium,
  expanded;

  bool get isCompact => this == WindowSizeClass.compact;

  bool get isExpanded => this == WindowSizeClass.expanded;

  /// True when the window is wide enough for a sidebar instead of a
  /// bottom navigation bar.
  bool get usesSidebar => this != WindowSizeClass.compact;

  /// True when the sidebar has room for its labels.
  bool get showsSidebarLabels => this == WindowSizeClass.expanded;

  static WindowSizeClass fromWidth(double width) {
    if (width < AppBreakpoints.compactMaxWidth) return WindowSizeClass.compact;
    if (width < AppBreakpoints.expandedMinWidth) return WindowSizeClass.medium;
    return WindowSizeClass.expanded;
  }

  static WindowSizeClass of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);
}
