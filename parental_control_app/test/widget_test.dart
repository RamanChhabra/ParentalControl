// Basic Flutter widget test for Parental Control app.

import 'package:flutter_test/flutter_test.dart';
import 'package:parental_control_app/main.dart';

void main() {
  testWidgets('App loads and shows role selector', (WidgetTester tester) async {
    await tester.pumpWidget(const ParentalControlApp());
    await tester.pumpAndSettle();

    expect(find.text('Parental Control'), findsOneWidget);
    expect(find.text('Parent'), findsOneWidget);
    expect(find.text('Child device'), findsOneWidget);
  });
}
