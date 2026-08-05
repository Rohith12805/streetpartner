import 'package:flutter_test/flutter_test.dart';
import 'package:streetpartner/main.dart';

void main() {
  testWidgets('SafeGuard app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SafeGuardApp());
    expect(find.byType(SafeGuardApp), findsOneWidget);
  });
}
