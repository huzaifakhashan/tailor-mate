// اختبار أساسي: يتأكد أن التطبيق يُقلع ويعرض الشاشة الرئيسية بدون أخطاء.

import 'package:flutter_test/flutter_test.dart';

import 'package:myproject555/main.dart';

void main() {
  testWidgets('App boots and shows the home screen title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TailorApp());
    await tester.pump();

    expect(find.text('قياسات العملاء'), findsOneWidget);
  });
}
