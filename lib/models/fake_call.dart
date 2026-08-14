enum FakeCallStatus {
  scheduled,
  triggered,
  cancelled,
  completed;

  String toValue() => name;

  static FakeCallStatus fromValue(String? val) {
    return FakeCallStatus.values.firstWhere(
      (e) => e.name == val,
      orElse: () => FakeCallStatus.scheduled,
    );
  }
}

class FakeCall {
  final String id;
  final String callerName;
  final String? phoneNumber;
  final DateTime scheduledDateTime;
  final FakeCallStatus status;

  const FakeCall({
    required this.id,
    required this.callerName,
    this.phoneNumber,
    required this.scheduledDateTime,
    this.status = FakeCallStatus.scheduled,
  });

  bool get isUpcoming =>
      status == FakeCallStatus.scheduled &&
      scheduledDateTime.isAfter(DateTime.now());

  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final callDate = DateTime(
      scheduledDateTime.year,
      scheduledDateTime.month,
      scheduledDateTime.day,
    );

    if (callDate == today) {
      return 'Today';
    } else if (callDate == tomorrow) {
      return 'Tomorrow';
    } else {
      return '${scheduledDateTime.day.toString().padLeft(2, '0')}/${scheduledDateTime.month.toString().padLeft(2, '0')}/${scheduledDateTime.year}';
    }
  }

  String get formattedTime {
    final hour = scheduledDateTime.hour;
    final minute = scheduledDateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final formattedMinute = minute.toString().padLeft(2, '0');
    return '$formattedHour:$formattedMinute $period';
  }

  String get formattedDisplayString => '$formattedDate • $formattedTime';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'callerName': callerName,
      'phoneNumber': phoneNumber,
      'scheduledDateTime': scheduledDateTime.toIso8601String(),
      'status': status.toValue(),
    };
  }

  factory FakeCall.fromJson(Map<String, dynamic> json) {
    return FakeCall(
      id: json['id'] as String,
      callerName: json['callerName'] as String? ?? 'Unknown',
      phoneNumber: json['phoneNumber'] as String?,
      scheduledDateTime: DateTime.parse(json['scheduledDateTime'] as String),
      status: FakeCallStatus.fromValue(json['status'] as String?),
    );
  }

  FakeCall copyWith({
    String? id,
    String? callerName,
    String? phoneNumber,
    DateTime? scheduledDateTime,
    FakeCallStatus? status,
  }) {
    return FakeCall(
      id: id ?? this.id,
      callerName: callerName ?? this.callerName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      status: status ?? this.status,
    );
  }
}
