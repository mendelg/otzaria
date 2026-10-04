import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/book_common/view/commentators_tab_top_bar.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/widgets/controls/bar_button.dart';
import 'package:otzaria/widgets/navigation/responsive_action_bar.dart';

class _SettingsBloc extends Bloc<SettingsEvent, SettingsState>
    implements SettingsBloc {
  _SettingsBloc() : super(SettingsState.initial()) {
    on<SettingsEvent>((event, emit) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('shows the title and runs the screen actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final settings = _SettingsBloc();
    final allExpanded = ValueNotifier(true);
    addTearDown(() async {
      allExpanded.dispose();
      await settings.close();
    });
    final calls = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<SettingsBloc>.value(
          value: settings,
          child: Scaffold(
            body: CommentatorsTabTopBar(
              title: 'מפרשים על בראשית',
              prevMajorTooltip: 'הפרק הקודם',
              nextMajorTooltip: 'הפרק הבא',
              navPaneOpen: false,
              navPanePinned: false,
              onToggleNavPane: () => calls.add('pane'),
              onTogglePin: () => calls.add('pin'),
              onPrevMajor: () => calls.add('prevMajor'),
              onPrevMinor: () => calls.add('prevMinor'),
              onNextMinor: () => calls.add('nextMinor'),
              onNextMajor: () => calls.add('nextMajor'),
              textDisplayAction: ActionButtonData(
                widget: BarButton.icon(
                  tooltip: 'תצוגה',
                  icon: Icons.text_fields,
                  onPressed: () => calls.add('display'),
                ),
                icon: Icons.text_fields,
                tooltip: 'תצוגה',
                actionId: ToolbarActionId.textDisplay,
                onPressed: () => calls.add('display'),
              ),
              onPrint: () => calls.add('print'),
              onSearch: () => calls.add('search'),
              allExpanded: allExpanded,
              onToggleAllExpanded: () => calls.add('expand'),
              onAddBookmark: () => calls.add('bookmark'),
              onZoomIn: () => calls.add('zoomIn'),
              onZoomOut: () => calls.add('zoomOut'),
              onShowBookmarks: () => calls.add('bookmarks'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('מפרשים על בראשית'), findsOneWidget);
    expect(find.byTooltip('הפרק הקודם'), findsOneWidget);
    expect(find.byTooltip('כווץ את כל המפרשים'), findsOneWidget);

    for (final tooltip in [
      'הדפסה',
      'חיפוש',
      'הוסף סימניה',
      'הגדל את גודל הטקסט',
      'הקטן את גודל הטקסט',
      'הפרק הבא',
    ]) {
      await tester.tap(find.byTooltip(tooltip));
    }
    expect(calls, [
      'print',
      'search',
      'bookmark',
      'zoomIn',
      'zoomOut',
      'nextMajor',
    ]);

    allExpanded.value = false;
    await tester.pump();
    expect(find.byTooltip('הרחב את כל המפרשים'), findsOneWidget);
  });
}
