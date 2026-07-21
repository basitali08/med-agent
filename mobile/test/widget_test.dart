// Smoke test: the app boots and renders, surviving the splash-screen timer.
import 'package:flutter_test/flutter_test.dart';
import 'package:med_agent/main.dart';

void main() {
  testWidgets('app boots and passes the splash timer', (WidgetTester tester) async {
    await tester.pumpWidget(const MedAgentApp());
    // Let the 2s splash timer fire and navigate to the login screen.
    await tester.pump(const Duration(seconds: 3));
    // 'MED AGENT' appears on both the splash and login screens.
    expect(find.text('MED AGENT'), findsWidgets);
  });
}
