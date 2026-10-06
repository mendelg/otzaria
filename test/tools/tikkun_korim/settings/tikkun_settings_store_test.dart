/// מנהג הקריאות (א"י/חו"ל) נגזר מהעיר שבלוח השנה כל עוד לא נבחר במפורש.
library;

import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';
import 'package:otzaria/tools/tikkun_korim/settings/tikkun_settings.dart';

import '../../../test_helpers/memory_cache_provider.dart';

void main() {
  const store = TikkunSettingsStore();

  setUp(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
  });

  test('בלי עיר בלוח — ארץ ישראל', () {
    expect(store.load().nusachLand, 'israel');
  });

  test('עיר בחוץ לארץ בלוח — חוץ לארץ', () async {
    await Settings.setValue<String>(
      SettingsRepository.keySelectedCity,
      'לונדון',
    );
    expect(store.load().nusachLand, 'diaspora');
  });

  test('שמירת הגדרה אחרת אינה מקבעת את המנהג שנגזר מהלוח', () async {
    await Settings.setValue<String>(
      SettingsRepository.keySelectedCity,
      'לונדון',
    );
    await store.save(store.load().copyWith(zoom: 1.5));
    await Settings.setValue<String>(
      SettingsRepository.keySelectedCity,
      'ירושלים',
    );
    expect(store.load().nusachLand, 'israel');
  });

  test('בחירה מפורשת גוברת על הלוח', () async {
    await Settings.setValue<String>(
      SettingsRepository.keySelectedCity,
      'לונדון',
    );
    await store.save(store.load().copyWith(nusachLand: 'israel'));
    expect(store.load().nusachLand, 'israel');
  });
}
