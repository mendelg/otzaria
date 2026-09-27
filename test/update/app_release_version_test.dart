import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/update/app_release_version.dart';
import 'package:package_info_plus/package_info_plus.dart';

PackageInfo _info(String version, String buildNumber) => PackageInfo(
  appName: 'otzaria',
  packageName: 'otzaria',
  version: version,
  buildNumber: buildNumber,
);

void main() {
  group('appReleaseVersion (issue #1547)', () {
    test('hotfix מקוד הגרסה נוסף כחלק רביעי', () {
      expect(appReleaseVersion(_info('0.9.97', '99702')), '0.9.97.2');
      expect(appReleaseVersion(_info('1.2.3', '1020399')), '1.2.3.99');
    });

    test('hotfix 0 נשאר בפורמט הרגיל', () {
      expect(appReleaseVersion(_info('0.9.97', '99700')), '0.9.97');
      expect(appReleaseVersion(_info('0.10.0', '100000')), '0.10.0');
    });

    test('build שאינו קוד הגרסה של אותה גרסה אינו נחשב hotfix', () {
      expect(appReleaseVersion(_info('0.9.97', '99802')), '0.9.97');
      expect(appReleaseVersion(_info('0.9.97', '790')), '0.9.97');
      expect(appReleaseVersion(_info('0.9.97', '')), '0.9.97');
      expect(appReleaseVersion(_info('0.9.97', 'abc')), '0.9.97');
      expect(appReleaseVersion(_info('0.9', '90002')), '0.9');
    });
  });
}
