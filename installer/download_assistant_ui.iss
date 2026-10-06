{ שכבת התצוגה של המסייע: חלון בלי מסגרת, פתיחה מונפשת, כרטיסים וכפתורים מצוירים.
  העמודים של download_assistant.iss הם מודל הנתונים, ואין כאן אף כלל בחירה. }

[Files]
; הערות ';' תקפות רק מחוץ ל-[Code], ולכן גם ה-.isi נכלל כאן ולא בראש הקובץ.
#if VER < EncodeVer(6, 7, 1)
  #error "מסייע ההורדה דורש Inno Setup 6.7.1 ומעלה (Requires Inno Setup 6.7.1 or newer)"
#endif
#define AssistantArtIsi AddBackslash(SourcePath) + "assistant_art\assistant_art.isi"
#if !FileExists(AssistantArtIsi)
  #error "חסר עיצוב המסייע ב-installer\assistant_art. יש למשוך אותו לפני הבנייה (Assistant art missing: fetch installer\assistant_art before compiling)"
#endif
#include AssistantArtIsi
#ifndef AA_TITLE_BAR_H
  #define AA_TITLE_BAR_H AA_CAP_H
#endif
#if AA_SCALES != "100,125,150,175,200,250"
  #error "רשימת קני המידה של העיצוב השתנתה: יש לעדכן את [Files] (Art scales changed: update [Files])"
#endif
#ifndef AA_BOOK_SRC_SCALE
  #error "עיצוב המסייע ישן: נדרשת גרסה 1.2.0 ומעלה (Assistant art too old: 1.2.0 or newer required)"
#endif
#if Pos(",preset_full_indexed,", "," + AA_ICON_NAMES + ",") == 0
  #error "עיצוב המסייע ישן: נדרשת גרסה 1.4.0 ומעלה (Assistant art too old: 1.4.0 or newer required)"
#endif

; התמונות נשלפות לתיקייה הזמנית בזמן ריצה בלבד; שום דבר אינו מותקן.
; הספר והכותרת נשמרים רק בקנה המידה הגדול, ו-Stretch מקטין אותם לכל קנה מידה אחר.
Source: "assistant_art\book_*_{#AA_BOOK_SRC_SCALE}.png"; Flags: dontcopy nocompression
Source: "assistant_art\title_*_{#AA_TITLE_SRC_SCALE}.png"; Flags: dontcopy nocompression
; כל קנה מידה ברצף משלו, כדי ששליפה תקרא רק את הקבצים של קנה המידה שנבחר.
Source: "assistant_art\*_100.png"; Excludes: "book_*,title_*"; Flags: dontcopy nocompression
Source: "assistant_art\*_125.png"; Excludes: "book_*,title_*"; Flags: dontcopy nocompression
Source: "assistant_art\*_150.png"; Excludes: "book_*,title_*"; Flags: dontcopy nocompression
Source: "assistant_art\*_175.png"; Excludes: "book_*,title_*"; Flags: dontcopy nocompression
Source: "assistant_art\*_200.png"; Excludes: "book_*,title_*"; Flags: dontcopy nocompression
Source: "assistant_art\*_250.png"; Excludes: "book_*,title_*"; Flags: dontcopy nocompression

; הטקסטים של שכבת התצוגה; הטקסטים של הלוגיקה ב-[CustomMessages] של download_assistant.iss.
[CustomMessages]
english.CardSize=Download size: %1
english.RowVersion=Version
english.RowWhat=What to download
english.RowFor=For
english.RowSavedIn=Saved in
english.RowFile=File
english.RowFolder=In folder
english.ConnectingProgress=Connecting to the Otzaria website…
english.StepOf=Step %1 of %2
english.StartButton=Let's Get Started
english.InstallNow=Install Now on This Computer
english.OpenFolder=Open the Installation Folder
english.Close=Close
english.OK=OK
english.ExitYes=Exit
english.ExitNo=Continue
english.TechDetails=Technical details
english.Resume=Continue
english.Retry=Try Again
english.OpenDownloads=Open the Downloads Page
english.ConnectStopTitle=Stop connecting?
english.ConnectStopText=You can start again whenever you like.
english.ConnectStopYes=Stop
english.ConnectStopNo=Keep Connecting
english.StopTitle=Stop the download?
english.StopText=Files that were already downloaded will be kept, and running the assistant again continues from the same point.
english.StopYes=Stop
english.StopNo=Keep Downloading
english.InstallFailedTitle=Couldn't start the installer
english.InstallFailedText=You can run it yourself from the folder:%n%1

hebrew.CardSize=גודל ההורדה: %1
hebrew.RowVersion=גרסה
hebrew.RowWhat=מה יורד
hebrew.RowFor=עבור
hebrew.RowSavedIn=נשמר בתיקייה
hebrew.RowFile=הקובץ
hebrew.RowFolder=בתיקייה
hebrew.ConnectingProgress=מתחבר לאתר אוצריא…
hebrew.StepOf=שלב %1 מתוך %2
hebrew.StartButton=בואו נתחיל
hebrew.InstallNow=התקן עכשיו במחשב הזה
hebrew.OpenFolder=פתח את תיקיית ההתקנה
hebrew.Close=סגור
hebrew.OK=אישור
hebrew.ExitYes=יציאה
hebrew.ExitNo=המשך
hebrew.TechDetails=פרטים טכניים
hebrew.Resume=המשך
hebrew.Retry=נסה שוב
hebrew.OpenDownloads=פתח את עמוד ההורדות
hebrew.ConnectStopTitle=להפסיק את ההתחברות?
hebrew.ConnectStopText=אפשר להתחיל שוב מתי שתרצה.
hebrew.ConnectStopYes=הפסק
hebrew.ConnectStopNo=המשך להתחבר
hebrew.StopTitle=לעצור את ההורדה?
hebrew.StopText=קבצים שכבר ירדו יישמרו, והפעלה חוזרת תמשיך מאותו מקום.
hebrew.StopYes=עצור
hebrew.StopNo=המשך להוריד
hebrew.InstallFailedTitle=לא ניתן היה להפעיל את המתקין
hebrew.InstallFailedText=אפשר להפעיל אותו ידנית מתוך התיקייה:%n%1

[Code]
const
  UiPageColor = {#AA_CLR_PAGE};
  UiBarColor = {#AA_CLR_TITLE_BAR};
  UiBarBorderColor = {#AA_CLR_TITLE_BAR_BORDER};
  UiCardColor = {#AA_CLR_CARD};
  UiDividerColor = {#AA_CLR_DIVIDER};
  UiThumbColor = {#AA_CLR_DIVIDER};
  UiTextColor = {#AA_CLR_TEXT};
  UiSecondaryColor = {#AA_CLR_MUTED};
  UiFaintColor = {#AA_CLR_FAINT};
  UiPrimaryColor = {#AA_CLR_PRIMARY};
  UiOnPrimaryColor = {#AA_CLR_ON_PRIMARY};
  UiOnTonalColor = {#AA_CLR_ON_TONAL};
  UiDisabledTextColor = {#AA_CLR_DISABLED_TEXT};
  UiFieldColor = {#AA_CLR_FIELD};
  UiErrorColor = {#AA_CLR_ERROR};
  { barrierColor של הדו-שיח בתוכנה: שחור ב-13.3%. }
  UiShadeAlpha = 34;

  UiWidth = 400;
  UiHeight = 660;
  UiBarH = {#AA_TITLE_BAR_H};
  { רצועת נקודות השלבים שמעל כל עמוד פנימי. }
  UiStepsH = 44;
  UiFooterTop = 592;
  { תחתית כפתורי הכותרת התחתונה: גם ערימת הכפתורים בעמודי התוצאה והפתיחה נגמרת כאן. }
  UiActionsBottom = UiFooterTop + (UiHeight - UiFooterTop + {#AA_BTN_PRIMARY_H}) div 2;
  UiStackGap = 8;
  UiBadgeTop = 72;
  UiMargin = 24;
  UiContentW = {#AA_CARD_W};
  UiCardGap = 10;
  UiToggle = {#AA_TOGGLE_SIZE};
  UiIcon = {#AA_ICON_SIZE};
  UiCardShadow = {#AA_CARD_SHADOW};
  UiTickMs = 20;
  { בזמן הפתיחה בלבד: הטיימר יורה בכל פעימת מערכת (15.6ms), ופריים של 42ms מתחלף אחרי 31
    או 47ms. ב-UiTickMs הפעימה היא 31ms, והפריים מתחלף אחרי 31 או 63. }
  UiHeroTickMs = 10;
  { הספר הסגור נחשף בדהייה, בזמן שהפריימים הבאים עוד נפרסים. }
  UiHeroFadeMs = 250;
  UiRiseStart = {#AA_RISE_START_FRAME} * {#AA_BOOK_FRAME_MS};
  UiRiseEnd = UiRiseStart + {#AA_RISE_MS};
  UiTitleEnd = UiRiseEnd + {#AA_TITLE_FADE_MS};

  UiWmCommand = $0111;
  UiWmSysCommand = $0112;
  UiWmMouseWheel = $020A;
  UiWmLButtonDown = $0201;
  UiScMinimize = $F020;
  UiScClose = $F060;
  UiScDragMove = $F012;

  DT_LEFT = $0;
  DT_CENTER = $1;
  DT_RIGHT = $2;
  DT_VCENTER = $4;
  DT_WORDBREAK = $10;
  DT_SINGLELINE = $20;
  DT_CALCRECT = $400;
  DT_NOPREFIX = $800;
  DT_EDITCONTROL = $2000;
  DT_PATH_ELLIPSIS = $4000;
  DT_END_ELLIPSIS = $8000;
  DT_RTLREADING = $20000;

  { סוגי הכפתורים המצוירים, לפי סדרם ב-UiButtons. }
  UiBtnNext = 0;
  UiBtnBack = 1;
  UiBtnAbort = 2;
  UiBtnStart = 3;
  UiBtnBrowse = 4;
  UiBtnClose = 5;
  UiBtnMin = 6;
  UiBtnRetry = 7;
  UiBtnOpenPage = 8;
  UiBtnQuit = 9;
  UiBtnDlgOk = 10;
  UiBtnDlgNo = 11;
  UiBtnInstall = 12;
  UiBtnOpenFolder = 13;
  UiBtnDone = 14;
  UiBtnCount = 15;

  UiSrcNone = 0;
  UiSrcDownload = 1;
  UiSrcWork = 2;
  UiSrcInstalling = 3;
  UiSrcConnect = 4;

type
  TUiPoint = record
    X, Y: Longint;
  end;

  TUiRect = record
    Left, Top, Right, Bottom: Longint;
  end;

  TUiMonitorInfo = record
    Size: LongWord;
    Monitor, Work: TUiRect;
    Flags: LongWord;
  end;

  TUiMouseHookInfo = record
    X, Y: Longint;
    Wnd: Longint;
    HitTest: Longint;
    ExtraInfo: Longint;
    MouseData: Longint;
  end;

  TUiButton = record
    Img: TBitmapImage;
    Art: String;
    Caption: String;
    Shown, Enabled, Hover, Down: Boolean;
    Drawn: String;
    { רוחב שאינו רוחב התמונה: הקצוות המעוגלים נשמרים והאמצע נמתח. }
    Width: Integer;
    Back: TColor;
    Danger: Boolean;
  end;

  TUiCard = record
    Img: TBitmapImage;
    Title, Desc, Side, Icon: String;
    Check: Boolean;
    Top, Height: Integer;
    Hover, Sel: Boolean;
    Drawn: String;
  end;

  TUiRow = record
    Icon, Caption, Value: String;
    Ltr: Boolean;
  end;

  TUiBitmapInfo = record
    Size: LongWord;
    Width, Height: Longint;
    Planes, BitCount: Word;
    Compression, SizeImage: LongWord;
    XPerMeter, YPerMeter: Longint;
    ClrUsed, ClrImportant: LongWord;
  end;

var
  UiScale: Integer;
  { עברית: הפריסה כפי שהיא כתובה. אנגלית: כל מיקום אופקי משוקף ב-UiX. }
  UiRtl: Boolean;
  UiTitleArt: String;
  UiReady: Boolean;
  UiFailed: Boolean;
  UiInTick: Boolean;
  UiTimerId, UiTickProc: LongWord;
  UiTickRate: Integer;
  UiHook: LongWord;
  UiPage: Integer;
  UiArtNames: TStringList;
  UiMeasure: TBitmap;

  UiTitleBar, UiFooter, UiHost, UiContent, UiThumb: TPanel;
  UiTitleLabel: TNewStaticText;
  UiButtons: array of TUiButton;
  UiStepImg: TBitmapImage;
  UiStepLabel: TNewStaticText;
  UiStepDrawn: String;
  UiHdrTitle, UiHdrDesc, UiHdrHint: TNewStaticText;

  UiCards: array of TUiCard;
  UiCardsPage: TInputOptionWizardPage;
  UiContentH, UiScrollY, UiScrollTarget: Integer;
  UiThumbDrag: Boolean;
  UiThumbGrabY, UiThumbGrabScroll: Integer;

  UiFolderField: TBitmapImage;
  UiFolderFocused: Integer;
  UiRows: array of TUiRow;

  UiReveal: TUiCard;
  UiBadge, UiResultImg: TBitmapImage;
  UiFinishTitle: TNewStaticText;

  UiProgSource: Integer;
  UiProgCaption, UiProgPercent, UiProgSpeed, UiProgBytes: TNewStaticText;
  UiProgBar: TBitmapImage;
  UiProgDrawn: String;

  UiCounterFreq: Int64;

  UiHeroBook, UiHeroTitle, UiHeroVeil: TBitmapImage;
  UiHeroNote: TNewStaticText;
  { פריימי הספר ואחריהם שלבי הכותרת; nil עד הפענוח, ושוב אחרי שהוצגו. }
  UiHeroArt: array of TBitmap;
  UiHeroDone, UiHeroHeld: Boolean;
  UiHeroFrame, UiHeroTitleStep, UiHeroNext, UiHeroFade, UiHeroT: Integer;
  UiHeroLast, UiHeroDecodeMax, UiHeroFrameCost: Extended;

  UiDlg, UiShade: TSetupForm;
  UiDlgOk, UiDlgNo: TNewButton;
  UiFrame: array of TPanel;
  UiClosing: Boolean;
  UiErrPanel: TPanel;
  UiErrBadge: TBitmapImage;
  UiErrTitle, UiErrBody, UiErrLink: TNewStaticText;
  UiErrTech: TRichEditViewer;

function UiGetCursorPos(var P: TUiPoint): BOOL;
  external 'GetCursorPos@user32.dll stdcall';
function UiScreenToClient(Wnd: Longint; var P: TUiPoint): BOOL;
  external 'ScreenToClient@user32.dll stdcall';
function UiWindowFromPoint(X, Y: Longint): Longint;
  external 'WindowFromPoint@user32.dll stdcall';
function UiGetAsyncKeyState(Key: Integer): Integer;
  external 'GetAsyncKeyState@user32.dll stdcall';
function UiReleaseCapture(): BOOL;
  external 'ReleaseCapture@user32.dll stdcall';
function UiGetForegroundWindow(): Longint;
  external 'GetForegroundWindow@user32.dll stdcall';
function UiIsWindowEnabled(Wnd: Longint): Integer;
  external 'IsWindowEnabled@user32.dll stdcall';
function UiSetTimer(Wnd: Longint; IdEvent, Elapse, TimerFunc: LongWord): LongWord;
  external 'SetTimer@user32.dll stdcall';
function UiKillTimer(Wnd: Longint; IdEvent: LongWord): BOOL;
  external 'KillTimer@user32.dll stdcall';
function UiGetClassLong(Wnd: Longint; Index: Integer): LongWord;
  external 'GetClassLongW@user32.dll stdcall';
function UiSetClassLong(Wnd: Longint; Index: Integer; Value: LongWord): LongWord;
  external 'SetClassLongW@user32.dll stdcall';
function UiGetWindowLong(Wnd: Longint; Index: Integer): LongWord;
  external 'GetWindowLongW@user32.dll stdcall';
function UiSetWindowLong(Wnd: Longint; Index: Integer; Value: LongWord): LongWord;
  external 'SetWindowLongW@user32.dll stdcall';
function UiDwmSetWindowAttribute(Wnd: Longint; Attr: LongWord; var Value: Integer;
  Size: LongWord): Integer;
  external 'DwmSetWindowAttribute@dwmapi.dll stdcall delayload';
function UiDrawText(DC: Longint; Text: String; Count: Integer; var R: TUiRect;
  Format: LongWord): Integer;
  external 'DrawTextW@user32.dll stdcall';
function UiGetDC(Wnd: Longint): Longint;
  external 'GetDC@user32.dll stdcall';
function UiReleaseDC(Wnd: Longint; DC: Longint): Integer;
  external 'ReleaseDC@user32.dll stdcall';
function UiGetDeviceCaps(DC: Longint; Index: Integer): Integer;
  external 'GetDeviceCaps@gdi32.dll stdcall';
function UiGetSpiBool(Action, Param: LongWord; var Value: Integer; WinIni: LongWord): BOOL;
  external 'SystemParametersInfoW@user32.dll stdcall';
function UiGetWorkArea(Action, Param: LongWord; var R: TUiRect; WinIni: LongWord): BOOL;
  external 'SystemParametersInfoW@user32.dll stdcall';
function UiSetWindowsHookEx(IdHook: Integer; Fn: LongWord; Module: LongWord;
  ThreadId: LongWord): LongWord;
  external 'SetWindowsHookExW@user32.dll stdcall';
function UiCallNextHookEx(Hook: LongWord; Code: Integer; WParam, LParam: LongWord): LongWord;
  external 'CallNextHookEx@user32.dll stdcall';
function UiUnhookWindowsHookEx(Hook: LongWord): BOOL;
  external 'UnhookWindowsHookEx@user32.dll stdcall';
function UiGetCurrentThreadId(): LongWord;
  external 'GetCurrentThreadId@kernel32.dll stdcall';
function UiAlphaBlend(Dest: Longint; DX, DY, DW, DH: Integer; Src: Longint;
  SX, SY, SW, SH: Integer; Blend: LongWord): BOOL;
  external 'AlphaBlend@msimg32.dll stdcall';
function UiBitBlt(Dest: Longint; DX, DY, DW, DH: Integer; Src: Longint; SX, SY: Integer;
  Rop: LongWord): BOOL;
  external 'BitBlt@gdi32.dll stdcall';
function UiSetLayeredWindowAttributes(Wnd: Longint; Key, Alpha, Flags: LongWord): BOOL;
  external 'SetLayeredWindowAttributes@user32.dll stdcall';
procedure UiReadHookInfo(var Dest: TUiMouseHookInfo; Src: LongWord; Len: LongWord);
  external 'RtlMoveMemory@kernel32.dll stdcall';
function UiIsIconic(Wnd: Longint): BOOL;
  external 'IsIconic@user32.dll stdcall';
function UiIsWindowVisible(Wnd: Longint): BOOL;
  external 'IsWindowVisible@user32.dll stdcall';
function UiGetWindowRect(Wnd: Longint; var R: TUiRect): BOOL;
  external 'GetWindowRect@user32.dll stdcall';
function UiMonitorFromWindow(Wnd: Longint; Flags: LongWord): Longint;
  external 'MonitorFromWindow@user32.dll stdcall';
function UiGetMonitorInfo(Monitor: Longint; var Info: TUiMonitorInfo): BOOL;
  external 'GetMonitorInfoW@user32.dll stdcall';
function UiSetWindowPos(Wnd, After: Longint; X, Y, W, H: Integer; Flags: LongWord): BOOL;
  external 'SetWindowPos@user32.dll stdcall';
function UiCreateRoundRectRgn(X1, Y1, X2, Y2, W, H: Integer): Longint;
  external 'CreateRoundRectRgn@gdi32.dll stdcall';
function UiSetWindowRgn(Wnd, Rgn: Longint; Redraw: BOOL): Integer;
  external 'SetWindowRgn@user32.dll stdcall';
function UiRedrawWindow(Wnd, Rect, Rgn: Longint; Flags: LongWord): BOOL;
  external 'RedrawWindow@user32.dll stdcall';
function UiQueryCounter(var Count: Int64): BOOL;
  external 'QueryPerformanceCounter@kernel32.dll stdcall';
function UiQueryFrequency(var Freq: Int64): BOOL;
  external 'QueryPerformanceFrequency@kernel32.dll stdcall';
function UiCreateDibSection(DC: Longint; var Info: TUiBitmapInfo; Usage: LongWord;
  var Bits: LongWord; Section: Longint; Offset: LongWord): Longint;
  external 'CreateDIBSection@gdi32.dll stdcall';
procedure UiWriteMemory(Dest: LongWord; var Src: LongWord; Len: LongWord);
  external 'RtlMoveMemory@kernel32.dll stdcall';

{ ============================ יסודות ============================ }

function Px(V: Integer): Integer;
begin
  Result := (V * UiScale + 50) div 100;
end;

{ X של פריט ברוחב W בתוך Total, כפי שהוא ממוקם בעברית; באנגלית — מהצד השני. }
function UiX(X, W, Total: Integer): Integer;
begin
  if UiRtl then
    Result := X
  else
    Result := Total - X - W;
end;

function UiAlign(): LongWord;
begin
  if UiRtl then
    Result := DT_RIGHT
  else
    Result := DT_LEFT;
end;

{ קנה המידה של התמונות לפי ה-DPI, כך שכל תמונה מוצגת פיקסל-לפיקסל. מסך נמוך
  מגודל החלון מקבל קנה מידה קטן יותר, ולא חלון שנחתך. }
function UiPickScale(): Integer;
var
  DC, Dpi: Integer;
  Area: TUiRect;
  Scales: TArrayOfString;
  I, S, Fit: Integer;
begin
  DC := UiGetDC(0);
  Dpi := UiGetDeviceCaps(DC, 88);
  UiReleaseDC(0, DC);
  Fit := 100000;
  if UiGetWorkArea(48, 0, Area, 0) then
    Fit := Area.Bottom - Area.Top;
  Result := 100;
  Scales := StringSplitEx('{#AA_SCALES}', [','], #0, stExcludeEmpty);
  for I := 0 to GetArrayLength(Scales) - 1 do
  begin
    S := StrToIntDef(Scales[I], 0);
    if (S > Result) and (S * 96 <= Dpi * 100 + 300) and
       (UiHeight * S div 100 <= Fit) then
      Result := S;
  end;
end;

function UiAnimationsEnabled(): Boolean;
var
  Value: Integer;
begin
  Value := 1;
  if not UiGetSpiBool($1042, 0, Value, 0) then
    Value := 1;
  Result := Value <> 0;
end;

function UiNowMs(): Extended;
var
  Count: Int64;
  C, F: Extended;
begin
  if UiCounterFreq = 0 then
    UiQueryFrequency(UiCounterFreq);
  UiQueryCounter(Count);
  C := Count;
  F := UiCounterFreq;
  Result := C * 1000 / F;
end;

{ מפת סיביות עם אלפא מוכפל, כפי ש-AlphaBlend דורש. תמונה חסרה נטענת ריקה: העמוד
  מצטייר בלעדיה, והאשף נשאר שמיש. }
function UiLoadArt(const Name: String; Scale: Integer): TBitmap;
var
  Png: TPngImage;
  FileName: String;
begin
  Result := TBitmap.Create;
  Png := TPngImage.Create;
  try
    try
      FileName := Name + '_' + IntToStr(Scale) + '.png';
      { הספר והכותרת אינם נשלפים בפעימה הראשונה, אלא כל תמונה כשמגיע תורה. }
      if not FileExists(ExpandConstant('{tmp}\') + FileName) then
        ExtractTemporaryFile(FileName);
      Png.LoadFromFile(ExpandConstant('{tmp}\') + FileName);
      Result.Assign(Png);
      if Result.AlphaFormat = afDefined then
        Result.AlphaFormat := afPremultiplied;
    except
      Log('DownloadAssistant UI: missing art ' + Name);
    end;
  finally
    Png.Free;
  end;
end;

function UiArt(const Name: String): TBitmap;
var
  I: Integer;
begin
  I := UiArtNames.IndexOf(Name);
  if I >= 0 then
  begin
    Result := TBitmap(UiArtNames.Objects[I]);
    exit;
  end;
  Result := UiLoadArt(Name, UiScale);
  I := UiArtNames.Add(Name);
  UiArtNames.Objects[I] := Result;
end;

procedure UiDraw(C: TCanvas; X, Y: Integer; Art: TBitmap);
begin
  if (Art.Width <= 0) or (Art.Height <= 0) then
    exit;
  if Art.AlphaFormat = afIgnored then
    UiBitBlt(C.Handle, X, Y, Art.Width, Art.Height, Art.Canvas.Handle, 0, 0, $00CC0020)
  else
    UiAlphaBlend(C.Handle, X, Y, Art.Width, Art.Height, Art.Canvas.Handle, 0, 0,
      Art.Width, Art.Height, $01FF0000);
end;

function UiStrip(const S: String): String;
begin
  Result := S;
  StringChangeEx(Result, '&', '', True);
  StringChangeEx(Result, '<', '', True);
  StringChangeEx(Result, '>', '', True);
  Result := Trim(Result);
end;

function UiHasHebrew(const S: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to Length(S) do
    if (Ord(S[I]) >= $0590) and (Ord(S[I]) <= $05FF) then
    begin
      Result := True;
      exit;
    end;
end;

function UiPanel(Parent: TWinControl; Color: TColor): TPanel;
begin
  Result := TPanel.Create(WizardForm);
  Result.Parent := Parent;
  Result.BevelOuter := bvNone;
  Result.BevelInner := bvNone;
  Result.Caption := '';
  Result.ParentBackground := False;
  Result.Color := Color;
end;

function UiLabel(Parent: TWinControl; Size: Integer; Bold: Boolean; Color: TColor;
  Align: TAlignment): TNewStaticText;
begin
  Result := TNewStaticText.Create(WizardForm);
  Result.Parent := Parent;
  Result.AutoSize := False;
  Result.WordWrap := True;
  Result.ShowAccelChar := False;
  Result.Alignment := Align;
  if Bold then
    Result.Font.Name := 'Segoe UI Semibold'
  else
    Result.Font.Name := 'Segoe UI';
  Result.Font.Height := -Px(Size);
  Result.Font.Color := Color;
end;

{ גובה לפי הטקסט ברוחב הנתון; מחזיר את התחתית. }
function UiPlaceLabel(L: TNewStaticText; const Caption: String; X, Y, W: Integer): Integer;
begin
  L.SetBounds(X, Y, W, Px(10));
  L.Caption := Caption;
  if Caption = '' then
  begin
    L.Visible := False;
    Result := Y;
    exit;
  end;
  L.AdjustHeight;
  L.Visible := True;
  Result := Y + L.Height;
end;

function UiImage(Parent: TWinControl): TBitmapImage;
begin
  Result := TBitmapImage.Create(WizardForm);
  Result.Parent := Parent;
  Result.BackColor := clNone;
end;

{ ============================ ציור ============================ }

function UiCanvas(W, H: Integer; Back: TColor): TBitmap;
begin
  Result := TBitmap.Create;
  Result.AlphaFormat := afIgnored;
  Result.Width := W;
  Result.Height := H;
  Result.Canvas.Brush.Style := bsSolid;
  Result.Canvas.Brush.Color := Back;
  Result.Canvas.Pen.Style := psClear;
  Result.Canvas.Rectangle(0, 0, W + 1, H + 1);
end;

procedure UiFill(C: TCanvas; X, Y, W, H: Integer; Color: TColor);
begin
  C.Brush.Style := bsSolid;
  C.Brush.Color := Color;
  C.Pen.Style := psClear;
  C.Rectangle(X, Y, X + W + 1, Y + H + 1);
end;

procedure UiSetFont(C: TCanvas; Size: Integer; Bold: Boolean; Color: TColor);
begin
  if Bold then
    C.Font.Name := 'Segoe UI Semibold'
  else
    C.Font.Name := 'Segoe UI';
  C.Font.Style := [];
  C.Font.Height := -Px(Size);
  C.Font.Color := Color;
end;

{ RLM אחרי כל פסיק במשפט עברי: בלעדיו רשימה של שמות לטיניים ("macOS, Linux")
  מוצגת כגוש אחד משמאל לימין, והפריטים נקראים בסדר הפוך. }
function UiBidi(const S: String): String;
begin
  Result := S;
  if UiHasHebrew(S) then
    StringChangeEx(Result, ', ', ',' + #$200F + ' ', True);
end;

{ גובה הטקסט ברוחב W; Flags בלי DT_CALCRECT. }
function UiTextH(const S: String; Size: Integer; Bold: Boolean; W: Integer;
  Flags: LongWord): Integer;
var
  R: TUiRect;
begin
  Result := 0;
  if S = '' then
    exit;
  UiSetFont(UiMeasure.Canvas, Size, Bold, 0);
  R.Left := 0;
  R.Top := 0;
  R.Right := W;
  R.Bottom := 0;
  UiDrawText(UiMeasure.Canvas.Handle, UiBidi(S), -1, R, Flags or DT_CALCRECT);
  Result := R.Bottom - R.Top;
end;

function UiTextW(const S: String; Size: Integer; Bold: Boolean): Integer;
var
  R: TUiRect;
begin
  UiSetFont(UiMeasure.Canvas, Size, Bold, 0);
  R.Left := 0;
  R.Top := 0;
  R.Right := 0;
  R.Bottom := 0;
  UiDrawText(UiMeasure.Canvas.Handle, S, -1, R,
    DT_CALCRECT or DT_SINGLELINE or DT_NOPREFIX);
  Result := R.Right - R.Left;
end;

procedure UiText(C: TCanvas; const S: String; X, Y, W, H, Size: Integer; Bold: Boolean;
  Color: TColor; Flags: LongWord);
var
  R: TUiRect;
begin
  UiSetFont(C, Size, Bold, Color);
  C.Brush.Style := bsClear;
  R.Left := X;
  R.Top := Y;
  R.Right := X + W;
  R.Bottom := Y + H;
  UiDrawText(C.Handle, UiBidi(S), -1, R, Flags);
end;

function UiTextFlags(const S: String): LongWord;
begin
  Result := UiAlign() or DT_WORDBREAK or DT_NOPREFIX;
  if UiHasHebrew(S) then
    Result := Result or DT_RTLREADING;
end;

{ שורה אחת שכולה בכיוון הממשק; טקסט עברי (שם מהמניפסט בלי תרגום) נקרא מימין גם באנגלית. }
function UiReading(const S: String): LongWord;
begin
  Result := 0;
  if UiRtl or UiHasHebrew(S) then
    Result := DT_RTLREADING;
end;

{ שלוש פרוסות אנכיות: עליונה ותחתונה בגודלן, והאמצעית חוזרת עד המילוי. }
{ פרוסה אמצעית נמתחת בקריאה אחת: ציור שורה-שורה עלה מאות קריאות לכרטיס. }
procedure UiDrawStretch(C: TCanvas; X, Y, W, H: Integer; Art: TBitmap);
begin
  if (Art.Width <= 0) or (Art.Height <= 0) or (W <= 0) or (H <= 0) then
    exit;
  UiAlphaBlend(C.Handle, X, Y, W, H, Art.Canvas.Handle, 0, 0, Art.Width, Art.Height,
    $01FF0000);
end;

procedure UiDrawVSlices(C: TCanvas; const Art: String; X, Y, H: Integer;
  Fallback: TColor);
var
  Top, Mid, Bottom: TBitmap;
  MidEnd: Integer;
begin
  Top := UiArt(Art + '_t');
  Mid := UiArt(Art + '_m');
  Bottom := UiArt(Art + '_b');
  if (Mid.Height <= 0) or (Top.Height <= 0) or (Bottom.Height <= 0) then
  begin
    UiFill(C, X, Y, Px(UiContentW), H, Fallback);
    exit;
  end;
  MidEnd := Y + H - Bottom.Height;
  UiDrawStretch(C, X, Y + Top.Height, Mid.Width, MidEnd - Y - Top.Height, Mid);
  UiDraw(C, X, Y, Top);
  UiDraw(C, X, MidEnd, Bottom);
end;

procedure UiDrawHSlices(C: TCanvas; const Art: String; X, Y, W: Integer);
var
  Left, Mid, Right: TBitmap;
  MidEnd: Integer;
begin
  Left := UiArt(Art + '_l');
  Mid := UiArt(Art + '_m');
  Right := UiArt(Art + '_r');
  if (Mid.Width <= 0) or (W < Left.Width + Right.Width) then
    exit;
  MidEnd := X + W - Right.Width;
  UiDrawStretch(C, X + Left.Width, Y, MidEnd - X - Left.Width, Mid.Height, Mid);
  UiDraw(C, X, Y, Left);
  UiDraw(C, MidEnd, Y, Right);
end;

procedure UiShowBitmap(Img: TBitmapImage; Bmp: TBitmap);
begin
  Img.Bitmap := Bmp;
  Img.SetBounds(Img.Left, Img.Top, Bmp.Width, Bmp.Height);
  Bmp.Free;
end;

procedure UiShowArt(Img: TBitmapImage; const Name: String);
var
  Art: TBitmap;
begin
  Art := UiArt(Name);
  Img.Bitmap := Art;
  Img.SetBounds(Img.Left, Img.Top, Art.Width, Art.Height);
end;

{ ============================ כפתורים ============================ }

function UiButtonState(I: Integer): String;
begin
  if not UiButtons[I].Enabled then
    Result := 'd'
  else if UiButtons[I].Down then
    Result := 'p'
  else if UiButtons[I].Hover then
    Result := 'h'
  else
    Result := 'n';
end;

procedure UiDrawButtonArt(C: TCanvas; Art: TBitmap; W: Integer);
var
  Cap: Integer;
begin
  if (Art.Width <= 0) or (W = Art.Width) then
  begin
    UiDraw(C, 0, 0, Art);
    exit;
  end;
  Cap := Px(14);
  UiAlphaBlend(C.Handle, 0, 0, Cap, Art.Height, Art.Canvas.Handle, 0, 0, Cap, Art.Height,
    $01FF0000);
  UiAlphaBlend(C.Handle, Cap, 0, W - 2 * Cap, Art.Height, Art.Canvas.Handle,
    Art.Width div 2, 0, 1, Art.Height, $01FF0000);
  UiAlphaBlend(C.Handle, W - Cap, 0, Cap, Art.Height, Art.Canvas.Handle, Art.Width - Cap, 0,
    Cap, Art.Height, $01FF0000);
end;

procedure UiRenderButton(I: Integer);
var
  State, Key, Art: String;
  Png: TBitmap;
  Bmp: TBitmap;
  Color: TColor;
  W: Integer;
begin
  State := UiButtonState(I);
  Key := State + '|' + UiButtons[I].Caption + '|' + IntToStr(UiButtons[I].Width);
  if Key = UiButtons[I].Drawn then
    exit;
  UiButtons[I].Drawn := Key;
  Art := UiButtons[I].Art;
  if (I = UiBtnClose) or (I = UiBtnMin) then
  begin
    if (State = 'h') or (State = 'p') then
      UiShowArt(UiButtons[I].Img, Art + 'h')
    else
      UiShowArt(UiButtons[I].Img, Art);
    exit;
  end;
  { לכפתור הטקסט אין מצב מושבת משלו. }
  if (State = 'd') and (Art = 'btn_ghost') then
    Png := UiArt(Art + '_n')
  else
    Png := UiArt(Art + '_' + State);
  W := UiButtons[I].Width;
  if W <= 0 then
    W := Png.Width;
  Bmp := UiCanvas(W, Png.Height, UiButtons[I].Back);
  UiDrawButtonArt(Bmp.Canvas, Png, W);
  if State = 'd' then
    Color := UiDisabledTextColor
  else if UiButtons[I].Danger then
    Color := UiErrorColor
  else if (Art = 'btn_primary') or (Art = 'btn_wide') then
    Color := UiOnPrimaryColor
  else if (Art = 'btn_tonal') or (Art = 'btn_tonalwide') then
    Color := UiOnTonalColor
  else
    Color := UiPrimaryColor;
  UiText(Bmp.Canvas, UiButtons[I].Caption, 0, 0, Bmp.Width, Bmp.Height, 14, True, Color,
    DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX or
    UiReading(UiButtons[I].Caption));
  UiShowBitmap(UiButtons[I].Img, Bmp);
end;

procedure UiSetButton(I: Integer; Shown, Enabled: Boolean; const Caption: String);
begin
  UiButtons[I].Shown := Shown;
  UiButtons[I].Enabled := Enabled;
  UiButtons[I].Caption := Caption;
  if UiButtons[I].Img.Visible <> Shown then
    UiButtons[I].Img.Visible := Shown;
  if Shown then
    UiRenderButton(I);
end;

{ הלחיצה נשלחת לכפתור האמיתי כהודעה ולא בקריאה ישירה: ההורדה כולה רצה בתוך
  "הבא", וקריאה ישירה הייתה מקננת אותה בתוך האירוע הזה. }
procedure UiClickReal(Button: TNewButton);
begin
  if Assigned(Button) and Button.Visible and Button.Enabled then
    PostMessage(WizardForm.Handle, UiWmCommand, 0, Button.Handle);
end;

procedure UiButtonClick(Sender: TObject); forward;

procedure UiMakeButton(I: Integer; Parent: TWinControl; const Art: String; X, Y: Integer);
begin
  UiButtons[I].Img := UiImage(Parent);
  UiButtons[I].Img.SetBounds(X, Y, 1, 1);
  UiButtons[I].Img.Cursor := crHand;
  UiButtons[I].Img.OnClick := @UiButtonClick;
  UiButtons[I].Img.Visible := False;
  UiButtons[I].Art := Art;
  UiButtons[I].Drawn := '';
  UiButtons[I].Width := 0;
  UiButtons[I].Back := UiPageColor;
  UiButtons[I].Danger := False;
end;

{ ראש כפתור במקום Index (מלמעלה) בערימה של Count כפתורים, בקואורדינטות 100% של
  החלון; הערימה נגמרת בתחתית כפתורי הכותרת התחתונה. }
function UiStackTop(Index, Count: Integer): Integer;
begin
  Result := UiActionsBottom - (Count - Index) * {#AA_BTN_PRIMARY_H} -
    (Count - 1 - Index) * UiStackGap;
end;

{ ============================ כרטיסים ============================ }

{ פריסת כרטיס: סימון בקצה שבו הטקסט מתחיל, אחריו אריח הסמל, ואז הכותרת והתיאור.
  Draw=False מודד בלבד ומחזיר את הגובה. }
function UiLayoutCard(var Card: TUiCard; C: TCanvas; Draw: Boolean): Integer;
var
  W, TextR, TextW, TitleH, DescH, SideH, Block, Body, X, Y: Integer;
  Side: String;
  Mark, Ico: TBitmap;
begin
  W := Px(UiContentW);
  TextR := W - Px(16 + UiToggle + 14 + UiIcon + 14);
  TextW := TextR - Px(16);
  Side := '';
  if Card.Side <> '' then
    Side := Msg1('CardSize', Card.Side);
  TitleH := UiTextH(Card.Title, 16, False, TextW, UiTextFlags(Card.Title));
  DescH := UiTextH(Card.Desc, 13, False, TextW, UiTextFlags(Card.Desc));
  SideH := UiTextH(Side, 12, False, TextW, UiTextFlags(Side));
  Block := TitleH;
  if DescH > 0 then
    Block := Block + Px(3) + DescH;
  if SideH > 0 then
    Block := Block + Px(4) + SideH;
  Result := Block + Px(30 + UiCardShadow);
  if Result < Px(68) then
    Result := Px(68);
  if not Draw then
    exit;

  if Card.Check then
  begin
    if Card.Sel then
      Mark := UiArt('check_on')
    else
      Mark := UiArt('check_off');
  end
  else if Card.Sel then
    Mark := UiArt('radio_on')
  else
    Mark := UiArt('radio_off');
  { הצל שבתחתית הפרוסה אינו חלק מהכרטיס, ולכן אינו נכלל במרכוז. }
  Body := Result - Px(UiCardShadow);
  UiDraw(C, UiX(W - Px(16) - Mark.Width, Mark.Width, W), (Body - Mark.Height) div 2,
    Mark);
  Ico := UiArt('ico_' + Card.Icon);
  UiDraw(C, UiX(W - Px(16 + UiToggle + 14) - Ico.Width, Ico.Width, W),
    (Body - Ico.Height) div 2, Ico);

  X := UiX(Px(16), TextW, W);
  Y := (Body - Block) div 2;
  UiText(C, Card.Title, X, Y, TextW, TitleH, 16, False, UiTextColor,
    UiTextFlags(Card.Title));
  Y := Y + TitleH;
  if DescH > 0 then
  begin
    UiText(C, Card.Desc, X, Y + Px(3), TextW, DescH, 13, False, UiSecondaryColor,
      UiTextFlags(Card.Desc));
    Y := Y + Px(3) + DescH;
  end;
  if SideH > 0 then
    UiText(C, Side, X, Y + Px(4), TextW, SideH, 12, False, UiFaintColor,
      UiTextFlags(Side));
end;

function UiCardArt(const Card: TUiCard): String;
begin
  if Card.Sel and Card.Hover then
    Result := 'card_sh'
  else if Card.Sel then
    Result := 'card_s'
  else if Card.Hover then
    Result := 'card_h'
  else
    Result := 'card_n';
end;

procedure UiRenderCardTo(var Card: TUiCard);
var
  Bmp: TBitmap;
  Key: String;
begin
  Key := UiCardArt(Card) + '|' + Card.Title + '|' + Card.Desc;
  if Key = Card.Drawn then
    exit;
  Card.Drawn := Key;
  Bmp := UiCanvas(Px(UiContentW), Card.Height, UiPageColor);
  UiDrawVSlices(Bmp.Canvas, UiCardArt(Card), 0, 0, Card.Height, UiCardColor);
  UiLayoutCard(Card, Bmp.Canvas, True);
  UiShowBitmap(Card.Img, Bmp);
end;

procedure UiRenderCard(I: Integer);
var
  Card: TUiCard;
begin
  Card := UiCards[I];
  UiRenderCardTo(Card);
  UiCards[I] := Card;
end;

{ ============================ גלילה ============================ }

procedure UiPlaceThumb();
var
  HostH, ThumbH, Room: Integer;
begin
  HostH := UiHost.Height;
  if UiContentH <= HostH then
  begin
    UiThumb.Visible := False;
    exit;
  end;
  ThumbH := HostH * HostH div UiContentH;
  if ThumbH < Px(28) then
    ThumbH := Px(28);
  Room := HostH - ThumbH;
  UiThumb.SetBounds(UiX(0, Px(4), UiHost.Width), Room * UiScrollY div (UiContentH - HostH),
    Px(4), ThumbH);
  UiThumb.Visible := True;
  UiThumb.BringToFront;
end;

function UiMaxScroll(): Integer;
begin
  Result := UiContentH - UiHost.Height;
  if Result < 0 then
    Result := 0;
end;

procedure UiScrollTo(Y: Integer);
begin
  if Y > UiMaxScroll() then
    Y := UiMaxScroll();
  if Y < 0 then
    Y := 0;
  UiScrollY := Y;
  UiContent.Top := -Y;
  UiPlaceThumb();
end;

procedure UiSetContentHeight(H: Integer);
begin
  UiContentH := H;
  if H < UiHost.Height then
    H := UiHost.Height;
  UiContent.SetBounds(UiX(Px(8), Px(UiContentW), UiHost.Width), 0, Px(UiContentW), H);
  UiScrollTarget := 0;
  UiScrollTo(0);
end;

procedure UiAnimateScroll();
var
  Step: Integer;
begin
  if UiThumbDrag or (UiScrollTarget = UiScrollY) then
    exit;
  Step := (UiScrollTarget - UiScrollY) * 2 div 5;
  if Step = 0 then
    Step := UiScrollTarget - UiScrollY;
  UiScrollTo(UiScrollY + Step);
end;

function UiPointIn(Ctl: TWinControl; X, Y: Integer): Boolean;
var
  P: TUiPoint;
begin
  Result := False;
  if not Assigned(Ctl) or not Ctl.Showing then
    exit;
  P.X := X;
  P.Y := Y;
  UiScreenToClient(Ctl.Handle, P);
  Result := (P.X >= 0) and (P.Y >= 0) and (P.X < Ctl.Width) and (P.Y < Ctl.Height);
end;

{ ============================ תוכן העמוד ============================ }

procedure UiClearContent();
var
  I: Integer;
begin
  for I := UiContent.ControlCount - 1 downto 0 do
    UiContent.Controls[I].Free;
  SetArrayLength(UiCards, 0);
  UiCardsPage := nil;
  UiFolderField := nil;
  UiResultImg := nil;
  UiProgCaption := nil;
  UiProgPercent := nil;
  UiProgSpeed := nil;
  UiProgBytes := nil;
  UiProgBar := nil;
  UiProgDrawn := '';
  UiProgSource := UiSrcNone;
  UiButtons[UiBtnBrowse].Img := nil;
  UiButtons[UiBtnBrowse].Shown := False;
  UiContentH := 0;
  UiThumbDrag := False;
end;

{ ממקם את מארח הגלילה בתוך Parent, מ-Top עד Bottom. }
procedure UiPlaceHost(Parent: TWinControl; Top, Bottom: Integer);
begin
  UiHost.Parent := Parent;
  UiHost.SetBounds(UiX(Px(UiMargin - 8), Px(UiContentW + 8), Px(UiWidth)), Top,
    Px(UiContentW + 8), Bottom - Top);
  UiHost.Visible := True;
  UiHost.BringToFront;
  UiSetContentHeight(0);
end;

function UiOptionIcon(PageID, Index: Integer): String;
var
  Value: String;
begin
  Result := 'component';
  if PageID = ModePage.ID then
  begin
    if Index = ModeThisComputer then
      Result := 'this_pc'
    else
      Result := 'other_pc';
  end
  else if (PageID = OtherPage.ID) and (Index < GetArrayLength(OtherPlatform)) then
  begin
    Result := OtherPlatform[Index];
    Value := OtherFormat[Index];
    if (Value = 'deb') or (Value = 'rpm') or (Value = PortableFormat) then
      Result := 'fmt_' + Value;
  end
  else if PageID = PresetPage.ID then
  begin
    if Index = CustomPresetIndex then
      Result := 'preset_custom'
    else if (Index < GetArrayLength(PresetId)) and (DisplayRank(PresetId[Index]) > 0) then
    begin
      Value := PresetId[Index];
      StringChangeEx(Value, '-', '_', True);
      Result := 'preset_' + Value;
    end;
  end;
end;

{ 'כותרת — גודל' של ההצעות: הגודל עובר לצד השמאלי של הכרטיס. }
procedure UiSplitSize(const Caption: String; var Title, Side: String);
var
  I: Integer;
begin
  Title := Caption;
  Side := '';
  for I := Length(Caption) - 2 downto 1 do
    if Copy(Caption, I, 3) = ' — ' then
    begin
      Title := Copy(Caption, 1, I - 1);
      Side := Copy(Caption, I + 3, Length(Caption));
      exit;
    end;
end;

function UiCardSelected(I: Integer): Boolean;
begin
  if UiCards[I].Check then
    Result := UiCardsPage.Values[I]
  else
    Result := UiCardsPage.SelectedValueIndex = I;
end;

procedure UiCardClick(Sender: TObject);
var
  I: Integer;
begin
  if not Assigned(UiCardsPage) then
    exit;
  for I := 0 to GetArrayLength(UiCards) - 1 do
    if Sender = UiCards[I].Img then
    begin
      if UiCards[I].Check then
        UiCardsPage.Values[I] := not UiCardsPage.Values[I]
      else
        UiCardsPage.SelectedValueIndex := I;
    end;
end;

procedure UiBuildCards(Page: TInputOptionWizardPage; PageID: Integer);
var
  I, N, Y, C: Integer;
  Card: TUiCard;
  Exclusive: Boolean;
begin
  UiCardsPage := Page;
  Exclusive := PageID <> CustomPage.ID;
  N := Page.CheckListBox.Items.Count;
  SetArrayLength(UiCards, N);
  Y := 0;
  for I := 0 to N - 1 do
  begin
    Card.Check := not Exclusive;
    Card.Icon := UiOptionIcon(PageID, I);
    Card.Side := '';
    Card.Desc := Page.CheckListBox.ItemSubItem[I];
    if PageID = CustomPage.ID then
    begin
      C := CustomIndex[I];
      Card.Title := CompName[C];
      if CompRequired[C] then
        Card.Title := Card.Title + ' ' + CustomMessage('RequiredTag');
      Card.Side := HumanSize(CustomChoiceSize(C));
    end
    else if (PageID = PresetPage.ID) and (I <> CustomPresetIndex) then
      UiSplitSize(Page.CheckListBox.ItemCaption[I], Card.Title, Card.Side)
    else
      Card.Title := Page.CheckListBox.ItemCaption[I];
    Card.Hover := False;
    Card.Drawn := '';
    Card.Img := UiImage(UiContent);
    Card.Img.Cursor := crHand;
    Card.Img.OnClick := @UiCardClick;
    Card.Height := UiLayoutCard(Card, nil, False);
    Card.Top := Y;
    Card.Img.SetBounds(0, Y, Px(UiContentW), Card.Height);
    UiCards[I] := Card;
    UiCards[I].Sel := UiCardSelected(I);
    UiRenderCard(I);
    Y := Y + Card.Height + Px(UiCardGap - UiCardShadow);
  end;
  if N > 0 then
    Y := Y - Px(UiCardGap - UiCardShadow);
  UiSetContentHeight(Y);
end;

{ ============================ עמוד התיקייה ============================ }

procedure UiRenderFolderField();
var
  Focused: Integer;
begin
  if not Assigned(UiFolderField) then
    exit;
  Focused := Ord(WizardForm.ActiveControl = FolderPage.Edits[0]);
  if Focused = UiFolderFocused then
    exit;
  UiFolderFocused := Focused;
  if Focused = 1 then
    UiShowArt(UiFolderField, 'field_f')
  else
    UiShowArt(UiFolderField, 'field_n');
end;

procedure UiBuildFolder();
var
  Edit: TEdit;
  FieldH, EditH, Y: Integer;
begin
  FolderPage.Buttons[0].Left := -Px(4000);
  UiFolderField := UiImage(UiContent);
  UiFolderField.SetBounds(0, 0, 1, 1);
  UiFolderFocused := -1;
  UiRenderFolderField();
  FieldH := UiFolderField.Height;
  if FieldH < Px(40) then
    FieldH := Px({#AA_FIELD_H});

  Edit := FolderPage.Edits[0];
  Edit.BorderStyle := bsNone;
  Edit.AutoSelect := False;
  Edit.AutoSize := False;
  Edit.Color := UiFieldColor;
  Edit.Font.Name := 'Segoe UI';
  Edit.Font.Height := -Px(14);
  Edit.Font.Color := UiTextColor;
  EditH := Px(20);
  Edit.SetBounds(UiHost.Left + UiContent.Left + Px(14),
    UiHost.Top + (FieldH - EditH) div 2, Px(UiContentW - 28), EditH);
  Edit.BringToFront;
  Edit.SelStart := 0;
  Edit.SelLength := 0;

  Y := FieldH + Px(12);
  UiMakeButton(UiBtnBrowse, UiContent, 'btn_tonal', 0, Y);
  UiSetButton(UiBtnBrowse, True, True, UiStrip(FolderPage.Buttons[0].Caption));
  UiButtons[UiBtnBrowse].Img.Left := UiX(Px(UiContentW) - UiButtons[UiBtnBrowse].Img.Width,
    UiButtons[UiBtnBrowse].Img.Width, Px(UiContentW));
  UiSetContentHeight(Y + UiButtons[UiBtnBrowse].Img.Height);
end;

{ ============================ עמוד הסיכום ============================ }

function UiSelectedSize(): Int64;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to GetArrayLength(CompId) - 1 do
    if CompSelected[I] then
      Result := Result + CompDownloadSize[I];
end;

function UiSummaryWhat(): String;
var
  Title, Side: String;
  I: Integer;
begin
  I := PresetPage.SelectedValueIndex;
  if (I >= 0) and (I < CustomPresetIndex) then
    UiSplitSize(PresetLabel[I], Title, Side)
  else
    Title := CustomMessage('PresetCustom');
  Result := Title + ' · ' + HumanSize(UiSelectedSize());
end;

function UiSummaryTarget(): String;
begin
  if IsThisComputerMode() then
    Result := ModePage.CheckListBox.ItemCaption[ModeThisComputer]
  else
    Result := TargetTitle(TargetPlatform, TargetArchitecture);
  if TargetFormat <> '' then
    Result := Result + ' · ' + FormatDisplayName(TargetFormat);
end;

{ שורה בכרטיס הסיכום; Draw=False מודד בלבד. }
function UiSummaryRow(C: TCanvas; Y: Integer; const Icon, Caption, Value: String;
  Ltr, Draw: Boolean): Integer;
var
  W, TextR, TextW, CapH, ValH, Flags: Integer;
  Ico: TBitmap;
begin
  W := Px(UiContentW);
  TextR := W - Px(16 + 40 + 14);
  TextW := TextR - Px(16);
  { נתיב בסיכום הוא תזכורת — הוא נקבע בעמוד הקודם — ולכן שורה אחת מקוצרת. }
  if Ltr then
    Flags := UiAlign() or DT_SINGLELINE or DT_PATH_ELLIPSIS or DT_NOPREFIX
  else
    Flags := UiTextFlags(Value);
  CapH := UiTextH(Caption, 12, False, TextW, UiTextFlags(Caption));
  ValH := UiTextH(Value, 16, False, TextW, Flags);
  Result := CapH + Px(2) + ValH;
  if Result < Px(40) then
    Result := Px(40);
  Result := Result + Px(28);
  if not Draw then
    exit;
  Ico := UiArt('ico_' + Icon);
  UiDraw(C, UiX(W - Px(16) - Ico.Width, Ico.Width, W), Y + (Result - Ico.Height) div 2, Ico);
  Y := Y + (Result - (CapH + Px(2) + ValH)) div 2;
  UiText(C, Caption, UiX(Px(16), TextW, W), Y, TextW, CapH, 12, False, UiFaintColor,
    UiTextFlags(Caption));
  UiText(C, Value, UiX(Px(16), TextW, W), Y + CapH + Px(2), TextW, ValH, 16, False,
    UiTextColor, Flags);
end;

{ שורה בלי ערך (למשל גרסה שאינה ידועה) אינה מוצגת. }
procedure UiAddRow(const Icon, Caption, Value: String; Ltr: Boolean);
var
  I: Integer;
begin
  if Value = '' then
    exit;
  I := GetArrayLength(UiRows);
  SetArrayLength(UiRows, I + 1);
  UiRows[I].Icon := Icon;
  UiRows[I].Caption := Caption;
  UiRows[I].Value := Value;
  UiRows[I].Ltr := Ltr;
end;

{ כרטיס אחד לשורות שנאספו ב-UiAddRow, ברצועה בצבע העמוד בין שורה לשורה כמו
  בכרטיסי ההגדרות. מחזיר את התחתית. }
function UiPlaceSummary(Y: Integer): Integer;
var
  Img: TBitmapImage;
  Bmp: TBitmap;
  Heights: array of Integer;
  I, N, H, RowY: Integer;
begin
  N := GetArrayLength(UiRows);
  SetArrayLength(Heights, N);
  H := Px(8) + Px(UiCardShadow) + (N - 1) * Px(2);
  for I := 0 to N - 1 do
  begin
    Heights[I] := UiSummaryRow(nil, 0, UiRows[I].Icon, UiRows[I].Caption, UiRows[I].Value,
      UiRows[I].Ltr, False);
    H := H + Heights[I];
  end;
  Bmp := UiCanvas(Px(UiContentW), H, UiPageColor);
  UiDrawVSlices(Bmp.Canvas, 'card_n', 0, 0, H, UiCardColor);
  RowY := Px(4);
  for I := 0 to N - 1 do
  begin
    if I > 0 then
    begin
      UiFill(Bmp.Canvas, 0, RowY, Px(UiContentW), Px(2), UiPageColor);
      RowY := RowY + Px(2);
    end;
    UiSummaryRow(Bmp.Canvas, RowY, UiRows[I].Icon, UiRows[I].Caption, UiRows[I].Value,
      UiRows[I].Ltr, True);
    RowY := RowY + Heights[I];
  end;
  SetArrayLength(UiRows, 0);
  Img := UiImage(UiContent);
  Img.SetBounds(0, Y, 1, 1);
  UiShowBitmap(Img, Bmp);
  Result := Y + H;
end;

procedure UiBuildReady();
var
  TargetIcon: String;
begin
  WizardForm.ReadyLabel.Visible := False;
  WizardForm.ReadyMemo.Visible := False;
  if IsThisComputerMode() then
    TargetIcon := 'this_pc'
  else
    TargetIcon := TargetPlatform;
  UiAddRow('preset_update', CustomMessage('RowVersion'), OtzariaVersionLabel(), False);
  UiAddRow(UiOptionIcon(PresetPage.ID, PresetPage.SelectedValueIndex),
    CustomMessage('RowWhat'), UiSummaryWhat(), False);
  UiAddRow(TargetIcon, CustomMessage('RowFor'), UiSummaryTarget(), False);
  UiAddRow('folder', CustomMessage('RowSavedIn'), FolderPage.Values[0], True);
  UiSetContentHeight(UiPlaceSummary(0));
end;

{ ============================ התקדמות ============================ }

procedure UiBuildProgress(Source: Integer);
var
  W, Y: Integer;
begin
  UiProgSource := Source;
  W := Px(UiContentW);
  Y := Px(28);
  UiProgPercent := UiLabel(UiContent, 40, True, UiPrimaryColor, taCenter);
  Y := UiPlaceLabel(UiProgPercent, '0%', 0, Y, W) + Px(4);
  UiProgCaption := UiLabel(UiContent, 14, False, UiTextColor, taCenter);
  Y := UiPlaceLabel(UiProgCaption, ' ', 0, Y, W) + Px(16);
  UiProgBar := UiImage(UiContent);
  UiProgBar.SetBounds(0, Y, W, Px(8));
  Y := Y + Px(8) + Px(16);
  UiProgSpeed := UiLabel(UiContent, 13, False, UiSecondaryColor, taCenter);
  Y := UiPlaceLabel(UiProgSpeed, ' ', 0, Y, W) + Px(4);
  UiProgBytes := UiLabel(UiContent, 13, False, UiFaintColor, taCenter);
  Y := UiPlaceLabel(UiProgBytes, ' ', 0, Y, W);
  UiSetContentHeight(Y);
end;

{ בפס בלי ערך (Max=0) מקטע נע מראה שהעבודה נמשכת. }
procedure UiRenderBar(Fraction: Extended; Indeterminate: Boolean);
var
  Bmp: TBitmap;
  W, H, FillW, X, Phase: Integer;
  Track: TBitmap;
  Key: String;
begin
  W := Px(UiContentW);
  Track := UiArt('bar_track_l');
  H := Track.Height;
  if H <= 0 then
    H := Px(8);
  if Indeterminate then
  begin
    Phase := (GetTickCount() div 30) mod 60;
    Key := 'i' + IntToStr(Phase);
  end
  else
  begin
    FillW := Round(W * Fraction);
    Key := 'f' + IntToStr(FillW);
  end;
  if Key = UiProgDrawn then
    exit;
  UiProgDrawn := Key;
  Bmp := UiCanvas(W, H, UiPageColor);
  UiDrawHSlices(Bmp.Canvas, 'bar_track', 0, 0, W);
  if Indeterminate then
  begin
    FillW := W * 3 div 10;
    X := (W + FillW) * Phase div 60 - FillW;
    { ההתקדמות נעה בכיוון הקריאה: בעברית מימין לשמאל. }
    if UiRtl then
      X := W - X - FillW;
    if X < 0 then
    begin
      FillW := FillW + X;
      X := 0;
    end;
    if X + FillW > W then
      FillW := W - X;
    if FillW >= Px(8) then
      UiDrawHSlices(Bmp.Canvas, 'bar_fill', X, 0, FillW);
  end
  else
  begin
    if (FillW > 0) and (FillW < Px(8)) then
      FillW := Px(8);
    if FillW > 0 then
      UiDrawHSlices(Bmp.Canvas, 'bar_fill', UiX(W - FillW, FillW, W), 0, FillW);
  end;
  UiProgBar.Bitmap := Bmp;
  Bmp.Free;
end;

{ ההתקדמות הכוללת: קבצים שהושלמו ועוד החלק של הקובץ הנוכחי לפי פס העמוד. }
function UiDownloadFraction(): Extended;
var
  I: Integer;
  Before, Current: Int64;
  Part, Done: Extended;
  Bar: TNewProgressBar;
begin
  Result := 0;
  if ProgressTotal <= 0 then
    exit;
  Before := 0;
  Current := 0;
  for I := 0 to GetArrayLength(QueueSize) - 1 do
  begin
    if Before = ProgressDone then
    begin
      Current := QueueSize[I];
      Break;
    end;
    Before := Before + QueueSize[I];
  end;
  Part := 0;
  Bar := DownloadPage.ProgressBar;
  if Bar.Visible and (Bar.Style = npbstNormal) and (Bar.Max > 0) then
  begin
    Part := Bar.Position;
    Part := Part / Bar.Max;
  end;
  Done := Current;
  Done := Done * Part + ProgressDone;
  Result := Done / ProgressTotal;
  if Result > 1 then
    Result := 1;
end;

procedure UiSetCaption(L: TNewStaticText; const S: String);
begin
  if Assigned(L) and (L.Caption <> S) then
    L.Caption := S;
end;

procedure UiUpdateProgress();
var
  Page: TOutputProgressWizardPage;
  Caption, Status, Speed, Bytes: String;
  Bar: TNewProgressBar;
  Fraction: Extended;
  Known: Boolean;
  P: Integer;
begin
  if (UiProgSource = UiSrcNone) or not Assigned(UiProgBar) then
    exit;
  Known := False;
  Fraction := 0;
  Speed := '';
  if UiProgSource = UiSrcConnect then
  begin
    UiSetCaption(UiProgCaption, CustomMessage('ConnectingProgress'));
    UiSetCaption(UiProgPercent, '');
    UiRenderBar(0, True);
    exit;
  end;
  if UiProgSource = UiSrcInstalling then
  begin
    Caption := WizardForm.StatusLabel.Caption;
    Bytes := '';
    Bar := WizardForm.ProgressGauge;
  end
  else
  begin
    if UiProgSource = UiSrcDownload then
      Page := DownloadPage
    else
      Page := WorkPage;
    Caption := Page.Msg1Label.Caption;
    Status := Page.Msg2Label.Caption;
    Bar := Page.ProgressBar;
    Bytes := Status;
    if UiProgSource = UiSrcDownload then
    begin
      Bytes := DownloadStatus;
      P := Pos(' · ', Bytes);
      if P > 0 then
      begin
        Speed := Copy(Bytes, P + 3, Length(Bytes));
        Bytes := Copy(Bytes, 1, P - 1);
      end;
      Fraction := UiDownloadFraction();
      Known := ProgressTotal > 0;
    end;
  end;
  if (UiProgSource <> UiSrcDownload) and Bar.Visible and (Bar.Style = npbstNormal) and
     (Bar.Max > 0) then
  begin
    Fraction := Bar.Position;
    Fraction := Fraction / Bar.Max;
    Known := True;
  end;
  UiSetCaption(UiProgCaption, Caption);
  UiSetCaption(UiProgSpeed, Speed);
  UiSetCaption(UiProgBytes, Bytes);
  if Known then
    UiSetCaption(UiProgPercent, IntToStr(Trunc(Fraction * 100)) + '%')
  else
    UiSetCaption(UiProgPercent, '');
  UiRenderBar(Fraction, not Known);
end;

{ ============================ שלבים וכותרת ============================ }

function UiStepOf(PageID: Integer; var Total: Integer): Integer;
var
  Other: Boolean;
begin
  Other := not IsThisComputerMode();
  if Other then
    Total := 6
  else
    Total := 5;
  Result := 0;
  if PageID = ModePage.ID then
    Result := 1
  else if PageID = OtherPage.ID then
    Result := 2
  else if (PageID = PresetPage.ID) or (PageID = CustomPage.ID) then
  begin
    if Other then
      Result := 3
    else
      Result := 2;
  end
  else if PageID = FolderPage.ID then
    Result := Total - 2
  else if PageID = wpReady then
    Result := Total - 1
  else if (PageID = DownloadPage.ID) or (PageID = WorkPage.ID) or
          (PageID = wpInstalling) or (PageID = wpPreparing) then
    Result := Total;
end;

{ הנקודות נקראות בכיוון הקריאה: בעברית השלב הראשון בקצה הימני. }
procedure UiRenderSteps();
var
  Step, Total, I, X, W, Gap: Integer;
  Dot: TBitmap;
  Bmp: TBitmap;
  Key: String;
begin
  Step := UiStepOf(UiPage, Total);
  Key := IntToStr(Step) + '/' + IntToStr(Total);
  if Key = UiStepDrawn then
    exit;
  UiStepDrawn := Key;
  UiStepImg.Visible := Step > 0;
  UiStepLabel.Visible := Step > 0;
  if Step = 0 then
    exit;
  Gap := Px(6);
  W := 0;
  for I := 1 to Total do
  begin
    if I = Step then
      W := W + UiArt('dot_cur').Width
    else
      W := W + UiArt('dot_off').Width;
    if I < Total then
      W := W + Gap;
  end;
  Bmp := UiCanvas(W, UiArt('dot_cur').Height, UiPageColor);
  X := W;
  for I := 1 to Total do
  begin
    if I = Step then
      Dot := UiArt('dot_cur')
    else if I < Step then
      Dot := UiArt('dot_on')
    else
      Dot := UiArt('dot_off');
    X := X - Dot.Width;
    UiDraw(Bmp.Canvas, UiX(X, Dot.Width, W), (Bmp.Height - Dot.Height) div 2, Dot);
    X := X - Gap;
  end;
  UiStepImg.Left := (Px(UiWidth) - W) div 2;
  UiShowBitmap(UiStepImg, Bmp);
  UiStepLabel.Caption := FmtMessage(CustomMessage('StepOf'), [IntToStr(Step),
    IntToStr(Total)]);
end;

{ כותרת העמוד, השאלה וההסבר; מחזיר את התחתית. }
function UiPlaceHeader(Parent: TWinControl; const Title, Desc, Hint: String): Integer;
var
  W, X: Integer;
begin
  X := Px(UiMargin);
  W := Px(UiContentW);
  UiHdrTitle.Parent := Parent;
  UiHdrDesc.Parent := Parent;
  UiHdrHint.Parent := Parent;
  Result := UiPlaceLabel(UiHdrTitle, Title, X, Px(4), W);
  Result := UiPlaceLabel(UiHdrDesc, Desc, X, Result + Px(6), W);
  Result := UiPlaceLabel(UiHdrHint, Hint, X, Result + Px(6), W);
end;

{ ============================ פתיחה ============================ }

{ פריימי הספר ואחריהם שלבי הכותרת, רק בקנה המידה הגדול. Stretch מקטין אותם לגודל
  הפקד במסנן SPLINE16 של Inno, ושומר את התוצאה עד שהתמונה מתחלפת. }
function UiHeroImage(I: Integer): TBitmap;
begin
  if not Assigned(UiHeroArt[I]) then
  begin
    if I < {#AA_BOOK_FRAMES} then
      UiHeroArt[I] := UiLoadArt('book_' + Format('%.2d', [I]), {#AA_BOOK_SRC_SCALE})
    else
      UiHeroArt[I] := UiLoadArt(UiTitleArt + IntToStr(I - {#AA_BOOK_FRAMES}),
        {#AA_TITLE_SRC_SCALE});
  end;
  Result := UiHeroArt[I];
end;

{ הפקד מחזיק עותק משותף של הפיקסלים. העותק שלנו משוחרר מיד: אחרת המתיחה הראשונה
  הייתה משכפלת את התמונה כולה. }
procedure UiHeroShow(Img: TBitmapImage; I: Integer);
begin
  Img.Bitmap := UiHeroImage(I);
  UiHeroArt[I].Free;
  UiHeroArt[I] := nil;
end;

{ משחרר כל מה שפוענח ולא הוצג, ועוצר את הפענוח. }
procedure UiHeroRelease();
var
  I: Integer;
begin
  for I := 0 to GetArrayLength(UiHeroArt) - 1 do
    if Assigned(UiHeroArt[I]) then
    begin
      UiHeroArt[I].Free;
      UiHeroArt[I] := nil;
    end;
  UiHeroNext := GetArrayLength(UiHeroArt);
end;

procedure UiHeroDecodeNext();
var
  Start, Ms: Extended;
begin
  Start := UiNowMs();
  UiHeroImage(UiHeroNext);
  Ms := UiNowMs() - Start;
  if Ms > UiHeroDecodeMax then
    UiHeroDecodeMax := Ms;
  UiHeroNext := UiHeroNext + 1;
end;

{ פענוח נכנס בפעימה אם יחד עם מה שכבר נעשה בה הוא נגמר לפני הפעימה הבאה. ההערכה
  היא האיטי ביותר שנמדד, ועוד רבע. }
function UiHeroDecodeFits(Used: Extended): Boolean;
begin
  Result := Used + UiHeroDecodeMax * 5 / 4 <= UiHeroTickMs;
end;

{ ניגון מתחיל או ממשיך רק אם לא ייעצר שוב: כל התמונות מוכנות, או שפענוח נכנס גם
  בפעימה שמחליפה פריים, ולכן קצב הפענוח עולה על קצב הניגון. }
function UiHeroCanRun(I: Integer): Boolean;
begin
  Result := (UiHeroNext >= GetArrayLength(UiHeroArt)) or
    ((UiHeroNext > I + 1) and UiHeroDecodeFits(UiHeroFrameCost));
end;

{ שכבה בצבע הדף מעל הספר. 2×2 ולא 1×1: המתיחה של Inno 6.7.3 נכשלת בתמונה בגובה
  שורה אחת. }
procedure UiHeroSetVeil(Alpha: Integer);
var
  Info: TUiBitmapInfo;
  Bits, Pixel: LongWord;
  Bmp: TBitmap;
  I: Integer;
begin
  UiHeroVeil.Visible := Alpha > 0;
  if Alpha <= 0 then
    exit;
  Info.Size := 40;
  Info.Width := 2;
  Info.Height := 2;
  Info.Planes := 1;
  Info.BitCount := 32;
  Bmp := TBitmap.Create;
  Bmp.Handle := UiCreateDibSection(0, Info, 0, Bits, 0, 0);
  Pixel := Alpha;
  Pixel := (Pixel shl 24) or ((UiPageColor and $FF) shl 16) or (UiPageColor and $FF00) or
    ((UiPageColor shr 16) and $FF);
  for I := 0 to 3 do
    UiWriteMemory(Bits + I * 4, Pixel, 4);
  { אלפא ישר: VCL מכפיל בו את הצבע בעצמו. }
  Bmp.AlphaFormat := afPremultiplied;
  UiHeroVeil.Bitmap := Bmp;
  Bmp.Free;
end;

procedure UiHeroPlaceFinal();
begin
  UiHeroDone := True;
  if UiHeroFrame <> {#AA_BOOK_FRAMES} - 1 then
    UiHeroShow(UiHeroBook, {#AA_BOOK_FRAMES} - 1);
  if UiHeroTitleStep <> {#AA_TITLE_STEPS} - 1 then
    UiHeroShow(UiHeroTitle, {#AA_BOOK_FRAMES} + {#AA_TITLE_STEPS} - 1);
  UiHeroFrame := {#AA_BOOK_FRAMES} - 1;
  UiHeroTitleStep := {#AA_TITLE_STEPS} - 1;
  UiHeroRelease();
  UiHeroVeil.Visible := False;
  UiHeroBook.Top := Px({#AA_BOOK_TOP} - {#AA_BOOK_RISE} - UiBarH);
  UiHeroTitle.Top := Px({#AA_TITLE_TOP} - UiBarH);
  UiHeroBook.Visible := True;
  UiHeroTitle.Visible := True;
  UiHeroNote.Visible := True;
  UiButtons[UiBtnStart].Img.Visible := True;
end;

function UiEaseOut(P: Extended): Extended;
begin
  if P > 1 then
    P := 1;
  Result := 1 - (1 - P) * (1 - P) * (1 - P);
end;

function UiEaseInOut(P: Extended): Extended;
begin
  if P > 1 then
    P := 1;
  if P < 0.5 then
    Result := 4 * P * P * P
  else
    Result := 1 - (2 - 2 * P) * (2 - 2 * P) * (2 - 2 * P) / 2;
end;

{ התמונה שהניגון דורש בזמן T: פריים הספר, ומסוף העלייה שלב הכותרת. }
function UiHeroWanted(T: Integer): Integer;
begin
  if T >= UiTitleEnd then
    Result := {#AA_BOOK_FRAMES} + {#AA_TITLE_STEPS} - 1
  else if T >= UiRiseEnd then
    Result := {#AA_BOOK_FRAMES} +
      (T - UiRiseEnd) * ({#AA_TITLE_STEPS} - 1) div {#AA_TITLE_FADE_MS}
  else
  begin
    Result := T div {#AA_BOOK_FRAME_MS};
    if Result > {#AA_BOOK_FRAMES} - 1 then
      Result := {#AA_BOOK_FRAMES} - 1;
  end;
end;

{ הספר מתחיל לעלות כשחצאיו נוחתים (AA_RISE_START_FRAME), שאר התמונות מתנגנות תוך
  כדי העלייה, והכותרת נחשפת בסופה. }
procedure UiHeroRender(T: Integer);
var
  I: Integer;
  E: Extended;
begin
  if T >= UiTitleEnd then
  begin
    UiHeroPlaceFinal();
    exit;
  end;
  I := UiHeroWanted(T);
  if (I < {#AA_BOOK_FRAMES}) and (I <> UiHeroFrame) then
  begin
    UiHeroShow(UiHeroBook, I);
    UiHeroFrame := I;
  end;
  if T < UiRiseStart then
    exit;
  if T < UiRiseEnd then
  begin
    E := T - UiRiseStart;
    E := UiEaseInOut(E / {#AA_RISE_MS});
    UiHeroBook.Top := Px({#AA_BOOK_TOP} - UiBarH) - Round(E * Px({#AA_BOOK_RISE}));
    exit;
  end;
  UiHeroBook.Top := Px({#AA_BOOK_TOP} - {#AA_BOOK_RISE} - UiBarH);
  if I - {#AA_BOOK_FRAMES} <> UiHeroTitleStep then
  begin
    UiHeroShow(UiHeroTitle, I);
    UiHeroTitleStep := I - {#AA_BOOK_FRAMES};
  end;
  E := T - UiRiseEnd;
  E := E / {#AA_TITLE_FADE_MS};
  UiHeroTitle.Top := Px({#AA_TITLE_TOP} - UiBarH) +
    Round((1 - UiEaseOut(E)) * Px({#AA_TITLE_SLIDE}));
  UiHeroTitle.Visible := True;
end;

{ פענוח זורם: תמונה אחת לכל היותר בפעימה, והספר הסגור מוצג כבר אחרי הראשונה. השעון
  מתקדם עד פריים אחד בפעימה ונעצר כשהתמונה הבאה חסרה: פריים לעולם אינו מדולג. }
procedure UiAnimateHero();
var
  Start, Used, E: Extended;
  Step, T, I, Shown: Integer;
begin
  if UiHeroDone or (UiPage <> wpWelcome) then
    exit;
  Start := UiNowMs();
  Step := Round(Start - UiHeroLast);
  if Step > {#AA_BOOK_FRAME_MS} then
    Step := {#AA_BOOK_FRAME_MS};
  UiHeroLast := Start;
  Shown := UiHeroFrame + UiHeroTitleStep;
  if UiHeroFade < 0 then
  begin
    if UiHeroNext > 0 then
    begin
      UiHeroShow(UiHeroBook, 0);
      UiHeroFrame := 0;
      UiHeroFade := 0;
      UiHeroSetVeil(255);
      UiHeroBook.Visible := True;
    end;
  end
  else if UiHeroFade < UiHeroFadeMs then
  begin
    UiHeroFade := UiHeroFade + Step;
    { '/' בין שני שלמים הוא חילוק שלמים ב-Pascal Script. }
    E := UiHeroFade;
    UiHeroSetVeil(Round(255 * (1 - UiEaseInOut(E / UiHeroFadeMs))));
  end
  else
  begin
    T := UiHeroT + Step;
    I := UiHeroWanted(T);
    UiHeroHeld := (I >= UiHeroNext) or (UiHeroHeld and not UiHeroCanRun(I));
    if not UiHeroHeld then
    begin
      UiHeroT := T;
      UiHeroRender(T);
    end;
  end;
  if UiHeroDone or (UiHeroNext >= GetArrayLength(UiHeroArt)) then
    exit;
  { מה שהשתנה מצויר לפני הפענוח, ולא מתעכב בגללו. }
  UiRedrawWindow(WizardForm.Handle, 0, 0, $180);
  Used := UiNowMs() - Start;
  if (UiHeroFrame + UiHeroTitleStep <> Shown) and (Used > UiHeroFrameCost) then
    UiHeroFrameCost := Used;
  if (UiHeroFade < UiHeroFadeMs) or UiHeroHeld or UiHeroDecodeFits(Used) then
    UiHeroDecodeNext();
end;

procedure UiBuildHero();
var
  Page: TNewNotebookPage;
  StartTop: Integer;
begin
  Page := WizardForm.WelcomePage;
  if not Assigned(UiHeroBook) then
  begin
    { "בואו נתחיל" נגמר בקו של כפתורי שאר העמודים, וההערה זזה איתו. }
    StartTop := UiActionsBottom - {#AA_BTN_WIDE_H};
    UiHeroBook := UiImage(Page);
    UiHeroBook.SetBounds((Px(UiWidth) - Px({#AA_BOOK_W})) div 2,
      Px({#AA_BOOK_TOP} - UiBarH), Px({#AA_BOOK_W}), Px({#AA_BOOK_H}));
    UiHeroBook.Stretch := True;
    UiHeroBook.Visible := False;
    UiHeroVeil := UiImage(Page);
    UiHeroVeil.SetBounds(UiHeroBook.Left, UiHeroBook.Top, UiHeroBook.Width, UiHeroBook.Height);
    UiHeroVeil.Stretch := True;
    UiHeroVeil.Visible := False;
    UiHeroTitle := UiImage(Page);
    UiHeroTitle.SetBounds(Px(UiMargin), Px({#AA_TITLE_TOP} - UiBarH), Px({#AA_TITLE_W}),
      Px({#AA_TITLE_H}));
    UiHeroTitle.Stretch := True;
    UiHeroTitle.Visible := False;
    UiHeroNote := UiLabel(Page, 13, False, UiSecondaryColor, taCenter);
    UiPlaceLabel(UiHeroNote, SetupMessage(msgWelcomeLabel2), Px(UiMargin + 16),
      Px({#AA_NOTE_TOP} + StartTop - {#AA_START_BUTTON_TOP} - UiBarH), Px(UiContentW - 32));
    UiHeroNote.Visible := False;
    UiMakeButton(UiBtnStart, Page, 'btn_wide', Px(UiMargin), Px(StartTop - UiBarH));
    UiSetButton(UiBtnStart, True, True, CustomMessage('StartButton'));
    UiButtons[UiBtnStart].Img.Visible := False;
    SetArrayLength(UiHeroArt, {#AA_BOOK_FRAMES} + {#AA_TITLE_STEPS});
    UiHeroFrame := -1;
    UiHeroTitleStep := -1;
    UiHeroFade := -1;
    UiHeroHeld := True;
  end;
  if UiHeroDone or not UiAnimationsEnabled() then
    UiHeroPlaceFinal();
end;

{ ============================ סיום ============================ }

function UiRevealClickTarget(): Boolean;
begin
  Result := (RevealPath <> '') and Assigned(RevealCheck);
end;

procedure UiRenderReveal();
var
  Bmp: TBitmap;
  Key: String;
  Mark: TBitmap;
  W, H, TextW: Integer;
begin
  if not Assigned(UiReveal.Img) or not UiRevealClickTarget() then
    exit;
  UiReveal.Sel := RevealCheck.Checked;
  UiReveal.Title := RevealCheck.Caption;
  Key := UiCardArt(UiReveal) + '|' + UiReveal.Title;
  if Key = UiReveal.Drawn then
    exit;
  UiReveal.Drawn := Key;
  W := Px(UiContentW);
  H := Px(52);
  Bmp := UiCanvas(W, H, UiPageColor);
  { שורת סימון ולא כרטיס בחירה: מסגרת רגילה גם כשהיא מסומנת. }
  if UiReveal.Hover then
    UiDrawVSlices(Bmp.Canvas, 'card_h', 0, 0, H, UiCardColor)
  else
    UiDrawVSlices(Bmp.Canvas, 'card_n', 0, 0, H, UiCardColor);
  if UiReveal.Sel then
    Mark := UiArt('check_on')
  else
    Mark := UiArt('check_off');
  UiDraw(Bmp.Canvas, UiX(W - Px(16) - Mark.Width, Mark.Width, W),
    (H - Px(UiCardShadow) - Mark.Height) div 2, Mark);
  TextW := W - Px(16 + UiToggle + 12 + 16);
  UiText(Bmp.Canvas, UiReveal.Title, UiX(Px(16), TextW, W), 0, TextW,
    H - Px(UiCardShadow), 16, False, UiTextColor, UiAlign() or DT_VCENTER or
    DT_SINGLELINE or DT_NOPREFIX or UiReading(UiReveal.Title));
  UiShowBitmap(UiReveal.Img, Bmp);
end;

procedure UiRevealClick(Sender: TObject);
begin
  if UiRevealClickTarget() then
    RevealCheck.Checked := not RevealCheck.Checked;
end;

{ משפט ממורכז, ורשימה עם השורה שמציגה אותה צמודות לצד שבו הקריאה מתחילה. שורה
  בלי עברית (פקודה, שם קובץ) נקראת משמאל לימין ונשברת גם באמצע מילה. }
function UiResultLineFlags(const Line: String; Center: Boolean): LongWord;
begin
  if Center then
    Result := DT_CENTER
  else
    Result := UiAlign();
  Result := Result or DT_WORDBREAK or DT_EDITCONTROL or DT_NOPREFIX;
  if UiHasHebrew(Line) then
    Result := Result or DT_RTLREADING;
end;

function UiLayoutResult(C: TCanvas; const Text: String; Draw: Boolean): Integer;
var
  Lines: TArrayOfString;
  I, N, W, H, Bullet, Y, Size: Integer;
  Line: String;
  Flags: LongWord;
  Value, Center: Boolean;
  Color: TColor;
begin
  W := Px(UiContentW);
  Size := 14;
  Bullet := UiTextW('•', Size, False) + Px(8);
  Lines := StringSplitEx(Text, [#13#10], #0, stAll);
  N := GetArrayLength(Lines);
  Y := 0;
  for I := 0 to N - 1 do
  begin
    Line := Lines[I];
    if Line = '' then
    begin
      Y := Y + Px(8);
      Continue;
    end;
    if Copy(Line, 1, 2) = '• ' then
    begin
      Line := Copy(Line, 3, Length(Line));
      Flags := UiResultLineFlags(Line, False);
      H := UiTextH(Line, Size, True, W - Bullet, Flags);
      if Draw then
      begin
        UiText(C, '•', UiX(W - Bullet, Bullet, W), Y, Bullet, H, Size, False, UiFaintColor,
          UiAlign() or DT_NOPREFIX);
        UiText(C, Line, UiX(0, W - Bullet, W), Y, W - Bullet, H, Size, True, UiTextColor,
          Flags);
      end;
    end
    else
    begin
      Center := True;
      if I + 1 < N then
        Center := Copy(Lines[I + 1], 1, 2) <> '• ';
      Flags := UiResultLineFlags(Line, Center);
      Value := ListIndex(ResultCommands, Line) >= 0;
      if Value then
        Color := UiTextColor
      else
        Color := UiSecondaryColor;
      if not Value and UiHasHebrew(Line) then
      begin
        { RLM סביב סוגריים עם טקסט לטיני, אחרת הסוגר והנקודה קופצים לצד הלא נכון. }
        StringChangeEx(Line, ' (', ' ' + #$200F + '(', True);
        StringChangeEx(Line, ').', ')' + #$200F + '.', True);
      end;
      H := UiTextH(Line, Size, Value, W, Flags);
      if Draw then
        UiText(C, Line, 0, Y, W, H, Size, Value, Color, Flags);
    end;
    Y := Y + H + Px(2);
  end;
  Result := Y;
end;

{ פעולות הסיום בערימה אחת מעל התחתית, כמו בעמודי השגיאה: במחשב הזה להתקין או
  לפתוח את התיקייה ו"סגור"; למחשב אחר "סיום". מחזיר את הגבול העליון שלהן. }
function UiPlaceFinishActions(Page: TNewNotebookPage): Integer;
var
  This, Install: Boolean;
begin
  if not Assigned(UiButtons[UiBtnDone].Img) then
  begin
    UiMakeButton(UiBtnInstall, Page, 'btn_primary', Px(UiMargin), 0);
    UiMakeButton(UiBtnOpenFolder, Page, 'btn_tonalwide', Px(UiMargin), 0);
    UiMakeButton(UiBtnDone, Page, 'btn_ghost', Px(UiMargin), 0);
    UiButtons[UiBtnInstall].Width := Px(UiContentW);
    UiButtons[UiBtnOpenFolder].Width := Px(UiContentW);
    UiButtons[UiBtnDone].Width := Px(UiContentW);
  end;
  This := IsThisComputerMode();
  Install := This and (RunAfterExe <> '');
  UiButtons[UiBtnDone].Img.Top := Px(UiStackTop(0, 1) - UiBarH);
  if This then
  begin
    UiButtons[UiBtnDone].Art := 'btn_ghost';
    UiButtons[UiBtnOpenFolder].Img.Top := Px(UiStackTop(0, 2) - UiBarH);
    UiButtons[UiBtnInstall].Img.Top := Px(UiStackTop(0, 3) - UiBarH);
  end
  else
    UiButtons[UiBtnDone].Art := 'btn_primary';
  UiButtons[UiBtnDone].Drawn := '';
  UiSetButton(UiBtnInstall, Install, True, CustomMessage('InstallNow'));
  UiSetButton(UiBtnOpenFolder, This, True, CustomMessage('OpenFolder'));
  if This then
    UiSetButton(UiBtnDone, True, True, CustomMessage('Close'))
  else
    UiSetButton(UiBtnDone, True, True, UiStrip(WizardForm.NextButton.Caption));
  UiFooter.Visible := False;
  if Install then
    Result := UiButtons[UiBtnInstall].Img.Top
  else if This then
    Result := UiButtons[UiBtnOpenFolder].Img.Top
  else
    Result := UiButtons[UiBtnDone].Img.Top;
end;

{ כרטיס עם הקובץ והתיקייה, כמו בסיכום שלפני ההורדה, ומתחתיו ההנחיה. }
procedure UiBuildFinish();
var
  Page: TNewNotebookPage;
  Bmp: TBitmap;
  H, Y, Bottom: Integer;
begin
  Page := WizardForm.FinishedPage;
  WizardForm.WizardBitmapImage2.Visible := False;
  WizardForm.FinishedHeadingLabel.Visible := False;
  WizardForm.FinishedLabel.Visible := False;
  WizardForm.RunList.Visible := False;
  WizardForm.YesRadio.Visible := False;
  WizardForm.NoRadio.Visible := False;
  if Assigned(RevealCheck) then
    RevealCheck.Left := -Px(4000);

  if not Assigned(UiBadge) then
  begin
    UiBadge := UiImage(Page);
    UiBadge.SetBounds(0, Px(UiBadgeTop - UiBarH), 1, 1);
    UiShowArt(UiBadge, 'badge_ok');
    UiBadge.Left := (Px(UiWidth) - UiBadge.Width) div 2;
    UiFinishTitle := UiLabel(Page, 20, True, UiTextColor, taCenter);
  end;
  Y := UiPlaceLabel(UiFinishTitle, WizardForm.FinishedHeadingLabel.Caption, Px(UiMargin),
    UiBadge.Top + UiBadge.Height + Px(16), Px(UiContentW));

  Bottom := UiPlaceFinishActions(Page) - Px(12);
  if not IsThisComputerMode() and UiRevealClickTarget() then
  begin
    if not Assigned(UiReveal.Img) then
    begin
      UiReveal.Img := UiImage(Page);
      UiReveal.Img.Cursor := crHand;
      UiReveal.Img.OnClick := @UiRevealClick;
      UiReveal.Check := True;
    end;
    UiReveal.Img.SetBounds(Px(UiMargin), Bottom - Px(52), Px(UiContentW), Px(52));
    UiReveal.Drawn := '';
    UiRenderReveal();
    UiReveal.Img.Visible := True;
    Bottom := Bottom - Px(52 + 12);
  end;

  UiPlaceHost(Page, Y + Px(16), Bottom);
  UiAddRow('preset_update', CustomMessage('RowVersion'), OtzariaVersionLabel(), False);
  UiAddRow('component', CustomMessage('RowFile'), ResultFile, True);
  UiAddRow('folder', CustomMessage('RowFolder'), ResultFolder, True);
  Y := UiPlaceSummary(0) + Px(16);
  H := UiLayoutResult(nil, ResultGuide, False);
  Bmp := UiCanvas(Px(UiContentW), H, UiPageColor);
  UiLayoutResult(Bmp.Canvas, ResultGuide, True);
  UiResultImg := UiImage(UiContent);
  UiResultImg.SetBounds(0, Y, 1, 1);
  UiShowBitmap(UiResultImg, Bmp);
  UiSetContentHeight(Y + H);
end;

{ ============================ בניית עמוד ============================ }

function UiOptionPage(PageID: Integer): TInputOptionWizardPage;
begin
  Result := nil;
  if PageID = ModePage.ID then
    Result := ModePage
  else if PageID = OtherPage.ID then
    Result := OtherPage
  else if PageID = PresetPage.ID then
    Result := PresetPage
  else if PageID = CustomPage.ID then
    Result := CustomPage;
end;

procedure UiHideProgressNative(Page: TOutputProgressWizardPage);
begin
  Page.Msg1Label.Left := -Px(4000);
  Page.Msg2Label.Left := -Px(4000);
  Page.ProgressBar.Left := -Px(4000);
end;

procedure UiHideFailure(); forward;

procedure UiRenderPage(PageID: Integer);
var
  Surface: TNewNotebookPage;
  Option: TInputOptionWizardPage;
  Hint: String;
  Bottom: Integer;
begin
  UiPage := PageID;
  { יציאה באמצע הפתיחה (Enter) משחררת את הפריימים; בחזרה מוצג המצב הסופי. }
  if (PageID <> wpWelcome) and Assigned(UiHeroBook) and not UiHeroDone then
  begin
    UiHeroDone := True;
    UiHeroRelease();
  end;
  UiHideFailure();
  UiClearContent();
  UiHost.Visible := False;
  UiFooter.Visible := PageID <> wpWelcome;
  UiStepDrawn := '';
  if PageID = wpWelcome then
  begin
    UiBuildHero();
    exit;
  end;
  if PageID = wpFinished then
  begin
    UiBuildFinish();
    exit;
  end;

  Surface := WizardForm.InnerNotebook.ActivePage;
  Option := UiOptionPage(PageID);
  Hint := '';
  if Assigned(Option) then
  begin
    Hint := Option.SubCaptionLabel.Caption;
    Option.SubCaptionLabel.Visible := False;
    Option.CheckListBox.Left := -Px(4000);
  end
  else if PageID = FolderPage.ID then
  begin
    Hint := FolderPage.SubCaptionLabel.Caption;
    FolderPage.SubCaptionLabel.Visible := False;
  end
  else if PageID = wpReady then
    Hint := WizardForm.ReadyLabel.Caption;
  UiRenderSteps();
  Bottom := UiPlaceHeader(Surface, WizardForm.PageNameLabel.Caption,
    WizardForm.PageDescriptionLabel.Caption, Hint);
  UiPlaceHost(Surface, Bottom + Px(20), Surface.ClientHeight - Px(12));

  if Assigned(Option) then
    UiBuildCards(Option, PageID)
  else if PageID = FolderPage.ID then
    UiBuildFolder()
  else if PageID = wpReady then
    UiBuildReady()
  else if PageID = DownloadPage.ID then
  begin
    UiHideProgressNative(DownloadPage);
    DownloadPage.AbortButton.Left := -Px(4000);
    UiBuildProgress(UiSrcDownload);
  end
  else if PageID = ConnectPage.ID then
  begin
    UiHideProgressNative(ConnectPage);
    ConnectPage.AbortButton.Left := -Px(4000);
    UiBuildProgress(UiSrcConnect);
  end
  else if PageID = WorkPage.ID then
  begin
    UiHideProgressNative(WorkPage);
    UiBuildProgress(UiSrcWork);
  end
  else if PageID = wpInstalling then
  begin
    WizardForm.StatusLabel.Left := -Px(4000);
    WizardForm.FilenameLabel.Left := -Px(4000);
    WizardForm.ProgressGauge.Left := -Px(4000);
    UiBuildProgress(UiSrcInstalling);
  end;
  UiUpdateProgress();
end;

{ ============================ חלונות ושגיאות ============================ }

function UiIsWin11(): Boolean;
var
  Version: TWindowsVersion;
begin
  GetWindowsVersionEx(Version);
  Result := Version.Build >= 22000;
end;

procedure UiRoundCorners(Wnd: Longint);
var
  Corner: Integer;
begin
  if not UiIsWin11() then
    exit;
  Corner := 2;
  UiDwmSetWindowAttribute(Wnd, 33, Corner, 4);
end;

{ קו מתאר של פיקסל לחלון הראשי: ב-Windows 10 אין לו קו משלו, והוא נמס ברקע בהיר. }
procedure UiAddFrame();
var
  I, W, H: Integer;
begin
  if UiIsWin11() then
    exit;
  W := Px(UiWidth);
  H := Px(UiHeight);
  SetArrayLength(UiFrame, 4);
  for I := 0 to 3 do
    UiFrame[I] := UiPanel(WizardForm, UiDividerColor);
  UiFrame[0].SetBounds(0, 0, W, 1);
  UiFrame[1].SetBounds(0, H - 1, W, 1);
  UiFrame[2].SetBounds(0, 0, 1, H);
  UiFrame[3].SetBounds(W - 1, 0, 1, H);
end;

procedure UiFrameToFront();
var
  I: Integer;
begin
  for I := 0 to GetArrayLength(UiFrame) - 1 do
    UiFrame[I].BringToFront;
end;

function UiButtonWidth(const Caption: String): Integer;
begin
  Result := UiTextW(Caption, 14, True) + Px(48);
  if Result < Px(104) then
    Result := Px(104);
end;

procedure UiDialogButtonClick(Sender: TObject);
begin
  if not Assigned(UiDlg) then
    exit;
  if Sender = UiButtons[UiBtnDlgOk].Img then
    PostMessage(UiDlg.Handle, UiWmCommand, 0, UiDlgOk.Handle)
  else if Sender = UiButtons[UiBtnDlgNo].Img then
    PostMessage(UiDlg.Handle, UiWmCommand, 0, UiDlgNo.Handle);
end;

{ שכבה כהה ושקופה למחצה מעל החלון הראשי, כמו מאחורי דו-שיח בתוכנה. }
procedure UiShowShade();
begin
  UiShade := CreateCustomForm(Px(10), Px(10), True, True);
  UiShade.BorderStyle := bsNone;
  UiShade.FlipControlsOnShow := False;
  UiShade.CenterOnShow := False;
  UiShade.Color := clBlack;
  UiShade.SetBounds(WizardForm.Left, WizardForm.Top, WizardForm.Width, WizardForm.Height);
  { WS_EX_LAYERED, WS_EX_TOOLWINDOW (בלי לחצן בשורת המשימות), WS_EX_NOACTIVATE. }
  UiSetWindowLong(UiShade.Handle, -20,
    UiGetWindowLong(UiShade.Handle, -20) or $00080000 or $00000080 or $08000000);
  UiSetLayeredWindowAttributes(UiShade.Handle, 0, UiShadeAlpha, 2);
  UiRoundCorners(UiShade.Handle);
  UiShade.Show;
end;

procedure UiFreeDialogButton(I: Integer);
begin
  if Assigned(UiButtons[I].Img) then
    UiButtons[I].Img.Free;
  UiButtons[I].Img := nil;
  UiButtons[I].Shown := False;
end;

{ חלון דו-שיח מעוצב במקום MsgBox. מחזיר True ל-Yes; Esc וסגירה — False. Danger: Yes
  הרסני — כפתור טקסט אדום, ו-No הבטוח הוא המלא וברירת המחדל של Enter, כמו בתוכנה. }
function UiAsk(const Title, Text, Yes, No: String; Danger: Boolean): Boolean;
var
  W, H, Pad, TitleH, TextH, BtnH, Y: Integer;
  L: TNewStaticText;
begin
  W := Px(336);
  Pad := Px(24);
  TitleH := UiTextH(Title, 18, True, W - 2 * Pad, UiTextFlags(Title));
  TextH := UiTextH(Text, 14, False, W - 2 * Pad, UiTextFlags(Text));
  BtnH := UiArt('btn_primary_n').Height;
  if BtnH <= 0 then
    BtnH := Px(40);
  H := Pad + TitleH + Px(10) + TextH + Px(24) + BtnH + Pad;
  UiDlg := CreateCustomForm(W, H, True, True);
  try
    UiDlg.BorderStyle := bsNone;
    UiDlg.FlipControlsOnShow := False;
    UiDlg.CenterOnShow := False;
    UiDlg.Color := UiBarColor;
    UiDlg.Caption := Title;
    UiDlg.SetBounds(WizardForm.Left + (WizardForm.Width - W) div 2,
      WizardForm.Top + (WizardForm.Height - H) div 2, W, H);
    UiRoundCorners(UiDlg.Handle);
    if not UiIsWin11() then
      UiSetWindowRgn(UiDlg.Handle, UiCreateRoundRectRgn(0, 0, W + 1, H + 1,
        Px(2 * {#AA_RADIUS}), Px(2 * {#AA_RADIUS})), True);

    L := UiLabel(UiDlg, 18, True, UiTextColor, taLeftJustify);
    UiPlaceLabel(L, Title, Pad, Pad, W - 2 * Pad);
    L := UiLabel(UiDlg, 14, False, UiSecondaryColor, taLeftJustify);
    UiPlaceLabel(L, Text, Pad, Pad + TitleH + Px(10), W - 2 * Pad);

    { כפתורים אמיתיים מחוץ לחלון: Enter ו-Esc, ו-ModalResult שסוגר את החלון. }
    UiDlgOk := TNewButton.Create(UiDlg);
    UiDlgOk.Parent := UiDlg;
    UiDlgOk.ModalResult := mrOk;
    UiDlgOk.Default := not Danger;
    UiDlgOk.SetBounds(-Px(4000), 0, Px(80), Px(24));
    UiDlgNo := TNewButton.Create(UiDlg);
    UiDlgNo.Parent := UiDlg;
    UiDlgNo.ModalResult := mrCancel;
    UiDlgNo.Cancel := True;
    UiDlgNo.Default := Danger;
    UiDlgNo.SetBounds(-Px(4000), 0, Px(80), Px(24));

    Y := H - Pad - BtnH;
    if Danger then
      UiMakeButton(UiBtnDlgOk, UiDlg, 'btn_ghost', Pad, Y)
    else
      UiMakeButton(UiBtnDlgOk, UiDlg, 'btn_primary', Pad, Y);
    UiButtons[UiBtnDlgOk].Img.OnClick := @UiDialogButtonClick;
    UiButtons[UiBtnDlgOk].Width := UiButtonWidth(Yes);
    UiButtons[UiBtnDlgOk].Back := UiBarColor;
    UiButtons[UiBtnDlgOk].Danger := Danger;
    UiSetButton(UiBtnDlgOk, True, True, Yes);
    if No <> '' then
    begin
      if Danger then
        UiMakeButton(UiBtnDlgNo, UiDlg, 'btn_primary',
          Pad + UiButtons[UiBtnDlgOk].Img.Width + Px(8), Y)
      else
        UiMakeButton(UiBtnDlgNo, UiDlg, 'btn_ghost',
          Pad + UiButtons[UiBtnDlgOk].Img.Width + Px(8), Y);
      UiButtons[UiBtnDlgNo].Img.OnClick := @UiDialogButtonClick;
      UiButtons[UiBtnDlgNo].Width := UiButtonWidth(No);
      UiButtons[UiBtnDlgNo].Back := UiBarColor;
      UiSetButton(UiBtnDlgNo, True, True, No);
      UiButtons[UiBtnDlgNo].Img.Left := UiX(UiButtons[UiBtnDlgNo].Img.Left,
        UiButtons[UiBtnDlgNo].Img.Width, W);
    end;
    UiButtons[UiBtnDlgOk].Img.Left := UiX(UiButtons[UiBtnDlgOk].Img.Left,
      UiButtons[UiBtnDlgOk].Img.Width, W);
    if Danger then
      UiDlg.ActiveControl := UiDlgNo
    else
      UiDlg.ActiveControl := UiDlgOk;
    UiShowShade();
    try
      Result := UiDlg.ShowModal() = mrOk;
    finally
      UiShade.Free;
      UiShade := nil;
    end;
  finally
    UiFreeDialogButton(UiBtnDlgOk);
    UiFreeDialogButton(UiBtnDlgNo);
    UiDlg.Free;
    UiDlg := nil;
  end;
end;

procedure UiTell(const Title, Text: String);
begin
  UiAsk(Title, Text, CustomMessage('OK'), '', False);
end;

{ Inno שואל לפני יציאה ב-MsgBox של המערכת; כאן אותה שאלה, באותו נוסח, בחלון מעוצב. }
function UiAskExit(): Boolean;
var
  Text: String;
begin
  Text := SetupMessage(msgExitSetupMessage);
  StringChangeEx(Text, '%n', #13#10, True);
  Result := UiAsk(SetupMessage(msgExitSetupTitle), Text, CustomMessage('ExitYes'),
    CustomMessage('ExitNo'), True);
end;

<event('CancelButtonClick')>
procedure UiCancelButtonClick(CurPageID: Integer; var Cancel, Confirm: Boolean);
begin
  Confirm := False;
  if UiClosing then
    exit;
  Cancel := UiAskExit();
end;

{ Inno מקבל סגירה רק בעמוד שיש בו "ביטול". בעמודי ההתקדמות השאלה נשאלת כאן,
  והסגירה מחכה עד שהשלב חוזר לעמוד רגיל (UiCloseIfRequested). }
procedure UiRequestClose();
begin
  if UiPage = wpFinished then
    UiClickReal(WizardForm.NextButton)
  else if WizardForm.CancelButton.CanFocus then
    PostMessage(WizardForm.Handle, UiWmSysCommand, UiScClose, 0)
  else if UiAskExit() then
  begin
    UiClosing := True;
    StopRequested := True;
  end;
end;

function UiCloseIfRequested(): Boolean;
begin
  Result := UiClosing;
  if Result then
    PostMessage(WizardForm.Handle, UiWmSysCommand, UiScClose, 0);
end;

{ RTF משמאל לימין: הפרטים הטכניים באנגלית, וצריך לבחור ולהעתיק אותם. }
function UiRtf(const Text: String): String;
var
  I: Integer;
  C: Char;
begin
  Result := '{\rtf1\ansi\deff0{\fonttbl{\f0 Consolas;}}{\colortbl;\red79\green69\blue57;}' +
    '\ltrpar\ql\f0\fs18\cf1 ';
  for I := 1 to Length(Text) do
  begin
    C := Text[I];
    if (C = '\') or (C = '{') or (C = '}') then
      Result := Result + '\' + C
    else if C = #10 then
      Result := Result + '\par '
    else if C = #13 then
      Continue
    else if Ord(C) > 127 then
      Result := Result + '\u' + IntToStr(Ord(C)) + '?'
    else
      Result := Result + C;
  end;
  Result := Result + '}';
end;

procedure UiErrLinkClick(Sender: TObject);
begin
  UiErrTech.Visible := not UiErrTech.Visible;
end;

procedure UiBuildErrorPanel();
var
  W: Integer;
begin
  W := Px(UiContentW);
  UiErrPanel := UiPanel(WizardForm, UiPageColor);
  UiErrPanel.SetBounds(0, Px(UiBarH), Px(UiWidth), Px(UiHeight - UiBarH));
  UiErrPanel.Visible := False;
  UiErrBadge := UiImage(UiErrPanel);
  UiErrBadge.SetBounds(0, Px(UiBadgeTop - UiBarH), 1, 1);
  UiErrTitle := UiLabel(UiErrPanel, 20, True, UiTextColor, taCenter);
  UiErrBody := UiLabel(UiErrPanel, 14, False, UiSecondaryColor, taCenter);
  UiErrLink := UiLabel(UiErrPanel, 13, True, UiPrimaryColor, taCenter);
  UiErrLink.Cursor := crHand;
  UiErrLink.OnClick := @UiErrLinkClick;
  UiErrTech := TRichEditViewer.Create(WizardForm);
  UiErrTech.Parent := UiErrPanel;
  UiErrTech.ReadOnly := True;
  UiErrTech.BorderStyle := bsNone;
  UiErrTech.ScrollBars := ssVertical;
  UiErrTech.Color := UiCardColor;
  UiErrTech.UseRichEdit := True;
  UiErrTech.Visible := False;

  UiMakeButton(UiBtnRetry, UiErrPanel, 'btn_primary', Px(UiMargin), 0);
  UiMakeButton(UiBtnOpenPage, UiErrPanel, 'btn_tonalwide', Px(UiMargin),
    Px(UiStackTop(1, 3) - UiBarH));
  UiMakeButton(UiBtnQuit, UiErrPanel, 'btn_ghost', Px(UiMargin), Px(UiStackTop(2, 3) - UiBarH));
  UiButtons[UiBtnRetry].Img.OnClick := @UiButtonClick;
  UiButtons[UiBtnOpenPage].Img.OnClick := @UiButtonClick;
  UiButtons[UiBtnQuit].Img.OnClick := @UiButtonClick;
  UiButtons[UiBtnRetry].Width := W;
  UiButtons[UiBtnOpenPage].Width := W;
  UiButtons[UiBtnQuit].Width := W;
end;

{ עמוד השגיאה מכסה את העמוד שבו קרה הכישלון. "נסה שוב" מסתיר אותו ולוחץ שוב על
  "הבא" של אותו עמוד, ולכן ניסיון חוזר עובר בדיוק באותם כללים של האשף. }
procedure UiShowFailure(Stage: Integer; const Title, Body, Tech: String; Offline: Boolean);
var
  Y, W, X: Integer;
  Heading: String;
  Stopped: Boolean;
begin
  if not UiReady or UiFailed or UiCloseIfRequested() then
    exit;
  if not Assigned(UiErrPanel) then
    UiBuildErrorPanel();
  W := Px(UiContentW);
  X := Px(UiMargin);
  Stopped := Stage = RunStopped;
  UiButtons[UiBtnRetry].Img.Top := Px(UiStackTop(0, 3) - UiBarH);
  if Stopped then
  begin
    { בעצירה אין מה לפתוח בדפדפן, ו"המשך" יורד אל מעל "סגור". }
    UiButtons[UiBtnRetry].Img.Top := Px(UiStackTop(0, 2) - UiBarH);
    UiShowArt(UiErrBadge, 'badge_paused');
  end
  else if Offline and (UiArt('badge_offline').Width > 0) then
    UiShowArt(UiErrBadge, 'badge_offline')
  else
    UiShowArt(UiErrBadge, 'badge_err');
  UiErrBadge.Left := (Px(UiWidth) - UiErrBadge.Width) div 2;
  { הנוסח הקיים הוא משפט שלם; ככותרת הוא מוצג בלי הנקודה. }
  Heading := Title;
  if Copy(Heading, Length(Heading), 1) = '.' then
    Heading := Copy(Heading, 1, Length(Heading) - 1);
  Y := UiPlaceLabel(UiErrTitle, Heading, X, UiErrBadge.Top + UiErrBadge.Height + Px(16), W);
  Y := UiPlaceLabel(UiErrBody, Body, X, Y + Px(8), W);
  UiErrTech.Visible := False;
  if Tech <> '' then
  begin
    Y := UiPlaceLabel(UiErrLink, CustomMessage('TechDetails'), X, Y + Px(14), W);
    UiErrTech.RTFText := UiRtf(Tech);
    UiErrTech.SetBounds(X, Y + Px(10), W,
      UiButtons[UiBtnRetry].Img.Top - Px(16) - Y - Px(10));
  end
  else
    UiErrLink.Visible := False;
  if Stopped then
    UiSetButton(UiBtnRetry, True, True, CustomMessage('Resume'))
  else
    UiSetButton(UiBtnRetry, True, True, CustomMessage('Retry'));
  UiSetButton(UiBtnOpenPage, not Stopped, True, CustomMessage('OpenDownloads'));
  UiSetButton(UiBtnQuit, True, True, CustomMessage('Close'));
  UiErrPanel.Visible := True;
  UiErrPanel.BringToFront;
  UiFrameToFront();
end;

procedure UiHideFailure();
begin
  if not Assigned(UiErrPanel) or not UiErrPanel.Visible then
    exit;
  UiErrPanel.Visible := False;
  UiButtons[UiBtnRetry].Shown := False;
  UiButtons[UiBtnOpenPage].Shown := False;
  UiButtons[UiBtnQuit].Shown := False;
end;

procedure UiButtonClick(Sender: TObject);
var
  I: Integer;
begin
  { בזמן דו-שיח החלון מושבת; לחיצה שבכל זאת הגיעה הייתה פותחת שאלה שנייה. }
  if UiIsWindowEnabled(WizardForm.Handle) = 0 then
    exit;
  for I := 0 to UiBtnCount - 1 do
    if (Sender = UiButtons[I].Img) and UiButtons[I].Shown and UiButtons[I].Enabled then
      case I of
        UiBtnNext, UiBtnStart: UiClickReal(WizardForm.NextButton);
        UiBtnBack: UiClickReal(WizardForm.BackButton);
        UiBtnBrowse: UiClickReal(FolderPage.Buttons[0]);
        UiBtnAbort:
          if UiPage = ConnectPage.ID then
          begin
            if UiAsk(CustomMessage('ConnectStopTitle'), CustomMessage('ConnectStopText'),
              CustomMessage('ConnectStopYes'), CustomMessage('ConnectStopNo'), True) then
              StopRequested := True;
          end
          else if UiAsk(CustomMessage('StopTitle'), CustomMessage('StopText'),
            CustomMessage('StopYes'), CustomMessage('StopNo'), True) then
            StopRequested := True;
        UiBtnRetry:
          begin
            UiHideFailure();
            UiClickReal(WizardForm.NextButton);
          end;
        UiBtnOpenPage: OpenDownloadsPage();
        UiBtnInstall:
          if RunInstaller() then
            UiClickReal(WizardForm.NextButton)
          else
            UiTell(CustomMessage('InstallFailedTitle'),
              Msg1('InstallFailedText', ExtractFileDir(RunAfterExe)));
        UiBtnOpenFolder: OpenOutputFolder();
        UiBtnDone: UiClickReal(WizardForm.NextButton);
        UiBtnQuit:
          begin
            UiClosing := True;
            WizardForm.Close;
          end;
        UiBtnClose: UiRequestClose();
        UiBtnMin: PostMessage(WizardForm.Handle, UiWmSysCommand, UiScMinimize, 0);
      end;
end;

{ ============================ עכבר ============================ }

function UiHitsX(Img: TBitmapImage; X: Integer): Boolean;
begin
  Result := (X >= Img.Left) and (X < Img.Left + Img.Width);
end;

procedure UiDragWindow();
begin
  UiReleaseCapture();
  PostMessage(WizardForm.Handle, UiWmSysCommand, UiScDragMove, 0);
end;

function UiOnMouseDown(X, Y, Wnd: Longint): Boolean;
var
  P: TUiPoint;
  Room: Integer;
begin
  Result := False;
  if (UiIsWindowEnabled(WizardForm.Handle) = 0) or not UiPointIn(WizardForm, X, Y) then
    exit;
  if not UiHeroDone and (UiPage = wpWelcome) then
    UiHeroPlaceFinal();
  { הפס צר; כל הרצועה שמשמאל לכרטיסים גוררת אותו. }
  if UiThumb.Visible and UiPointIn(UiHost, X, Y) then
  begin
    P.X := X;
    P.Y := Y;
    UiScreenToClient(UiHost.Handle, P);
    if UiX(P.X, 1, UiHost.Width) < Px(8) then
    begin
      if (P.Y < UiThumb.Top) or (P.Y >= UiThumb.Top + UiThumb.Height) then
      begin
        Room := UiHost.Height - UiThumb.Height;
        if Room > 0 then
          UiScrollTo((P.Y - UiThumb.Height div 2) * UiMaxScroll() div Room);
        UiScrollTarget := UiScrollY;
      end;
      UiThumbDrag := True;
      UiThumbGrabY := Y;
      UiThumbGrabScroll := UiScrollY;
      Result := True;
      exit;
    end;
  end;
  if (Wnd = UiTitleBar.Handle) or (Wnd = UiTitleLabel.Handle) then
  begin
    P.X := X;
    P.Y := Y;
    UiScreenToClient(UiTitleBar.Handle, P);
    if not UiHitsX(UiButtons[UiBtnMin].Img, P.X) and
       not UiHitsX(UiButtons[UiBtnClose].Img, P.X) then
    begin
      UiDragWindow();
      Result := True;
    end;
  end;
end;

function UiOnWheel(X, Y, Delta: Integer): Boolean;
begin
  Result := False;
  if not UiHost.Showing or (UiMaxScroll() = 0) or not UiPointIn(UiHost, X, Y) then
    exit;
  UiScrollTarget := UiScrollTarget - Delta * Px(56) div 120;
  if UiScrollTarget < 0 then
    UiScrollTarget := 0;
  if UiScrollTarget > UiMaxScroll() then
    UiScrollTarget := UiMaxScroll();
  Result := True;
end;

{ גלגלת העכבר מגיעה לחלון שבמוקד ולא לכרטיסים, ולכן נתפסת כאן. }
function UiMouseHookProc(Code: Integer; WParam: LongWord; LParam: LongWord): LongWord;
var
  Info: TUiMouseHookInfo;
  Delta: Integer;
begin
  if (Code >= 0) and UiReady and not UiFailed and
     ((WParam = UiWmMouseWheel) or (WParam = UiWmLButtonDown)) then
  begin
    UiReadHookInfo(Info, LParam, 24);
    if WParam = UiWmMouseWheel then
    begin
      Delta := (Info.MouseData shr 16) and $FFFF;
      if Delta >= 32768 then
        Delta := Delta - 65536;
      if UiOnWheel(Info.X, Info.Y, Delta) then
      begin
        Result := 1;
        exit;
      end;
    end
    else if UiOnMouseDown(Info.X, Info.Y, Info.Wnd) then
    begin
      Result := 1;
      exit;
    end;
  end;
  Result := UiCallNextHookEx(UiHook, Code, WParam, LParam);
end;

function UiHitImage(Img: TBitmapImage; Wnd: Longint; const P: TUiPoint): Boolean;
var
  Q: TUiPoint;
begin
  Result := False;
  if not Assigned(Img) or not Img.Visible or (Wnd = 0) or
     (Wnd <> Img.Parent.Handle) then
    exit;
  Q := P;
  UiScreenToClient(Wnd, Q);
  Result := (Q.X >= Img.Left) and (Q.Y >= Img.Top) and
    (Q.X < Img.Left + Img.Width) and (Q.Y < Img.Top + Img.Height);
end;

procedure UiPollMouse();
var
  P: TUiPoint;
  Wnd, ActiveWnd: Longint;
  Active, Down, Hover: Boolean;
  I: Integer;
  Card: TUiCard;
begin
  UiGetCursorPos(P);
  ActiveWnd := WizardForm.Handle;
  if Assigned(UiDlg) then
    ActiveWnd := UiDlg.Handle;
  Active := (UiGetForegroundWindow() = ActiveWnd) and (UiIsWindowEnabled(ActiveWnd) <> 0);
  Wnd := 0;
  if Active then
    Wnd := UiWindowFromPoint(P.X, P.Y);
  Down := (UiGetAsyncKeyState(1) and $8000) <> 0;

  if UiThumbDrag then
  begin
    if Down and (UiContentH > UiHost.Height) then
    begin
      UiScrollTarget := UiThumbGrabScroll + (P.Y - UiThumbGrabY) * UiContentH div UiHost.Height;
      if UiScrollTarget < 0 then
        UiScrollTarget := 0;
      if UiScrollTarget > UiMaxScroll() then
        UiScrollTarget := UiMaxScroll();
      UiScrollTo(UiScrollTarget);
    end
    else
      UiThumbDrag := False;
  end;

  for I := 0 to UiBtnCount - 1 do
    if Assigned(UiButtons[I].Img) and UiButtons[I].Shown then
    begin
      Hover := UiHitImage(UiButtons[I].Img, Wnd, P);
      if (Hover <> UiButtons[I].Hover) or ((Hover and Down) <> UiButtons[I].Down) then
      begin
        UiButtons[I].Hover := Hover;
        UiButtons[I].Down := Hover and Down;
        UiRenderButton(I);
      end;
    end;

  for I := 0 to GetArrayLength(UiCards) - 1 do
  begin
    Hover := UiHitImage(UiCards[I].Img, Wnd, P) and UiPointIn(UiHost, P.X, P.Y);
    if (Hover <> UiCards[I].Hover) or (UiCards[I].Sel <> UiCardSelected(I)) then
    begin
      Card := UiCards[I];
      Card.Hover := Hover;
      Card.Sel := UiCardSelected(I);
      UiRenderCardTo(Card);
      UiCards[I] := Card;
    end;
  end;

  if Assigned(UiReveal.Img) and UiReveal.Img.Visible and (UiPage = wpFinished) then
  begin
    Hover := UiHitImage(UiReveal.Img, Wnd, P);
    if Hover <> UiReveal.Hover then
      UiReveal.Hover := Hover;
    UiRenderReveal();
  end;
end;

{ ============================ מראה הכפתורים ============================ }

procedure UiSyncFooter();
var
  Next, Back: TNewButton;
  OnDownload: Boolean;
begin
  Next := WizardForm.NextButton;
  Back := WizardForm.BackButton;
  OnDownload := UiPage = DownloadPage.ID;
  UiSetButton(UiBtnNext, Next.Visible and (UiPage <> wpWelcome), Next.Enabled,
    UiStrip(Next.Caption));
  UiSetButton(UiBtnBack, Back.Visible and (UiPage <> wpWelcome), Back.Enabled,
    UiStrip(Back.Caption));
  if UiPage = ConnectPage.ID then
    UiSetButton(UiBtnAbort, ConnectPage.AbortButton.Visible,
      ConnectPage.AbortButton.Enabled and not StopRequested, CustomMessage('Cancel'))
  else
    UiSetButton(UiBtnAbort, OnDownload and DownloadPage.AbortButton.Visible,
      DownloadPage.AbortButton.Enabled and not StopRequested,
      UiStrip(DownloadPage.AbortButton.Caption));
end;

{ ============================ שעון ============================ }

{ החלון כמעט בגובה מסך נמוך: אחרי שחזור ממזעור, שינוי מסך או גרירה הוא מוחזר
  כולו לאזור העבודה. }
procedure UiKeepOnScreen();
var
  Win: TUiRect;
  Info: TUiMonitorInfo;
  X, Y: Integer;
begin
  if (UiGetAsyncKeyState(1) and $8000) <> 0 then
    exit;
  if not UiIsWindowVisible(WizardForm.Handle) or UiIsIconic(WizardForm.Handle) then
    exit;
  Info.Size := 40;
  if not UiGetWindowRect(WizardForm.Handle, Win) or
     not UiGetMonitorInfo(UiMonitorFromWindow(WizardForm.Handle, 2), Info) then
    exit;
  X := Win.Left;
  Y := Win.Top;
  if X + Win.Right - Win.Left > Info.Work.Right then
    X := Info.Work.Right - (Win.Right - Win.Left);
  if Y + Win.Bottom - Win.Top > Info.Work.Bottom then
    Y := Info.Work.Bottom - (Win.Bottom - Win.Top);
  if X < Info.Work.Left then
    X := Info.Work.Left;
  if Y < Info.Work.Top then
    Y := Info.Work.Top;
  { SWP_NOSIZE, SWP_NOZORDER, SWP_NOACTIVATE }
  if (X <> Win.Left) or (Y <> Win.Top) then
    UiSetWindowPos(WizardForm.Handle, 0, X, Y, 0, 0, $1 or $4 or $10);
end;

procedure UiFail(const Message: String);
begin
  UiFailed := True;
  Log('DownloadAssistant UI: ' + Message);
  if UiTimerId <> 0 then
    UiKillTimer(0, UiTimerId);
  UiTimerId := 0;
end;

procedure UiBuildChrome();
var
  W, Y: Integer;
begin
  W := Px(UiWidth);
  UiTitleLabel.Visible := True;

  UiMakeButton(UiBtnClose, UiTitleBar, 'cap_close', 0, 0);
  UiMakeButton(UiBtnMin, UiTitleBar, 'cap_min', 0, 0);
  UiSetButton(UiBtnClose, True, True, '');
  UiSetButton(UiBtnMin, True, True, '');
  UiButtons[UiBtnClose].Img.Left := UiX(0, UiButtons[UiBtnClose].Img.Width, W);
  UiButtons[UiBtnMin].Img.Left := UiX(UiButtons[UiBtnClose].Img.Width,
    UiButtons[UiBtnMin].Img.Width, W);

  Y := Px(UiFooterTop) + (Px(UiHeight - UiFooterTop) - UiArt('btn_primary_n').Height) div 2 -
    UiFooter.Top;
  UiMakeButton(UiBtnNext, UiFooter, 'btn_primary',
    UiX(Px(UiMargin), UiArt('btn_primary_n').Width, W), Y);
  UiMakeButton(UiBtnAbort, UiFooter, 'btn_tonal',
    UiX(Px(UiMargin), UiArt('btn_tonal_n').Width, W), Y);
  UiMakeButton(UiBtnBack, UiFooter, 'btn_ghost',
    UiX(W - Px(UiMargin) - UiArt('btn_ghost_n').Width, UiArt('btn_ghost_n').Width, W), Y);
end;

procedure UiFirstTick();
begin
  try
    ExtractTemporaryFiles('*_' + IntToStr(UiScale) + '.png');
  except
    Log('DownloadAssistant UI: cannot extract art: ' + GetExceptionMessage);
  end;
  UiBuildChrome();
  UiHook := UiSetWindowsHookEx(7, CreateCallback(@UiMouseHookProc), 0,
    UiGetCurrentThreadId());
  UiReady := True;
  UiRenderPage(WizardForm.CurPageID);
end;

{ כל יציאה מהפתיחה (סוף, לחיצה, עמוד אחר) מחזירה בפעימה הבאה את הקצב הרגיל. }
procedure UiPaceTimer();
var
  Ms: Integer;
begin
  if (UiPage = wpWelcome) and not UiHeroDone then
    Ms := UiHeroTickMs
  else
    Ms := UiTickMs;
  if Ms = UiTickRate then
    exit;
  UiKillTimer(0, UiTimerId);
  UiTickRate := Ms;
  UiTimerId := UiSetTimer(0, 0, Ms, UiTickProc);
end;

procedure UiTick(Wnd: LongWord; Msg: LongWord; IdEvent: LongWord; Time: LongWord);
begin
  if UiInTick or UiFailed then
    exit;
  UiInTick := True;
  try
    try
      if not UiReady then
        UiFirstTick();
      UiKeepOnScreen();
      UiAnimateHero();
      UiPaceTimer();
      UiAnimateScroll();
      UiSyncFooter();
      UiPollMouse();
      UiRenderSteps();
      UiRenderFolderField();
      UiUpdateProgress();
    except
      UiFail(GetExceptionMessage);
    end;
  finally
    UiInTick := False;
  end;
end;

{ ============================ חיבור לאשף ============================ }

procedure UiHideNativeChrome();
var
  I: Integer;
begin
  WizardForm.Bevel.Visible := False;
  WizardForm.BeveledLabel.Visible := False;
  WizardForm.MainPanel.Visible := False;
  WizardForm.Bevel1.Visible := False;
  WizardForm.WizardBitmapImage.Visible := False;
  WizardForm.WelcomeLabel1.Visible := False;
  WizardForm.WelcomeLabel2.Visible := False;
  WizardForm.WelcomePage.Color := UiPageColor;
  WizardForm.InnerPage.Color := UiPageColor;
  WizardForm.FinishedPage.Color := UiPageColor;
  for I := 0 to WizardForm.InnerNotebook.PageCount - 1 do
    WizardForm.InnerNotebook.Pages[I].Color := UiPageColor;
  { הכפתורים האמיתיים נשארים פעילים ל-Enter ו-Esc, אבל מחוץ לחלון. }
  WizardForm.NextButton.Top := Px(UiHeight + 100);
  WizardForm.BackButton.Top := Px(UiHeight + 100);
  WizardForm.CancelButton.Top := Px(UiHeight + 100);
end;

procedure UiInitializeWizard();
var
  Corner: Integer;
  Version: TWindowsVersion;
begin
  UiRtl := not EnglishUi();
#ifdef AA_TITLE_EN
  if UiRtl then
    UiTitleArt := 'title_'
  else
    UiTitleArt := 'title_en_';
#else
  UiTitleArt := 'title_';
#endif
  UiScale := UiPickScale();
  UiArtNames := TStringList.Create;
  UiMeasure := TBitmap.Create;
  UiMeasure.Width := 4;
  UiMeasure.Height := 4;
  SetArrayLength(UiButtons, UiBtnCount);

  { בלי היפוך של Inno: כל פקד ממוקם כאן ישירות במקומו הסופי, באנגלית דרך UiX. }
  WizardForm.FlipControlsOnShow := False;
  WizardForm.BorderStyle := bsNone;
  WizardForm.Constraints.MinWidth := 0;
  WizardForm.Constraints.MinHeight := 0;
  WizardForm.Color := UiPageColor;
  WizardForm.ClientWidth := Px(UiWidth);
  WizardForm.ClientHeight := Px(UiHeight);
  { WS_SYSMENU ו-WS_MINIMIZEBOX: מזעור ושחזור משורת המשימות גם בלי מסגרת. }
  UiSetWindowLong(WizardForm.Handle, -16,
    UiGetWindowLong(WizardForm.Handle, -16) or $00080000 or $00020000);
  UiSetClassLong(WizardForm.Handle, -26,
    UiGetClassLong(WizardForm.Handle, -26) or $00020000);
  { WS_EX_COMPOSITED: בלעדיו תמונה שמוחלפת נמחקת ונצבעת בשני שלבים ומהבהבת. דווקא על מחברת
    העמודים: על החלון הראשי (גם בנוסף לה) DWM עוד מציג לפעמים את השלב הריק. }
  UiSetWindowLong(WizardForm.OuterNotebook.Handle, -20,
    UiGetWindowLong(WizardForm.OuterNotebook.Handle, -20) or $02000000);
  GetWindowsVersionEx(Version);
  if Version.Build >= 22000 then
  begin
    Corner := 2;
    UiDwmSetWindowAttribute(WizardForm.Handle, 33, Corner, 4);
  end;

  UiTitleBar := UiPanel(WizardForm, UiBarColor);
  UiTitleBar.SetBounds(0, 0, Px(UiWidth), Px(UiBarH));
  UiPanel(UiTitleBar, UiBarBorderColor).SetBounds(0, Px(UiBarH) - 1, Px(UiWidth), 1);
  UiTitleLabel := UiLabel(UiTitleBar, 12, False, UiTextColor, taLeftJustify);
  UiTitleLabel.Color := UiBarColor;
  UiPlaceLabel(UiTitleLabel, SetupMessage(msgWelcomeLabel1),
    UiX(Px(2 * {#AA_CAP_W} + 8), Px(UiWidth - (2 * {#AA_CAP_W} + 8) - 12), Px(UiWidth)), 0,
    Px(UiWidth - (2 * {#AA_CAP_W} + 8) - 12));
  UiTitleLabel.Top := (Px(UiBarH) - UiTitleLabel.Height) div 2;
  UiTitleLabel.Visible := False;

  WizardForm.OuterNotebook.SetBounds(0, Px(UiBarH), Px(UiWidth), Px(UiHeight - UiBarH));
  WizardForm.InnerNotebook.SetBounds(0, Px(UiStepsH), Px(UiWidth),
    Px(UiFooterTop - UiBarH - UiStepsH));
  UiHideNativeChrome();

  UiStepImg := UiImage(WizardForm.InnerPage);
  UiStepImg.SetBounds(0, Px(14), 1, 1);
  UiStepLabel := UiLabel(WizardForm.InnerPage, 12, False, UiFaintColor, taCenter);
  UiPlaceLabel(UiStepLabel, ' ', Px(UiMargin), Px(24), Px(UiContentW));

  UiHdrTitle := UiLabel(WizardForm.InnerPage, 20, True, UiTextColor, taCenter);
  UiHdrDesc := UiLabel(WizardForm.InnerPage, 14, False, UiSecondaryColor, taCenter);
  UiHdrHint := UiLabel(WizardForm.InnerPage, 13, False, UiSecondaryColor, taCenter);

  UiFooter := UiPanel(WizardForm, UiPageColor);
  UiFooter.SetBounds(0, Px(UiFooterTop), Px(UiWidth), Px(UiHeight - UiFooterTop));
  UiPanel(UiFooter, UiDividerColor).SetBounds(0, 0, Px(UiWidth), 1);
  UiFooter.Visible := False;

  UiHost := UiPanel(WizardForm.InnerPage, UiPageColor);
  UiHost.Visible := False;
  UiContent := UiPanel(UiHost, UiPageColor);
  UiThumb := UiPanel(UiHost, UiThumbColor);
  UiThumb.Visible := False;

  { MinimizePathName מקצר את שורת המצב לרוחב התווית, והתווית עצמה מוסתרת. }
  DownloadPage.Msg2Label.Width := Px(4000);
  WorkPage.Msg2Label.Width := Px(4000);

  UiAddFrame();
  UiPage := -1;
  UiTickProc := CreateCallback(@UiTick);
  UiTickRate := UiTickMs;
  UiTimerId := UiSetTimer(0, 0, UiTickRate, UiTickProc);
end;

procedure UiCurPageChanged(CurPageID: Integer);
begin
  UiPage := CurPageID;
  { יציאה שאושרה באמצע הכנה שהסתיימה בהצלחה. }
  if UiClosing and (CurPageID = wpFinished) then
    UiClickReal(WizardForm.NextButton);
  if not UiReady or UiFailed then
    exit;
  try
    UiRenderPage(CurPageID);
  except
    UiFail(GetExceptionMessage);
  end;
end;

procedure UiDeinitializeSetup();
begin
  if UiTimerId <> 0 then
    UiKillTimer(0, UiTimerId);
  UiTimerId := 0;
  if UiHook <> 0 then
    UiUnhookWindowsHookEx(UiHook);
  UiHook := 0;
end;
