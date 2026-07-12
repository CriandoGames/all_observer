import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'dart2js compiles core and engine entrypoints',
    () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'all_observer_dart2js_',
      );
      final String outputPath =
          '${tempDir.path}${Platform.pathSeparator}all_observer_entry.js';

      try {
        final ProcessResult result = await Process.run(
          'dart',
          <String>[
            'compile',
            'js',
            'test/fixtures/dart2js_entry.dart',
            '-o',
            outputPath,
          ],
          workingDirectory: Directory.current.path,
          runInShell: Platform.isWindows,
        );

        if (result.exitCode != 0) {
          fail(
            'dart2js compile failed (exit ${result.exitCode}).\n'
            'stdout: ${result.stdout}\n'
            'stderr: ${result.stderr}',
          );
        }

        expect(await File(outputPath).exists(), isTrue);
      } finally {
        await tempDir.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
