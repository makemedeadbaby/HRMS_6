import 'package:flutter_test/flutter_test.dart';
import 'package:abhishek_attendance/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AbhishekAttendanceApp());
    expect(find.byType(AbhishekAttendanceApp), findsOneWidget);
  });
}
