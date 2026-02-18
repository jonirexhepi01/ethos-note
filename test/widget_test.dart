import 'package:flutter_test/flutter_test.dart';
import 'package:ethos_note/main.dart';

void main() {
  testWidgets('EthosNoteApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EthosNoteApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Verify the app renders without errors
    expect(find.text('Ethos Note'), findsAny);
  });
}
