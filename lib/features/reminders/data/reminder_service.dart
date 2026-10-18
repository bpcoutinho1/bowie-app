import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/reminders/domain/reminder_plan.dart';

/// The phone's notifications, behind an interface so tests run without them.
abstract interface class NotificationGateway {
  /// Whether the person allowed notifications.
  Future<bool> isEnabled();

  /// Shows the system question. True when allowed.
  Future<bool> requestPermission();

  /// Replaces every scheduled reminder with [reminders].
  Future<void> replaceAll(List<Reminder> reminders);

  Future<void> cancelAll();

  /// Routes of reminders the person taps while the app runs.
  Stream<String> get taps;

  /// The route of the reminder that opened the app, once.
  Future<String?> takeLaunchRoute();
}

class LocalNotificationsGateway implements NotificationGateway {
  LocalNotificationsGateway([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<String>.broadcast();
  Future<void>? _ready;
  var _launchTaken = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Lembretes',
      channelDescription: 'Vacinas perto de vencer e aniversários dos pets',
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> _init() => _ready ??= () async {
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Asked at the right moment (after the first pet), not at launch.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null) _taps.add(route);
      },
    );
  }();

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> isEnabled() async {
    await _init();
    final android = _android;
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    final options = await _ios?.checkPermissions();
    return options?.isEnabled ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    await _init();
    final android = _android;
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    return await _ios?.requestPermissions(
          alert: true,
          sound: true,
          badge: false,
        ) ??
        false;
  }

  @override
  Future<void> replaceAll(List<Reminder> reminders) async {
    await _init();
    await _plugin.cancelAllPendingNotifications();
    for (var i = 0; i < reminders.length; i++) {
      final reminder = reminders[i];
      final at = reminder.at;
      await _plugin.zonedSchedule(
        id: i + 1,
        scheduledDate: tz.TZDateTime(
          tz.local,
          at.year,
          at.month,
          at.day,
          at.hour,
          at.minute,
        ),
        notificationDetails: _details,
        // A reminder a few minutes late is fine; exact alarms need a special
        // Android permission.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: reminder.title,
        body: reminder.body,
        payload: reminder.route,
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    await _init();
    await _plugin.cancelAll();
  }

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> takeLaunchRoute() async {
    if (_launchTaken) return null;
    _launchTaken = true;
    await _init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }
}

/// Keeps the phone's reminders in step with the pets and their vaccines.
class ReminderService {
  ReminderService(this._store, this._gateway, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final PetLocalStore _store;
  final NotificationGateway _gateway;
  final DateTime Function() _now;

  NotificationGateway get gateway => _gateway;

  /// Schedules the reminders of every pet [user] cares for. Best effort:
  /// a phone that refuses only means no reminders.
  Future<void> reschedule(AppUser user) async {
    try {
      final pets = await _store.listPetsFor(normalizeEmail(user.email));
      final doses = {
        for (final pet in pets) pet.id: await _store.listDoses(pet.id),
      };
      await _gateway.replaceAll(
        planReminders(pets: pets, dosesByPet: doses, now: _now()),
      );
    } catch (error) {
      // Nothing about the pets in the log.
      if (kDebugMode) {
        debugPrint('Reminders not scheduled: ${error.runtimeType}');
      }
    }
  }

  /// After signing out, the reminders of that account go too.
  Future<void> clear() async {
    try {
      await _gateway.cancelAll();
    } catch (_) {}
  }
}
