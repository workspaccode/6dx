import 'package:awesome_notifications/awesome_notifications.dart';

import '../constants/app_colors.dart';
import '../utils/logger.dart';

/// Thin wrapper around `awesome_notifications` so the rest of the app never
/// touches the plugin API directly.
class NotificationService {
  NotificationService([AwesomeNotifications? notifications])
      : _notifications = notifications ?? AwesomeNotifications();

  final AwesomeNotifications _notifications;

  static const String _tag = 'Notifications';
  static const String _channelKey = 'sixdx_channel';

  static final NotificationChannel _channel = NotificationChannel(
    channelKey: _channelKey,
    channelName: '6DX',
    channelDescription: 'General 6DX notifications',
    importance: NotificationImportance.High,
    playSound: true,
    enableVibration: true,
    ledColor: AppColors.accent,
  );

  Future<void> initialize() async {
    try {
      await _notifications.initialize(
        '@mipmap/ic_launcher',
        [_channel],
      );

      await _notifications.setListeners(
        onActionReceivedMethod: onActionReceived,
        onNotificationDisplayedMethod: onNotificationDisplayed,
      );
    } catch (e) {
      AppLogger.w(_tag, 'Failed to initialize notifications', e);
    }
  }
  Future<bool> requestPermission() async {
    try {
      if (!await _notifications.isNotificationAllowed()) {
        await _notifications.requestPermissionToSendNotifications(
          channelKey: _channelKey,
        );
      }
      return await _notifications.isNotificationAllowed();
    } catch (e) {
      AppLogger.w(_tag, 'Failed to request notification permission', e);
      return false;
    }
  }

  /// Shows an immediate notification.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
    NotificationLayout layout = NotificationLayout.Default,
  }) async {
    try {
      await _notifications.createNotification(
        content: NotificationContent(
          id: id,
          channelKey: _channelKey,
          title: title,
          body: body,
          payload: payload == null ? null : {'data': payload},
          notificationLayout: layout,
          color: AppColors.accent,
        ),
      );
    } catch (e) {
      AppLogger.w(_tag, 'Failed to show notification', e);
    }
  }

  /// Schedules a notification for later.
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime date,
    String? payload,
  }) async {
    try {
      await _notifications.createNotification(
        content: NotificationContent(
          id: id,
          channelKey: _channelKey,
          title: title,
          body: body,
          payload: payload == null ? null : {'data': payload},
        ),
        schedule: NotificationCalendar.fromDate(
          date: date,
          allowWhileIdle: true,
        ),
      );
    } catch (e) {
      AppLogger.w(_tag, 'Failed to schedule notification', e);
    }
  }

  Future<void> cancel(int id) => _notifications.cancel(id);

  @pragma('vm:entry-point')
  static Future<void> onActionReceived(ReceivedAction action) async {
    AppLogger.i(_tag, 'Notification action received');
  }
  @pragma('vm:entry-point')
  static Future<void> onNotificationDisplayed(
    ReceivedNotification notification,
  ) async {
    AppLogger.i(_tag, 'Notification displayed');
  }
}
