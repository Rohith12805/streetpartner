import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class SosResult {
  final bool success;
  final String smsStatus;
  final double latitude;
  final double longitude;
  final int timestamp;
  final String? errorMessage;

  SosResult({
    required this.success,
    required this.smsStatus,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.errorMessage,
  });

  factory SosResult.fromMap(Map<dynamic, dynamic> map) {
    return SosResult(
      success: map['success'] as bool? ?? false,
      smsStatus: map['smsStatus'] as String? ?? 'Unknown',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      timestamp:
          (map['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class SosService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.streetpartner/sos_channel',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.example.streetpartner/sos_timer_events',
  );

  static final AudioPlayer _audioPlayer = AudioPlayer();

  static Future<void> playSiren() async {
    try {
      await _channel.invokeMethod('playAlarmSound');
    } catch (e) {
      debugPrint('Error playing native background siren: $e');
    }
  }

  static Future<void> stopSiren() async {
    try {
      await _channel.invokeMethod('stopAlarmSound');
      await _audioPlayer.stop();
    } catch (_) {}
  }

  /// Starts the native Android Foreground Service.
  static Future<void> startSosService({
    required List<String> phoneNumbers,
    required String message,
    required String userId,
    String? emergencyId,
  }) async {
    try {
      await _channel.invokeMethod('startForegroundService', {
        'phoneNumbers': phoneNumbers,
        'message': message,
        'userId': userId,
        'emergencyId': emergencyId ?? '',
      });
    } catch (_) {}
  }

  /// Stops the native Android Foreground Service entirely.
  static Future<void> stopForegroundService() async {
    try {
      await _channel.invokeMethod('stopForegroundService');
    } catch (_) {}
  }

  /// Triggers the 10-second SOS countdown manually.
  static Future<void> triggerSosCountdown({
    required List<String> phoneNumbers,
    required String message,
    String? userId,
    String? emergencyId,
    String triggerSource = 'SOS Button',
  }) async {
    try {
      await _channel.invokeMethod('triggerSosCountdown', {
        'phoneNumbers': phoneNumbers,
        'message': message,
        'userId': userId ?? 'unknown',
        'emergencyId': emergencyId ?? '',
        'triggerSource': triggerSource,
      });
    } catch (_) {}
  }

  /// Stops the ongoing SOS countdown and resets the notification.
  static Future<void> stopSosCountdown() async {
    stopSiren();
    try {
      await _channel.invokeMethod('stopSosCountdown');
    } catch (_) {}
  }

  /// Stops the active live location session and service.
  static Future<void> stopLiveLocation() async {
    try {
      await _channel.invokeMethod('stopLiveLocation');
    } catch (_) {}
  }

  /// Queries the real-time background status of the native SOS service
  static Future<Map<String, dynamic>> getServiceStatus() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getServiceStatus');
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return {
      'isLiveLocationActive': false,
      'isCountingDown': false,
      'secondsLeft': -1,
      'isRouteDeviation': false,
      'triggerSource': 'SOS Button',
    };
  }

  /// Gets a stream of timer ticks from the native foreground service.
  /// Stream of timer ticks during an active SOS countdown
  static Stream<Map<dynamic, dynamic>> get timerTickStream {
    return _eventChannel.receiveBroadcastStream().map((event) => event as Map<dynamic, dynamic>);
  }

  /// Triggers an emergency SOS alert by making native platform calls for
  /// phone call, SMS dispatch, location fetch, and haptic vibration feedback.
  static Future<SosResult> triggerSosAlert({
    List<String> phoneNumbers = const [],
    String message = 'EMERGENCY SOS: I need immediate assistance!',
    String userId = '',
    String? emergencyId,
  }) async {
    try {
      final result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('triggerSosAlert', {
            'phoneNumbers': phoneNumbers,
            'message': message,
            'userId': userId,
            'emergencyId': emergencyId ?? '',
          });

      if (result != null) {
        return SosResult.fromMap(result);
      }
      return SosResult(
        success: false,
        smsStatus: 'No response from native channel',
        latitude: 0.0,
        longitude: 0.0,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    } on PlatformException catch (e) {
      return SosResult(
        success: false,
        smsStatus: 'Platform Error',
        latitude: 0.0,
        longitude: 0.0,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        errorMessage: e.message,
      );
    } catch (e) {
      return SosResult(
        success: false,
        smsStatus: 'Error',
        latitude: 0.0,
        longitude: 0.0,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        errorMessage: e.toString(),
      );
    }
  }

  /// Fetches current device GPS coordinates from native Android LocationManager.
  static Future<Map<String, dynamic>?> getDeviceLocation() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getDeviceLocation',
      );
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
    } on PlatformException catch (_) {
      // Platform channel unavailable or permission missing
    }
    return null;
  }

  /// Checks if required permissions (SMS, Call, Location) are granted.
  static Future<Map<String, bool>> checkPermissions() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'checkPermissions',
      );
      if (result != null) {
        final permissions = Map<String, bool>.from(result);
        return {
          'sms': permissions['sms'] ?? false,
          'call': permissions['call'] ?? false,
          'location': permissions['location'] ?? false,
          'allGranted': permissions['allGranted'] ?? false,
        };
      }
    } on PlatformException catch (_) {}
    return {'sms': false, 'call': false, 'location': false, 'allGranted': false};
  }

  /// Requests permissions natively from Android OS.
  static Future<bool> requestPermissions() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermissions');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<void> startGeofenceMonitoring(
    double lat,
    double lng,
    double radius, {
    List<String>? phoneNumbers,
    String? userId,
  }) async {
    try {
      await _channel.invokeMethod('startGeofenceMonitoring', {
        'lat': lat,
        'lng': lng,
        'radius': radius,
        'phoneNumbers': phoneNumbers ?? [],
        'userId': userId ?? '',
      });
    } catch (_) {}
  }

  static Future<void> startRouteMonitoring(List<Map<String, double>> polyline) async {
    try {
      await _channel.invokeMethod('startRouteMonitoring', {
        'polyline': polyline,
      });
    } catch (_) {}
  }

  static Future<void> updateRouteMonitoring(List<Map<String, double>> polyline) async {
    try {
      await _channel.invokeMethod('updateRouteMonitoring', {
        'polyline': polyline,
      });
    } catch (_) {}
  }

  static Future<void> stopMonitoring() async {
    try {
      await _channel.invokeMethod('stopMonitoring');
    } catch (_) {}
  }
}
