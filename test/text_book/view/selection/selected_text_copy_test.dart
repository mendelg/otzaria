import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/book_common/selection/selected_text_restore.dart';
import 'package:otzaria/book_common/utils/link_anchor_markers.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_book/view/selection/selected_text_copy.dart';
import 'package:otzaria/text_display/text_display_exports.dart';
import 'package:otzaria/widgets/smart_text/render_settings.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  group('resolveHtmlTextForSelection', () {
    test('מחזיר HTML מקורי כשהבחירה מכסה את כל השורה', () {
      final resolved = resolveHtmlTextForSelection(
        plainText: 'שלום עולם',
        selectedIndex: 0,
        sourceContent: const ['<b>שלום</b> עולם'],
      );

      expect(resolved, '<b>שלום</b> עולם');
    });

    test('מחזיר HTML חתוך כשהבחירה היא רק חלק מהשורה', () {
      final resolved = resolveHtmlTextForSelection(
        plainText: 'שלום',
        selectedIndex: 0,
        sourceContent: const ['<b>שלום</b> עולם'],
      );

      expect(resolved, '<b>שלום</b>');
    });

    test('שומר עיצוב גם בבחירה שחוצה תגית', () {
      final resolved = resolveHtmlTextForSelection(
        plainText: 'לום עו',
        selectedIndex: 0,
        sourceContent: const ['<b>שלום</b> עולם'],
      );

      expect(resolved, '<b>לום</b> עו');
    });

    test('נופל לטקסט פשוט כשהבחירה אינה נמצאת בשורה', () {
      final resolved = resolveHtmlTextForSelection(
        plainText: 'טקסט משורה אחרת',
        selectedIndex: 0,
        sourceContent: const ['<b>שלום</b> עולם'],
      );

      expect(resolved, 'טקסט משורה אחרת');
    });

    test('מחזיר fallback לטקסט פשוט כשאין אינדקס תקין', () {
      final resolved = resolveHtmlTextForSelection(
        plainText: 'שלום',
        selectedIndex: null,
        sourceContent: const ['<b>שלום</b> עולם'],
      );

      expect(resolved, 'שלום');
    });
  });

  group('העתקת בחירה לפי ערוץ ההעתקה (#1859)', () {
    final link = Link(
      heRef: 'מפרש בדיקה א, ב',
      index1: 1,
      path2: 'מפרש בדיקה',
      index2: 1,
      connectionType: 'commentary',
      anchorStart: 7,
      anchorLabel: 'ב',
    );
    final marker = anchorMarkerText(link)!;

    Future<String> copyOfSelection({
      required String line,
      required String Function(String shownLine) select,
      TextDisplayPatch copy = const TextDisplayPatch(),
    }) async {
      final state = _state(line, link, copy);
      final shown = renderSelectionLineWithMarkers(
        rawText: injectLinkAnchorMarkers(
          rawLine: line,
          anchorLinks: [link],
          styleIndexByCommentator: anchorStyleIndexByCommentator([link]),
          lineIndex: 0,
        ),
        settings: const RenderSettings(),
      );
      final selected = select(shown.text);
      final copied = await buildSelectedTextCopy(
        plainText: selected,
        selectedIndex: 0,
        sourceContent: [line],
        textBookState: state,
        settingsState: SettingsState.initial(),
        copyTarget: TextTarget.body,
        source: SourceSelection.strip(
          shownText: selected,
          lines: [shown],
          startColumn: shown.text.indexOf(selected),
        ),
      );
      return copied!.plainText;
    }

    String rabbiYochanan(String shown) =>
        shown.substring(shown.indexOf('רבי'), shown.indexOf('יוחנן') + 5);

    test('ערוץ ההעתקה מסתיר ציונים — הציון שנבחר אינו מועתק', () async {
      expect(
        await copyOfSelection(
          line: 'אמר רבי יוחנן הלכה',
          select: rabbiYochanan,
          copy: const TextDisplayPatch(anchorMarkers: MarkVisibility.hide),
        ),
        'רבי יוחנן',
      );
    });

    test('ערוץ ההעתקה כמו התצוגה — הציון מועתק כפי שהוא מוצג', () async {
      expect(
        await copyOfSelection(
          line: 'אמר רבי יוחנן הלכה',
          select: rabbiYochanan,
        ),
        'רבי$marker יוחנן',
      );
    });

    test('טקסט זהה לציון שמודפס בספר עצמו נשמר', () async {
      expect(
        await copyOfSelection(
          line: 'אמר רבי יוחנן $marker הלכה',
          select: (shown) => shown.substring(shown.indexOf('רבי')),
          copy: const TextDisplayPatch(anchorMarkers: MarkVisibility.hide),
        ),
        'רבי יוחנן $marker הלכה',
      );
    });

    test('Ctrl+C מסיר ניקוד ופיסוק כשערוץ ההעתקה מסתיר אותם', () async {
      const line = 'אָמַר, רַבִּי יוֹחָנָן.';
      final copied = await buildSelectedTextCopy(
        plainText: line,
        selectedIndex: 0,
        sourceContent: const [line],
        textBookState: _state(
          line,
          link,
          const TextDisplayPatch(
            nikud: MarkVisibility.hide,
            punctuation: MarkVisibility.hide,
          ),
        ),
        settingsState: SettingsState.initial(),
        copyTarget: TextTarget.body,
      );
      expect(copied!.plainText, 'אמר רבי יוחנן.');
    });

    test('"העתק בלי ניקוד" מסיר ניקוד גם כשערוץ ההעתקה מציג אותו', () async {
      const line = 'אָמַר רַבִּי';
      final copied = await buildSelectedTextCopy(
        plainText: line,
        selectedIndex: 0,
        sourceContent: const [line],
        textBookState: _state(line, link, const TextDisplayPatch()),
        settingsState: SettingsState.initial(),
        copyTarget: TextTarget.body,
        removeNikud: true,
      );
      expect(copied!.plainText, 'אמר רבי');
    });

    test('בחירה של הציון בלבד אינה דורסת את הלוח בריק', () async {
      const line = 'אמר רבי יוחנן הלכה';
      final shown = renderSelectionLineWithMarkers(
        rawText: injectLinkAnchorMarkers(
          rawLine: line,
          anchorLinks: [link],
          styleIndexByCommentator: anchorStyleIndexByCommentator([link]),
        ),
        settings: const RenderSettings(),
      );
      final copied = await buildSelectedTextCopy(
        plainText: marker,
        selectedIndex: 0,
        sourceContent: const [line],
        textBookState: _state(
          line,
          link,
          const TextDisplayPatch(anchorMarkers: MarkVisibility.hide),
        ),
        settingsState: SettingsState.initial(),
        copyTarget: TextTarget.body,
        source: SourceSelection.strip(
          shownText: marker,
          lines: [shown],
          startColumn: shown.text.indexOf(marker),
        ),
      );
      expect(copied, isNull);
    });
  });
}

TextBookLoaded _state(String line, Link link, TextDisplayPatch copy) {
  return TextBookLoaded(
    book: TextBook(title: 'ספר בדיקה'),
    showLeftPane: false,
    content: [line],
    fontSize: 18,
    showSplitView: false,
    showPageShapeView: false,
    activeCommentators: const [],
    commentatorGroups: const [],
    availableCommentators: const [],
    links: [link],
    linksByLine: {
      1: [link],
    },
    tableOfContents: const [],
    removeNikud: false,
    visibleIndices: const [0],
    selectedIndex: 0,
    pinLeftPane: false,
    searchText: '',
    scrollController: ItemScrollController(),
    positionsListener: ItemPositionsListener.create(),
    displayPolicy: TextDisplayPolicy.empty.merged(
      TextDisplayBookClass.general,
      const TextDisplaySlot(
        target: TextTarget.body,
        view: TextView.regular,
        channel: TextChannel.copy,
      ),
      copy,
    ),
  );
}
