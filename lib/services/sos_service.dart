import 'package:flutter/services.dart';

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
      timestamp: (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class SosService {
  static const MethodChannel _channel =
      MethodChannel('com.example.streetpartner/sos_channel');

  static Function()? _onShakeCallback;

  /// Registers a callback that triggers when the device is shaken (3-shake gesture)
  static void initializeShakeHandler(Function() onShake) {
    _onShakeCallback = onShake;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShakeDetected') {
        _onShakeCallback?.call();
      }
    });
  }

  /// Plays emergency alarm siren sound
  static Future<void> playAlarmSound() async {
    try {
      await _channel.invokeMethod('playAlarmSound');
    } catch (_) {}
  }

  /// Stops emergency alarm siren sound
  static Future<void> stopAlarmSound() async {
    try {
      await _channel.invokeMethod('stopAlarmSound');
    } catch (_) {}
  }

  /// Triggers an emergency SOS alert by making native platform calls for
  /// phone call, SMS dispatch, location fetch, and haptic vibration feedback.
  static Future<SosResult> triggerSosAlert({
    List<String> phoneNumbers = const ['112', '+18005550199'],
    String message = 'EMERGENCY SOS: I need immediate assistance!',
    bool callEmergency = true,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'triggerSosAlert',
        {
          'phoneNumbers': phoneNumbers,
          'message': message,
          'callEmergency': callEmergency,
        },
      );

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
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getDeviceLocation');
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
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('checkPermissions');
      if (result != null) {
        return Map<String, bool>.from(result);
      }
    } on PlatformException catch (_) {}
    return {
      'sms': false,
      'call': false,
      'location': false,
      'allGranted': false,
    };
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
}
