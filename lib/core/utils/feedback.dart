import 'package:flutter/material.dart';

import '../errors/exceptions.dart';

/// The user-facing text of an error: the server's own message when it sent
/// one, never a raw exception.
String describeError(Object error, {String fallback = 'حصل خطأ، حاول تاني.'}) {
  if (error is ServerException && error.message.isNotEmpty) return error.message;
  if (error is NetworkException && error.message.isNotEmpty) return error.message;
  if (error is UnauthorizedException) return 'انتهت الجلسة، سجّل الدخول تاني.';
  return fallback;
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Runs a write from a button: shows [done] on success and the error text
/// on failure. Returns whether it worked.
Future<bool> runAction(BuildContext context, Future<void> Function() action, {String? done}) async {
  try {
    await action();
    if (done != null && context.mounted) showSnack(context, done);
    return true;
  } catch (error) {
    if (context.mounted) showSnack(context, describeError(error));
    return false;
  }
}
