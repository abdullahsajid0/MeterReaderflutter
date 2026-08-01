// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:wattwise/main.dart';
import 'package:wattwise/store/wattwise_store.dart';

void main() {
  testWidgets('WattWise starts with an empty meter state',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => WattWiseStore(),
        child: const WattWiseApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No meters yet'), findsOneWidget);
    expect(find.text('Add Meter'), findsOneWidget);
  });
}
