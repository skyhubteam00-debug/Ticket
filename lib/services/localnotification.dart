import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

/// ====================== Notification Service ======================
class TicketNotificationService {
  // Singleton
  static final TicketNotificationService instance =
      TicketNotificationService._internal();
  TicketNotificationService._internal();

  /// Initialize notifications
  Future<void> init() async {
    await AwesomeNotifications().initialize(
      null, // icon for notifications, null uses default app icon
      [
        NotificationChannel(
          channelKey: 'ticket_channel',
          channelName: 'Ticket Notifications',
          channelDescription: 'Notifications for ticket updates',
          defaultColor: Colors.indigo,
          importance: NotificationImportance.High,
          channelShowBadge: true,
        ),
      ],
    );

    // Request permissions on iOS/Android 13+
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  /// Show a simple notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'ticket_channel',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        payload: payload != null ? {'payload': payload} : null,
      ),
    );
  }

  /// Notify when ticket is called
  Future<void> notifyTicketCalled({required int ticketNumber}) async {
    await showNotification(
      id: ticketNumber,
      title: 'Ticket #$ticketNumber',
      body: 'Please head to the counter 🛎️',
    );
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await AwesomeNotifications().cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
  }
}
