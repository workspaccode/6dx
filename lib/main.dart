import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_providers.dart';
import 'core/config/app_config.dart';
import 'core/notifications/notification_service.dart';
import 'core/storage/local_storage_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.useFirebaseAuth && !AppConfig.useDeviceFlowFallback) {
    // Firebase is the identity provider only — the data lives in the Go
    // backend (see backend/), so nothing but Auth is initialised here.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

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
