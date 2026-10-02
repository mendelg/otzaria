import 'package:otzaria_icons/otzaria_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/library/view/library_daf_yomi.dart';
import 'package:otzaria/tools/calendar/bloc/calendar_cubit.dart';

/// מספק CalendarState קבוע בלי להריץ את אתחול ה-cubit האמיתי.
class _StubCalendarCubit extends Cubit<CalendarState> implements CalendarCubit {
  _StubCalendarCubit(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _StubCalendarCubit calendarCubit;

  CalendarState stateWithToday(DateTime today) =>
      CalendarState.initial().copyWith(todayGregorianDate: today);

  setUp(() {
    calendarCubit = _StubCalendarCubit(stateWithToday(DateTime.now()));
  });

  tearDown(() async {
    await calendarCubit.close();
  });

  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(
      body: BlocProvider<CalendarCubit>.value(
        value: calendarCubit,
        child: child,
      ),
    ),
  );

  /// הטקסט שעל כפתור הדף היומי.
  String dafText(WidgetTester tester) {
    final label = find.descendant(
      of: find.ancestor(
        of: find.byIcon(OtzariaIcons.book_24_regular),
        matching: find.byType(TextButton),
      ),
      matching: find.byType(Text),
    );
    return tester.widget<Text>(label.first).data ?? '';
  }

  TextButton buttonForIcon(WidgetTester tester, IconData icon) {
    return tester.widget<TextButton>(
      find.ancestor(
        of: find.byIcon(icon),
        matching: find.byType(TextButton),
      ),
    );
  }

  group('LibraryDafYomi — השבתת הדף היומי', () {
    testWidgets('dafEnabled=true — כפתור הדף היומי פעיל', (tester) async {
      await tester.pumpWidget(wrap(LibraryDafYomi(onDafYomiTap: (_, _) {})));

      expect(
        buttonForIcon(tester, OtzariaIcons.book_24_regular).onPressed,
        isNotNull,
      );
    });

    testWidgets('dafEnabled=false — הדף היומי מושבת, התאריך נשאר פעיל', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(LibraryDafYomi(dafEnabled: false, onDafYomiTap: (_, _) {})),
      );

      expect(
        buttonForIcon(tester, OtzariaIcons.book_24_regular).onPressed,
        isNull,
      );
      expect(
        buttonForIcon(tester, OtzariaIcons.calendar_24_regular).onPressed,
        isNotNull,
      );
    });
  });

  group('LibraryDafYomi — היום הלוחי', () {
    // רגרסיה: התאריך חושב מ-DateTime.now() ולכן התחלף בחצות, בעוד לוח השנה
    // מתחלף בשקיעה — כל הערב הוצג בסרגל יום אחד ובלוח יום אחר.
    testWidgets('התאריך נלקח מהיום הלוחי של הלוח, לא משעון המערכת', (
      tester,
    ) async {
      // 18/08/2026 = ה׳ אלול תשפ״ו.
      calendarCubit.emit(stateWithToday(DateTime(2026, 8, 18)));

      await tester.pumpWidget(wrap(LibraryDafYomi(onDafYomiTap: (_, _) {})));

      expect(find.textContaining('ה׳ אלול תשפ״ו'), findsOneWidget);
    });

    testWidgets('מעבר יום בלוח מעדכן את הסרגל מיד', (tester) async {
      calendarCubit.emit(stateWithToday(DateTime(2026, 8, 17)));
      await tester.pumpWidget(wrap(LibraryDafYomi(onDafYomiTap: (_, _) {})));
      expect(find.textContaining('ד׳ אלול'), findsOneWidget);

      calendarCubit.emit(stateWithToday(DateTime(2026, 8, 18)));
      await tester.pump();

      expect(find.textContaining('ה׳ אלול'), findsOneWidget);
      expect(find.textContaining('ד׳ אלול'), findsNothing);
    });

    testWidgets('הדף היומי מתחלף יחד עם היום הלוחי', (tester) async {
      calendarCubit.emit(stateWithToday(DateTime(2026, 8, 17)));
      await tester.pumpWidget(wrap(LibraryDafYomi(onDafYomiTap: (_, _) {})));
      final dafBefore = dafText(tester);

      calendarCubit.emit(stateWithToday(DateTime(2026, 8, 18)));
      await tester.pump();

      expect(dafText(tester), isNot(dafBefore));
    });

    testWidgets('הלחיצה פותחת את הדף של היום הלוחי', (tester) async {
      final tapped = <String>[];
      calendarCubit.emit(stateWithToday(DateTime(2026, 8, 17)));
      await tester.pumpWidget(
        wrap(
          LibraryDafYomi(
            onDafYomiTap: (tractate, daf) => tapped.add('$tractate $daf'),
          ),
        ),
      );
      await tester.tap(find.byIcon(OtzariaIcons.book_24_regular));
      await tester.pump();

      calendarCubit.emit(stateWithToday(DateTime(2026, 8, 18)));
      await tester.pump();
      await tester.tap(find.byIcon(OtzariaIcons.book_24_regular));
      await tester.pump();

      expect(tapped.first, isNot(tapped.last));
      expect(tapped.last, dafText(tester));
    });
  });
}
