import 'package:flutter_test/flutter_test.dart';
import 'package:flashlight/main.dart';

void main() {
  testWidgets('shows the power button in the OFF state', (tester) async {
    await tester.pumpWidget(const FlashlightApp());
    expect(find.text('OFF'), findsOneWidget);
    expect(find.text('Steady'), findsOneWidget);
  });
}
