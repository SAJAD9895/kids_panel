import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Clean Architecture rule (02-flutter-architecture §2.1): the domain layer is pure Dart.
/// No Flutter, Supabase, Riverpod or data-layer imports.
void main() {
  test(
    'domain files import nothing from Flutter, Supabase, Riverpod or data/',
    () {
      final domainFiles = [
        ...Directory('lib/features')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.contains('/domain/')),
        File('lib/core/gate/parental_gate.dart'),
      ];
      expect(domainFiles, isNotEmpty);
      final forbidden = RegExp(
        r"import '(package:(flutter|supabase|supabase_flutter|flutter_riverpod|riverpod|go_router)/|[^']*/(data|presentation)/)",
      );
      for (final f in domainFiles) {
        final bad = f.readAsLinesSync().where(forbidden.hasMatch).toList();
        expect(bad, isEmpty, reason: f.path);
      }
    },
  );

  test('no secret keys or database URLs in the app source', () {
    final pattern = RegExp(
      r'sb_secret_[A-Za-z0-9]|service_role\b(?!.*(looksLikeSecretKey|role ==|supabase_admin))|postgres(ql)?://', // secret-scan: allow
    );
    for (final f
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      for (final line in f.readAsLinesSync()) {
        if (line.trimLeft().startsWith('//') ||
            line.trimLeft().startsWith('///')) {
          continue;
        }
        if (f.path.endsWith('app_config.dart')) {
          continue; // the detector itself names the patterns
        }
        expect(pattern.hasMatch(line), isFalse, reason: '${f.path}: $line');
      }
    }
  });
}
