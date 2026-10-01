import 'package:flutter_test/flutter_test.dart';
import 'package:gaz_field_agent/main.dart';

void main() {
  testWidgets('app boots to bootstrap gate', (WidgetTester tester) async {
    await tester.pumpWidget(const GazFieldApp());
    await tester.pump();
    expect(find.byType(GazFieldApp), findsOneWidget);
  });
}
