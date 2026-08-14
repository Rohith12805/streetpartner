import 'package:flutter_test/flutter_test.dart';
import 'package:streetpartner/main.dart';

void main() {
  testWidgets('Sheild app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SheildApp());
    expect(find.byType(SheildApp), findsOneWidget);
  });
}
