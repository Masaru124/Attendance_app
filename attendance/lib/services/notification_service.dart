import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  /// Initialize push notifications
  Future<void> initialize() async {
    // Request permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission for notifications');
    } else {
      print('User denied notification permission');
    }

    // Get and print the FCM token
    _fcmToken = await _messaging.getToken();
    print('FCM Token: $_fcmToken');

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      print('FCM Token refreshed: $newToken');
      _fcmToken = newToken;
      // Send new token to backend
      _sendTokenToBackend(newToken);
    });

    // Handle notification when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification when app is in background
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('Foreground message received: ${message.notification?.title}');

    if (message.notification != null) {
      // Show a snackbar or dialog
      // You can use a global key to show a snackbar
    }
  }

  /// Handle background messages
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('Background message received: ${message.notification?.title}');

    // You can navigate to a specific screen here
    // This requires a navigator key setup
  }

  /// Send FCM token to backend
  Future<void> _sendTokenToBackend(String token) async {
    try {
      await ApiService().saveFcmToken(token);
      print('FCM token saved to backend');
    } catch (e) {
      print('Failed to save FCM token: $e');
    }
  }

  /// Call this when user logs in
  Future<void> onUserLogin() async {
    if (_fcmToken != null) {
      await _sendTokenToBackend(_fcmToken!);
    }
  }

  /// Call this when user logs out
  Future<void> onUserLogout() async {
    if (_fcmToken != null) {
      try {
        await ApiService().deleteFcmToken(_fcmToken!);
        print('FCM token deleted from backend');
      } catch (e) {
        print('Failed to delete FCM token: $e');
      }
    }
  }

  /// Subscribe to topics for broad notifications
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    print('Subscribed to topic: $topic');
  }

  /// Unsubscribe from topics
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    print('Unsubscribed from topic: $topic');
  }
}
