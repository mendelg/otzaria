import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/text_display/models/text_display_profile.dart';
import 'package:otzaria/text_display/text_display_transforms.dart';
import 'package:otzaria/utils/text/text_manipulation.dart';
import 'package:otzaria/widgets/smart_text/render_settings.dart';
import 'package:otzaria/widgets/smart_text/text_renderer_service.dart';

void main() {
  group('גרשיים בהסרת פיסוק', () {
    const cases = <String, String>{
      '<b>ברמב</b>"<b>ן</b>': '<b>ברמב</b>"<b>ן</b>',
      'רש"י,ובגמ\'': 'רש"יובגמ\'',
      'ב"<b>כ</b><i>י</i> יותן': 'ב<b>כ</b><i>י</i> יותן',
      'ב"<b>כִּ</b><i>י</i> יותן': 'ב<b>כִּ</b><i>י</i> יותן',
      'א</p>"<p>ב': 'א</p><p>ב',
      'א"</div><div>ב': 'א</div><div>ב',
      '<p>א"ב</p><p>ג</p>': '<p>א"ב</p><p>ג</p>',
      'א\n"ב': 'א ב',
      'א"\r\nב': 'א ב',
      'א<br>"ב': 'א ב',
      'א"<BR />ב': 'א ב',
      'א"ב<br>ג': 'א"ב ג',
      'א<small>ַ</small>"<b>בּ</b>': 'א<small>ַ</small>"<b>בּ</b>',
      'א!<b>ַ</b>"<i>ּ</i>,ב': 'א<b>ַ</b>"<i>ּ</i>ב',
      'א"ב־ג': 'א"ב־ג',
      'א־"ב': 'א־ב',
      'א"ב׀ג': 'א"ב׀ג',
      'א׀"ב': 'א׀ב',
      'א"ב&nbsp;ג': 'א"ב&nbsp;ג',
      'א&nbsp;"ב': 'א&nbsp;ב',
      'א"&nbsp;ב': 'א&nbsp;ב',
      'א"&#1489;': 'א"&#1489;',
      '&#1488;"ב': '&#1488;"ב',
      'א"ב&#1490;': 'אב&#1490;',
      'א"ב&#x05B4;ג': 'אב&#x05B4;ג',
      'א&#x05B4;"ב': 'א&#x05B4;"ב',
      'א&quot;ב רש"י': 'א&quot;ב רש"י',
      '"ציטוט" וגם ״ציטוט״': 'ציטוט וגם ציטוט',
      'רש"י רמב״ם U"S ב"כי': 'רש"י רמב״ם U"S בכי',
      'א"ב"ג': 'א"ב"ג',
      'א""ב': 'אב',
      '"א"': 'א',
      '# כותרת: "טקסט"': '# כותרת: "טקסט"',
      '<h2>כותרת: "טקסט"</h2>': '<h2>כותרת: "טקסט"</h2>',
      '<a href="otzaria://inline-link?ref=1-2&amp;x=3">רש</a>"י':
          '<a href="otzaria://inline-link?ref=1-2&amp;x=3">רש</a>"י',
    };
    for (final entry in cases.entries) {
      test(entry.key, () {
        expect(removePunctuation(entry.key), entry.value);
      });
    }

    for (final tag in ['p', 'DIV', 'li', 'td', 'blockquote', 'hr']) {
      test('תג $tag מפריד בכל צד של הגרשיים', () {
        expect(removePunctuation('א</$tag>"ב'), 'א</$tag>ב');
        expect(removePunctuation('א"<$tag class="x">ב'), 'א<$tag class="x">ב');
        expect(removePunctuation('א"ב</$tag>ג'), 'א"ב</$tag>ג');
      });
    }

    for (final punctuation in ['!', ':', ';', '.', ',', '?', '-', '—', '–']) {
      test('פיסוק $punctuation צמוד לגרשיים ואחרי ראשי התיבות', () {
        expect(removePunctuation('א$punctuation"ב'), 'א"ב');
        expect(removePunctuation('א"$punctuationב'), 'א"ב');
        expect(removePunctuation('א"ב$punctuationגד'), 'א"בגד');
      });
    }

    test('תצוגה והעתקה משתמשות באותה הכרעה עם ניקוד ובלעדיו', () {
      const input = '<b>רַש</b>"<b>י</b>, ב"<i>כִּ</i>י';
      for (final removeNikud in [false, true]) {
        final expected = removeNikud
            ? '<b>רש</b>"<b>י</b> ב<i>כ</i>י'
            : '<b>רַש</b>"<b>י</b> ב<i>כִּ</i>י';
        expect(
          TextRendererService.processText(
            input,
            RenderSettings(removePunctuation: true, removeNikud: removeNikud),
          ),
          expected,
        );
        expect(
          applyTextDisplayProfile(
            input,
            TextDisplayProfile(
              punctuation: MarkVisibility.hide,
              nikud: removeNikud ? MarkVisibility.hide : MarkVisibility.show,
            ),
          ),
          expected,
        );
      }
    });

    test('שורה גדולה עם גרשיים ותגים נשארת מעשית לעיבוד', () {
      const unit = '<b>רש</b>"<b>י</b>, ב"<i>כ</i>י ';
      const expectedUnit = '<b>רש</b>"<b>י</b> ב<i>כ</i>י ';
      final input = unit * 10000;
      removePunctuation(unit * 100);
      final watch = Stopwatch()..start();
      final result = removePunctuation(input);
      watch.stop();
      expect(result, expectedUnit * 10000);
      // הסף נדיב למכונות CI; סריקה ריבועית של מאות אלפי תווים חורגת ממנו.
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    });
  });
}
