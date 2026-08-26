// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:traffic_data/main.dart';

void main() {
  testWidgets('앱바 제목이 정상적으로 표시되는지 확인', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('서울/경기 교통정보'), findsOneWidget);
  });
}
