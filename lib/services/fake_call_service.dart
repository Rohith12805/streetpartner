import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/fake_call.dart';
import '../screens/fake_incoming_call_screen.dart';

class FakeCallService {
  static final FakeCallService instance = FakeCallService._internal();

  FakeCallService._internal();

  GlobalKey<NavigatorState>? navigatorKey;

  static const String _storageKey = 'scheduled_fake_calls';
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final Map<String, Timer> _activeTimers = {};
  final StreamController<FakeCall> _incomingCallController =
      StreamController<FakeCall>.broadcast();

  Stream<FakeCall> get onIncomingCall => _incomingCallController.stream;

  bool _initialized = false;
  bool _isCallScreenActive = false;
  String? _activeCallId;

  bool get isCallScreenActive => _isCallScreenActive;

  void markCallEnded() {
    _isCallScreenActive = false;
    _activeCallId = null;
  }

  Future<void> playBuiltInRingtone() async {
    try {
      await const MethodChannel('com.example.streetpartner/sos_channel')
          .invokeMethod('playRingtone');
    } catch (e) {
      debugPrint('Error playing built-in ringtone: $e');
    }
  }

  Future<void> stopBuiltInRingtone() async {
    try {
      await const MethodChannel('com.example.streetpartner/sos_channel')
          .invokeMethod('stopRingtone');
    } catch (e) {
      debugPrint('Error stopping built-in ringtone: $e');
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          if (response.payload != null && response.payload!.isNotEmpty) {
            try {
              final jsonMap =
                  jsonDecode(response.payload!) as Map<String, dynamic>;
              final fakeCall = FakeCall.fromJson(jsonMap);
              _triggerCall(fakeCall);
            } catch (e) {
              debugPrint('Error parsing notification payload: $e');
            }
          }
        },
      );

      // Create high-priority Android Notification Channel
      final androidImpl =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImpl != null) {
        const channel = AndroidNotificationChannel(
          'fake_call_channel_v4',
          'Simulated Incoming Calls',
          description:
              'Channel for displaying simulated incoming fake call notifications',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );
        await androidImpl.createNotificationChannel(channel);
      }

      _initialized = true;
      debugPrint('FakeCallService initialized successfully.');

      const MethodChannel('com.example.streetpartner/sos_channel')
          .setMethodCallHandler((call) async {
        if (call.method == 'onNativeFakeCallTriggered') {
          try {
            final map = Map<String, dynamic>.from(call.arguments as Map);
            final fakeCall = FakeCall(
              id: map['id'] as String? ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
              callerName: map['callerName'] as String? ?? 'Incoming Call',
              phoneNumber: map['phoneNumber'] as String?,
              scheduledDateTime: DateTime.now(),
              status: FakeCallStatus.triggered,
            );
            _triggerCall(fakeCall);
          } catch (e) {
            debugPrint('Error handling native fake call event: $e');
          }
        }
      });

      await checkForInitialFakeCall();

      final launchDetails =
          await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final payload = launchDetails.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) {
          try {
            final jsonMap = jsonDecode(payload) as Map<String, dynamic>;
            final fakeCall = FakeCall.fromJson(jsonMap);
            _triggerCall(fakeCall);
          } catch (e) {
            debugPrint('Error parsing launch notification payload: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error initializing notification plugin: $e');
    }

    // Restore and schedule pending timers for active fake calls
    await _reschedulePendingCalls();
  }

  Future<void> checkForInitialFakeCall() async {
    try {
      final initialCall =
          await const MethodChannel('com.example.streetpartner/sos_channel')
              .invokeMethod<Map<dynamic, dynamic>>('getInitialFakeCall');
      if (initialCall != null) {
        final map = Map<String, dynamic>.from(initialCall);
        final fakeCall = FakeCall(
          id: map['id'] as String? ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          callerName: map['callerName'] as String? ?? 'Incoming Call',
          phoneNumber: map['phoneNumber'] as String?,
          scheduledDateTime: DateTime.now(),
          status: FakeCallStatus.triggered,
        );
        _triggerCall(fakeCall);
      }
    } catch (e) {
      debugPrint('Error checking initial fake call: $e');
    }
  }

  Future<bool> requestPermissions() async {
    return true;
  }

  Future<List<FakeCall>> getCalls() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list
          .map((e) => FakeCall.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading saved fake calls: $e');
      return [];
    }
  }

  Future<void> saveCall(FakeCall call) async {
    debugPrint(
        'Saving call: ${call.callerName}, scheduled for ${call.scheduledDateTime}');
    final calls = await getCalls();
    calls.add(call);
    await _saveCallsList(calls);
    await _scheduleCallTimerAndNotification(call);
  }

  Future<void> updateCall(FakeCall updatedCall) async {
    final calls = await getCalls();
    final index = calls.indexWhere((c) => c.id == updatedCall.id);
    if (index != -1) {
      calls[index] = updatedCall;
      await _saveCallsList(calls);
      await _cancelTimerAndNotification(updatedCall.id);
      if (updatedCall.status == FakeCallStatus.scheduled) {
        await _scheduleCallTimerAndNotification(updatedCall);
      }
    }
  }

  Future<void> deleteCall(String id) async {
    await _cancelTimerAndNotification(id);
    final calls = await getCalls();
    calls.removeWhere((c) => c.id == id);
    await _saveCallsList(calls);
  }

  Future<void> updateCallStatus(String id, FakeCallStatus newStatus) async {
    final calls = await getCalls();
    final index = calls.indexWhere((c) => c.id == id);
    if (index != -1) {
      calls[index] = calls[index].copyWith(status: newStatus);
      await _saveCallsList(calls);
      if (newStatus != FakeCallStatus.scheduled) {
        await _cancelTimerAndNotification(id);
      }
    }
  }

  Future<void> _saveCallsList(List<FakeCall> calls) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(calls.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  Future<void> _scheduleCallTimerAndNotification(FakeCall call) async {
    if (call.status != FakeCallStatus.scheduled) return;

    final now = DateTime.now();
    final delay = call.scheduledDateTime.difference(now);

    debugPrint('Scheduling timer for ${call.callerName} with delay: $delay');

    if (delay.isNegative) {
      debugPrint('Call scheduled in past, ignoring timer.');
      return;
    }

    await _cancelTimerAndNotification(call.id);

    // 1. In-app Timer
    _activeTimers[call.id] = Timer(delay, () {
      debugPrint('Timer fired for fake call ${call.id} (${call.callerName})!');
      _triggerCall(call);
    });

    // 2. Native Android Alarm (Wakes device & displays over lock screen / closed app)
    try {
      await const MethodChannel('com.example.streetpartner/sos_channel')
          .invokeMethod('scheduleNativeFakeCall', {
        'id': call.id,
        'callerName': call.callerName,
        'phoneNumber': call.phoneNumber ?? '',
        'delayMs': delay.inMilliseconds,
      });
    } catch (e) {
      debugPrint('Error scheduling native fake call alarm: $e');
    }

    // 3. Local Notification
    await _scheduleLocalNotification(call, delay);
  }

  Future<void> _scheduleLocalNotification(
      FakeCall call, Duration delay) async {
    try {
      final notificationId = call.id.hashCode.abs() % 100000;
      final scheduledTzDate = tz.TZDateTime.now(tz.local).add(delay);

      const androidDetails = AndroidNotificationDetails(
        'fake_call_channel_v4',
        'Simulated Incoming Calls',
        channelDescription:
            'Channel for displaying simulated incoming fake call notifications',
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.call,
        audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
        visibility: NotificationVisibility.public,
        ongoing: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      try {
        await _notificationsPlugin.zonedSchedule(
          notificationId,
          'Incoming Call',
          'Fake call from ${call.callerName}',
          scheduledTzDate,
          details,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: jsonEncode(call.toJson()),
        );
      } catch (e) {
        debugPrint(
            'AlarmClock failed, falling back to exactAllowWhileIdle: $e');
        await _notificationsPlugin.zonedSchedule(
          notificationId,
          'Incoming Call',
          'Fake call from ${call.callerName}',
          scheduledTzDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: jsonEncode(call.toJson()),
        );
      }
    } catch (e) {
      debugPrint('Error scheduling local notification: $e');
    }
  }

  void _triggerCall(FakeCall call) {
    if (_isCallScreenActive && _activeCallId == call.id) {
      debugPrint('Call screen is already active for call ${call.id}, ignoring duplicate trigger.');
      return;
    }

    _isCallScreenActive = true;
    _activeCallId = call.id;

    // Cancel timer and notification for this call so duplicate events do not fire
    _activeTimers[call.id]?.cancel();
    _activeTimers.remove(call.id);
    try {
      final notificationId = call.id.hashCode.abs() % 100000;
      _notificationsPlugin.cancel(notificationId);
    } catch (_) {}

    debugPrint('Triggering fake call screen for: ${call.callerName}');
    updateCallStatus(call.id, FakeCallStatus.triggered);
    _incomingCallController.add(call);

    try {
      const MethodChannel('com.example.streetpartner/sos_channel')
          .invokeMethod('wakeUpScreen');
    } catch (e) {
      debugPrint('Error waking up screen: $e');
    }

    final navContext = navigatorKey?.currentContext;
    if (navContext != null) {
      Navigator.of(navContext).push(
        MaterialPageRoute(
          builder: (_) => FakeIncomingCallScreen(fakeCall: call),
        ),
      ).then((_) {
        markCallEnded();
      });
    } else {
      debugPrint('Warning: navigatorKey.currentContext is null when triggering call.');
    }
  }

  Future<void> _cancelTimerAndNotification(String id) async {
    _activeTimers[id]?.cancel();
    _activeTimers.remove(id);

    try {
      await const MethodChannel('com.example.streetpartner/sos_channel')
          .invokeMethod('cancelNativeFakeCall', {'id': id});
    } catch (e) {
      debugPrint('Error cancelling native fake call alarm: $e');
    }

    try {
      final notificationId = id.hashCode.abs() % 100000;
      await _notificationsPlugin.cancel(notificationId);
    } catch (e) {
      debugPrint('Error cancelling notification: $e');
    }
  }

  Future<void> _reschedulePendingCalls() async {
    final calls = await getCalls();
    for (final call in calls) {
      if (call.status == FakeCallStatus.scheduled) {
        if (call.scheduledDateTime.isBefore(DateTime.now())) {
          // Mark old calls as completed or expired
          await updateCallStatus(call.id, FakeCallStatus.completed);
        } else {
          await _scheduleCallTimerAndNotification(call);
        }
      }
    }
  }

  void dispose() {
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
  }
}
