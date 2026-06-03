import 'package:flutter_test/flutter_test.dart';
import 'package:nama_project/main.dart';

void main() {
  testWidgets('App launches and shows login page', (WidgetTester tester) async {
    await tester.pumpWidget(const SamsApp());
    await tester.pump();

    expect(find.text('SA Management'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
