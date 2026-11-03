import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract final class DownloadNotification {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static bool _failed = false;
  static const _id = 41001;

  static Future<void> init() async {
    if (_ready || _failed) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        const InitializationSettings(android: android),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      _failed = true;
    }
  }

  static Future<void> progress(int percent, String text) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.show(
        _id,
        '保存视频',
        text,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'video_download',
            '视频下载',
            channelDescription: '保存视频到相册的下载进度',
            importance: Importance.low,
            priority: Priority.low,
            onlyAlertOnce: true,
            ongoing: true,
            autoCancel: false,
            showProgress: true,
            maxProgress: 100,
            progress: percent.clamp(0, 100).toInt(),
          ),
        ),
      );
    } catch (_) {}
  }

  static Future<void> done(String text) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.show(
        _id,
        '保存视频',
        text,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'video_download',
            '视频下载',
            channelDescription: '保存视频到相册的下载进度',
            importance: Importance.low,
            priority: Priority.low,
            onlyAlertOnce: true,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(seconds: 3));
      await _plugin.cancel(_id);
    } catch (_) {}
  }

  static Future<void> cancel() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(_id);
    } catch (_) {}
  }
}
