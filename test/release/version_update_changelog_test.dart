import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

bool _hasPwsh() {
  try {
    return Process.runSync('pwsh', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

void main() {
  final scripts = [
    p.absolute('tool/version/update_version.sh'),
    p.absolute('tool/version/update_version.ps1'),
  ];
  final hasPwsh = _hasPwsh();

  for (final script in scripts) {
    for (final hotfix in [0, 2]) {
      test(
        '${p.basename(script)} creates the changelog heading for hotfix $hotfix',
        () async {
          final dir = await Directory.systemTemp.createTemp('otzaria_version_');
          addTearDown(() => dir.deleteSync(recursive: true));

          void write(String path, String content) {
            final file = File(p.join(dir.path, path));
            file.parent.createSync(recursive: true);
            file.writeAsStringSync(content);
          }

          write('.gitignore', 'external/\n');
          write('pubspec.yaml', 'version: 0.9.96+99600\n');
          write(
            'tool/version/version.json',
            jsonEncode({'version': '0.9.97', 'hotfix': hotfix}),
          );
          write(
            'lib/main.dart',
            'const int _latestReleasedBuildNumber = 99600;\n',
          );
          write('assets/יומן שינויים.md', '* **0.9.96**\n  - קודם\n');
          write('installer/otzaria.iss', '#define MyAppVersion "0.9.96"\n');
          write(
            'installer/otzaria_full.iss',
            '#define MyAppVersion "0.9.96"\n',
          );

          for (final args in [
            ['init', '-q'],
            ['config', 'user.name', 'Test'],
            ['config', 'user.email', 'test@example.com'],
          ]) {
            final result = await Process.run(
              'git',
              args,
              workingDirectory: dir.path,
            );
            expect(result.exitCode, 0, reason: '${result.stderr}');
          }

          final versionFile = p.join('tool', 'version', 'version.json');
          final result = await Process.run(
            script.endsWith('.ps1') ? 'pwsh' : 'bash',
            script.endsWith('.ps1')
                ? ['-NoLogo', '-NoProfile', '-File', script, versionFile]
                : [script, versionFile],
            workingDirectory: dir.path,
          );
          expect(
            result.exitCode,
            0,
            reason: '${result.stdout}\n${result.stderr}',
          );

          final changelog = File(
            p.join(dir.path, 'assets/יומן שינויים.md'),
          ).readAsLinesSync();
          expect(
            changelog.first,
            hotfix == 0 ? '* **0.9.97**' : '* **0.9.97.$hotfix**',
          );
          expect(changelog, contains('* **0.9.96**'));
        },
        skip: script.endsWith('.ps1') && !hasPwsh
            ? 'pwsh is unavailable'
            : false,
      );
    }
  }
}
