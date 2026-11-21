import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_providers.dart';
import 'core/config/app_config.dart';
import 'core/notifications/notification_service.dart';
import 'core/storage/local_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.isMisconfigured) {
    runApp(const _MisconfiguredApp());
    return;
  }

  // Identity is GitHub's: the device flow talks to github.com over HTTPS and
  // the Go backend verifies the resulting grant, so nothing here depends on a
  // platform specific auth plugin.
  final localStorage = await LocalStorageService.create();

  runApp(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(localStorage),
      ],
      child: const SixDxApp(),
    ),
  );

  // The notification plugin talks to the platform and must never block the
  // launch: on a slow device (or when the app is started by the
  // BOOT_COMPLETED broadcast) it would ANR the whole process.
  unawaited(_initNotifications());
}

Future<void> _initNotifications() async {
  try {
    await NotificationService().initialize();
  } catch (error) {
    debugPrint('6DX: notification init failed — $error');
  }
}

/// Shown by a release build that was compiled without API_BASE_URL, instead of
/// an app that silently tries to reach localhost.
class _MisconfiguredApp extends StatelessWidget {
  const _MisconfiguredApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'النسخة دي اتبنت من غير عنوان السيرفر.' '\n'
                'ابنيها تاني بـ --dart-define=API_BASE_URL=<عنوان السيرفر>',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
