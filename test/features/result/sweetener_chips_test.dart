// test/features/result/sweetener_chips_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cubed_app/core/rulebook.dart';
import 'package:cubed_app/domain/interpretation.dart';
import 'package:cubed_app/features/result/widgets/sweetener_chips.dart';

SweetenerChip chip(String slug, String name, Grade g, {bool risky = false}) =>
    SweetenerChip(
      slug: slug, name: name, klass: '당알코올', glycemic: g,
      amountG: null, isRisky: risky, note: null, cariogenic: '중립',
    );

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('혈당 위험 내림차순 정렬', (tester) async {
    await tester.pumpWidget(host(SweetenerChips(
      chips: [
        chip('erythritol', '에리스리톨', Grade.low),
        chip('maltitol', '말티톨', Grade.caution, risky: true),
        chip('xylitol', '자일리톨', Grade.mid, risky: true),
      ],
      notes: const {},
    )));
    final maltitolX = tester.getTopLeft(find.text('말티톨')).dx;
    final xylitolX = tester.getTopLeft(find.text('자일리톨')).dx;
    final erythritolX = tester.getTopLeft(find.text('에리스리톨')).dx;
    expect(maltitolX, lessThan(xylitolX));
    expect(xylitolX, lessThan(erythritolX));
  });

  testWidgets('칩 탭하면 바텀시트가 열린다', (tester) async {
    await tester.pumpWidget(host(SweetenerChips(
      chips: [chip('maltitol', '말티톨', Grade.caution, risky: true)],
      notes: const {},
    )));
    await tester.tap(find.text('말티톨'));
    await tester.pumpAndSettle();
    expect(find.text('혈당 주의'), findsOneWidget); // 시트의 등급 배지
    expect(find.textContaining('양 조절이 필요해요'), findsOneWidget); // 폴백 문장
  });

  testWidgets('긴 노트 텍스트도 오버플로 없이 시트가 열린다', (tester) async {
    final longNote = '아주 긴 설명. ' * 120;
    await tester.pumpWidget(host(SweetenerChips(
      chips: [
        SweetenerChip(
          slug: 'maltitol', name: '말티톨', klass: '당알코올', glycemic: Grade.caution,
          amountG: null, isRisky: true, note: longNote, cariogenic: '중립',
        ),
      ],
      notes: const {},
    )));
    await tester.tap(find.text('말티톨'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull); // 오버플로 예외 없음
    expect(find.textContaining('아주 긴 설명.'), findsOneWidget);
  });

  testWidgets('빈 목록 안내 문구', (tester) async {
    await tester.pumpWidget(host(const SweetenerChips(chips: [], notes: {})));
    expect(find.text('표시된 대체당이 없어요.'), findsOneWidget);
  });
}
