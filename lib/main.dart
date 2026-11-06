import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
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
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _syncMyProfile();
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

/// Keeps the public profile (`users/{uid}`) fresh so other members can show a
/// name, an e-mail and an avatar — Firestore has no `auth.users` the clients
/// may read. The callable writes `defaultWorkspaceId` on its own side, so the
/// merge never clobbers it.
Future<void> _syncMyProfile() async {
  try {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .doc('users/${user.uid}')
        .set({
          'displayName': user.displayName,
          'email': user.email,
          'photoURL': user.photoURL,
        }, SetOptions(merge: true));
  } catch (error) {
    debugPrint('6DX: profile sync failed — $error');
  }
}

Future<void> _initNotifications() async {
  try {
    await NotificationService().initialize();
  } catch (error) {
    debugPrint('6DX: notification init failed — $error');
  }
}
