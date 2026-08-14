import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetpartner/models/fake_call.dart';
import 'package:streetpartner/services/fake_call_service.dart';
import 'package:streetpartner/screens/fake_call_generator_screen.dart';
import 'package:streetpartner/screens/fake_incoming_call_screen.dart';
import 'package:streetpartner/screens/fake_call_conversation_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('FakeCall Model Tests', () {
    test('FakeCall serialization and deserialization', () {
      final now = DateTime.now().add(const Duration(minutes: 5));
      final fakeCall = FakeCall(
        id: '123',
        callerName: 'Mom',
        phoneNumber: '9876543210',
        scheduledDateTime: now,
        status: FakeCallStatus.scheduled,
      );

      final json = fakeCall.toJson();
      expect(json['id'], '123');
      expect(json['callerName'], 'Mom');
      expect(json['phoneNumber'], '9876543210');

      final restored = FakeCall.fromJson(json);
      expect(restored.id, '123');
      expect(restored.callerName, 'Mom');
      expect(restored.phoneNumber, '9876543210');
      expect(restored.status, FakeCallStatus.scheduled);
    });

    test('FakeCall copyWith and status updates', () {
      final fakeCall = FakeCall(
        id: '123',
        callerName: 'Boss',
        scheduledDateTime: DateTime.now(),
      );

      final updated = fakeCall.copyWith(
        callerName: 'Manager',
        status: FakeCallStatus.completed,
      );

      expect(updated.id, '123');
      expect(updated.callerName, 'Manager');
      expect(updated.status, FakeCallStatus.completed);
    });
  });

  group('FakeCallService Local Persistence & CRUD Tests', () {
    test('Create and Save Fake Call', () async {
      final now = DateTime.now().add(const Duration(minutes: 10));
      final call = FakeCall(
        id: 'c1',
        callerName: 'Dad',
        phoneNumber: '1234567890',
        scheduledDateTime: now,
      );

      await FakeCallService.instance.saveCall(call);

      final calls = await FakeCallService.instance.getCalls();
      expect(calls.length, 1);
      expect(calls.first.callerName, 'Dad');
      expect(calls.first.phoneNumber, '1234567890');
    });

    test('Reload application and verify saved calls persist', () async {
      final now = DateTime.now().add(const Duration(minutes: 15));
      final call1 = FakeCall(
        id: 'c1',
        callerName: 'Sister',
        scheduledDateTime: now,
      );
      final call2 = FakeCall(
        id: 'c2',
        callerName: 'Emergency Contact',
        scheduledDateTime: now.add(const Duration(minutes: 5)),
      );

      await FakeCallService.instance.saveCall(call1);
      await FakeCallService.instance.saveCall(call2);

      // Verify restored list from SharedPreferences
      final calls = await FakeCallService.instance.getCalls();
      expect(calls.length, 2);
      expect(calls[0].callerName, 'Sister');
      expect(calls[1].callerName, 'Emergency Contact');
    });

    test('Edit Fake Call', () async {
      final now = DateTime.now().add(const Duration(minutes: 10));
      final call = FakeCall(
        id: 'c1',
        callerName: 'Doctor',
        scheduledDateTime: now,
      );

      await FakeCallService.instance.saveCall(call);

      final updatedCall = call.copyWith(
        callerName: 'Dr. Smith',
        phoneNumber: '555-0199',
      );

      await FakeCallService.instance.updateCall(updatedCall);

      final calls = await FakeCallService.instance.getCalls();
      expect(calls.length, 1);
      expect(calls.first.callerName, 'Dr. Smith');
      expect(calls.first.phoneNumber, '555-0199');
    });

    test('Delete/Cancel Fake Call', () async {
      final now = DateTime.now().add(const Duration(minutes: 10));
      final call = FakeCall(
        id: 'c1',
        callerName: 'Police',
        scheduledDateTime: now,
      );

      await FakeCallService.instance.saveCall(call);
      var calls = await FakeCallService.instance.getCalls();
      expect(calls.length, 1);

      await FakeCallService.instance.deleteCall('c1');
      calls = await FakeCallService.instance.getCalls();
      expect(calls.isEmpty, true);
    });
  });

  group('Fake Call UI & Widgets Tests', () {
    testWidgets('FakeCallGeneratorScreen renders caller input & time options',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FakeCallGeneratorScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fake Call Generator'), findsOneWidget);
      expect(find.text('Caller Information'), findsOneWidget);
      expect(find.text('Schedule Fake Call'), findsOneWidget);
      expect(find.text('10 Seconds'), findsOneWidget);
      expect(find.text('30 Seconds'), findsOneWidget);
      expect(find.text('1 Minute'), findsOneWidget);
      expect(find.text('5 Minutes'), findsOneWidget);
    });

    testWidgets('FakeIncomingCallScreen displays caller info & Accept/Decline',
        (WidgetTester tester) async {
      final call = FakeCall(
        id: 'c_test',
        callerName: 'Mom',
        phoneNumber: '9876543210',
        scheduledDateTime: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FakeIncomingCallScreen(fakeCall: call),
        ),
      );

      expect(find.text('Mom'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
      expect(find.text('Simulated Incoming Call'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
    });

    testWidgets(
        'FakeCallConversationScreen renders ongoing call UI and End Call button',
        (WidgetTester tester) async {
      final call = FakeCall(
        id: 'c_conv',
        callerName: 'Boss',
        phoneNumber: '1122334455',
        scheduledDateTime: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FakeCallConversationScreen(fakeCall: call),
        ),
      );

      expect(find.text('Boss'), findsOneWidget);
      expect(find.text('1122334455'), findsOneWidget);
      expect(find.text('Simulated Ongoing Call'), findsOneWidget);
      expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('00:02'), findsOneWidget);
    });
  });
}
