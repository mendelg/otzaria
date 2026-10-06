import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String routine(String script, String signature) {
  final start = script.indexOf(signature);
  expect(start, isNonNegative, reason: signature);
  return script.substring(start, script.indexOf('\nend;', start));
}

void main() {
  final script = File('installer/download_assistant_ui.iss').readAsStringSync();

  test('כל פעולות המסייע הן כפתורי Windows עם שם ומוקד גלוי', () {
    expect(script, contains('Img: TBitmapButton;'));
    final make = routine(script, 'procedure UiMakeButton(');
    expect(make, contains('TBitmapButton.Create(WizardForm)'));
    expect(make, contains('.TabStop := True;'));
    expect(make, contains('.Stretch := False;'));
    final set = routine(script, 'procedure UiSetButton(');
    expect(set, contains('.Img.Caption := Caption;'));
    expect(set, contains('.Img.Enabled := Enabled;'));
    final chrome = routine(script, 'procedure UiBuildChrome()');
    expect(chrome, contains("CustomMessage('Close')"));
    expect(chrome, contains("CustomMessage('Minimize')"));
  });

  test('שוליי המוקד משאירים את bounds וגודל הטקסט המקוריים', () {
    final render = routine(script, 'procedure UiRenderButton(');
    expect(render, contains('UiCanvas(W - 4, H - 4, UiButtons[I].Back)'));
    expect(render, contains('UiDrawButtonArt(Bmp.Canvas, Png, W - 4, H - 4)'));
    expect(render, contains('Bmp.Width, Bmp.Height, 14, True, Color'));
    expect(render, contains('UiButtons[I].Img.Top, W, H)'));
    expect(
      render,
      contains('UiDrawStretch(Bmp.Canvas, 0, 0, W - 4, H - 4, Png)'),
    );
    expect(render, contains('if (W <= 4) or (H <= 4) then'));
  });

  test('Enter מפעיל את הכפתור הגלוי שבמוקד גם בסיום ובדו שיח', () {
    final keys = routine(script, 'procedure UiKeyDown(');
    expect(keys, contains('if Key <> 13 then'));
    expect(keys, contains('.Img.Focused'));
    expect(keys, contains('Key := 0;'));
    expect(keys, contains('UiDialogButtonClick('));
    expect(keys, contains('UiButtonClick('));
    final wizard = routine(script, 'procedure UiInitializeWizard()');
    expect(wizard, contains('WizardForm.KeyPreview := True;'));
    expect(wizard, contains('WizardForm.OnKeyDown := @UiKeyDown;'));
    final ask = routine(script, 'function UiAsk(');
    expect(ask, contains('UiDlg.OnKeyDown := @UiKeyDown;'));
    expect(ask, contains('UiDlg.ActiveControl := UiButtons[UiBtnDlgNo].Img'));
    expect(ask, contains('UiDlg.ActiveControl := UiButtons[UiBtnDlgOk].Img'));
    expect(ask, contains('UiDlgNo.Cancel := True;'));
    expect(ask, contains('UiDlgOk.Default := False;'));
    expect(ask, contains('UiDlgNo.Default := False;'));
    expect(
      routine(script, 'procedure UiHideNativeChrome()'),
      contains('WizardForm.NextButton.Default := False;'),
    );
    final focus = routine(script, 'procedure UiFocusAction()');
    expect(focus, contains('if Assigned(UiDlg)'));
    expect(focus, contains('for I := UiBtnInstall to UiBtnDone'));
    expect(
      focus,
      contains('I := UiBtnStart'),
    );
    expect(
      focus,
      contains('I := UiBtnAbort'),
    );
  });

  test('Tab אינו עובר לכפתורי proxy נסתרים', () {
    final chrome = routine(script, 'procedure UiHideNativeChrome()');
    for (final name in ['NextButton', 'BackButton', 'CancelButton']) {
      expect(chrome, contains('WizardForm.$name.TabStop := False;'));
    }
    final ask = routine(script, 'function UiAsk(');
    for (final name in ['UiDlgOk', 'UiDlgNo']) {
      expect(ask, contains('$name.TabStop := False;'));
    }
    expect(
      routine(script, 'procedure UiBuildFolder()'),
      contains('FolderPage.Buttons[0].TabStop := False;'),
    );
  });

  test('ה-hover של כפתור חלון בודק את HWND שלו ולא רק את ההורה', () {
    final hit = routine(script, 'function UiHitButton(');
    expect(hit, contains('Wnd = Img.Handle'));
    expect(
      routine(script, 'procedure UiPollMouse()'),
      contains('UiHitButton(UiButtons[I].Img, Wnd)'),
    );
  });

  test('קנה המידה מותאם לכל אזורי העבודה גם ברוחב וגם בגובה', () {
    final fit = routine(script, 'function UiMeasureMonitor(');
    expect(fit, contains('UiGetMonitorInfo(Monitor, Info)'));
    expect(fit, contains('Info.Work.Right - Info.Work.Left'));
    expect(fit, contains('Info.Work.Bottom - Info.Work.Top'));
    final scale = routine(script, 'function UiPickScale()');
    expect(
      scale,
      contains(
        'UiEnumDisplayMonitors(0, 0, CreateCallback(@UiMeasureMonitor), 0)',
      ),
    );
    expect(scale, contains('UiWidth * S div 100 <= UiFitWidth'));
    expect(scale, contains('UiHeight * S div 100 <= UiFitHeight'));
    expect(scale, contains('if UiGetWorkArea(48, 0, Area, 0) then'));
    expect(scale, contains('UiFitWidth := Area.Right - Area.Left;'));
    expect(scale, contains('UiFitHeight := Area.Bottom - Area.Top;'));
  });
}
