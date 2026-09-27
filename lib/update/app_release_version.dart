import 'package:package_info_plus/package_info_plus.dart';

/// גרסת האפליקציה בפורמט תג השחרור: `0.9.97.2` כשיש hotfix, אחרת `0.9.97`.
/// ה-hotfix הוא `buildNumber % 100`, רק כש-buildNumber הוא קוד הגרסה של אותה גרסה.
String appReleaseVersion(PackageInfo info) {
  final version = info.version.trim();
  final parts = version.split('.').map(int.tryParse).toList();
  final code = int.tryParse(info.buildNumber.trim());
  if (parts.length != 3 || parts.contains(null) || code == null) {
    return version;
  }
  final base = parts[0]! * 10000 + parts[1]! * 100 + parts[2]!;
  final hotfix = code ~/ 100 == base ? code % 100 : 0;
  return hotfix > 0 ? '$version.$hotfix' : version;
}
