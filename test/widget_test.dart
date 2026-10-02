import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_diary/core/widgets/status_badge.dart';
import 'package:magic_diary/core/widgets/summary_card.dart';

void main() {
  testWidgets('StatusBadge renders correct status text', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusBadge(status: 'expiring_soon'),
        ),
      ),
    );

    expect(find.text('EXPIRING SOON'), findsOneWidget);
  });

  testWidgets('SummaryCard renders title, value, and subtitle', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SummaryCard(
            title: 'Total Products',
            value: '5',
            subtitle: '3 with warranty',
            icon: Icons.verified,
            color: Colors.blue,
          ),
        ),
      ),
    );

    expect(find.text('Total Products'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('3 with warranty'), findsOneWidget);
  });
}
