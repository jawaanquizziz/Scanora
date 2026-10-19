import 'package:flutter_test/flutter_test.dart';
import 'package:scanora/app.dart';

void main() {
  testWidgets('Scanora app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ScanoraApp());
    await tester.pumpAndSettle();

    // Verify that the title Scanora is displayed
    expect(find.text('Scanora'), findsWidgets);
  });
}
