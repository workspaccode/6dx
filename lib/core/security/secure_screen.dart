import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Marks a screen as sensitive: on Android the window gets `FLAG_SECURE`
/// while it is shown, so it is left out of screenshots, screen recordings and
/// the recent-apps preview. Used on the sign-in device code and on the member
/// lists (names, e-mails, roles). Other platforms ignore it.
///
/// Nested or stacked secure screens are counted, so the flag is only cleared
/// when the last one goes.
class SecureScreen extends StatefulWidget {
  const SecureScreen({super.key, required this.child});

  final Widget child;

  static const MethodChannel _channel = MethodChannel('sixdx/secure_window');
  static int _active = 0;

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> _set(bool secure) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('setSecure', secure);
    } catch (_) {
      // No channel (tests, an old build): the screen still works.
    }
  }

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  @override
  void initState() {
    super.initState();
    if (SecureScreen._active++ == 0) SecureScreen._set(true);
  }

  @override
  void dispose() {
    if (--SecureScreen._active == 0) SecureScreen._set(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
