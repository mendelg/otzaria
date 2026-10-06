[Files]
; העיצוב של שכבת התצוגה, משותף למסייע ולמתקינים. נכלל לפני כל [Files] אחר: עם SolidCompression
; ExtractTemporaryFile של תמונה מאוחרת היה פורס קודם את כל מה שלפניה, והפתיחה הייתה ממתינה.
; הערות ';' תקפות רק מחוץ ל-[Code], ולכן גם ה-.isi נכלל כאן ולא בראש הקובץ.
#if VER < EncodeVer(6, 7, 1)
  #error "שכבת התצוגה של אוצריא דורשת Inno Setup 6.7.1 ומעלה (Requires Inno Setup 6.7.1 or newer)"
#endif
#define AssistantArtIsi AddBackslash(SourcePath) + "assistant_art\assistant_art.isi"
#if !FileExists(AssistantArtIsi)
  #error "חסר העיצוב ב-installer\assistant_art. יש למשוך אותו לפני הבנייה (Art missing: fetch installer\assistant_art before compiling)"
#endif
#include AssistantArtIsi
#ifndef AA_TITLE_BAR_H
  #define AA_TITLE_BAR_H AA_CAP_H
#endif
#if AA_SCALES != "100,125,150,175,200,250"
  #error "רשימת קני המידה של העיצוב השתנתה: יש לעדכן את [Files] (Art scales changed: update [Files])"
#endif
#ifndef AA_BOOK_SRC_SCALE
  #error "העיצוב ישן: נדרשת גרסה 1.2.0 ומעלה (Art too old: 1.2.0 or newer required)"
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
