import 'package:flutter_test/flutter_test.dart';

import 'package:reclaim_flutter/app.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ReclaimApp());

    expect(find.text('Reclaim'), findsOneWidget);
  });
}