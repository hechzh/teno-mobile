import 'dart:io';
import 'dart:convert';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class Labels extends RecursiveAstVisitor<void> {
  final labels = <String>{};
  @override
  void visitSimpleStringLiteral(SimpleStringLiteral n) {
    final v = n.value;
    if (RegExp(r'^[A-Z][A-Za-z]*(?:\s|$|[?…])').hasMatch(v) &&
        !v.contains('/api/') &&
        !v.contains('.dart'))
      labels.add(v);
  }
}

void main() {
  final all = <String>{};
  for (final f
      in Directory('shared-ui/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.dart') &&
                !f.path.contains('l10n') &&
                !f.path.contains('generated') &&
                !f.path.contains('runtime.g.'),
          )) {
    final v = Labels();
    parseString(content: f.readAsStringSync()).unit.accept(v);
    all.addAll(v.labels);
  }
  File('scripts/ui-label-audit.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(all.toList()..sort()),
  );
  stdout.writeln('${all.length} label candidates');
}
