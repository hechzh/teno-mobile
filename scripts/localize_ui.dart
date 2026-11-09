// One-time migration helper. Only app-owned literal UI labels are changed.
import 'dart:convert';
import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class LabelVisitor extends RecursiveAstVisitor<void> {
  final String source;
  final edits = <(int, int, String)>[];
  final labels = <String>{};
  final removedConst = <int>{};
  LabelVisitor(this.source);
  bool literal(Expression e) {
    if (e is StringLiteral && e.stringValue != null) {
      labels.add(e.stringValue!); return true;
    }
    return e is ConditionalExpression && literal(e.thenExpression) && literal(e.elseExpression);
  }
  void runtimeContext(AstNode n) {
    for (AstNode? p = n.parent; p != null; p = p.parent) {
      final token = switch (p) {
        InstanceCreationExpression v => v.keyword,
        ListLiteral v => v.constKeyword,
        SetOrMapLiteral v => v.constKeyword,
        _ => null,
      };
      if (token?.lexeme == 'const' && removedConst.add(token!.offset)) edits.add((token.offset, token.length, ''));
    }
  }
  @override
  void visitNamedArgument(NamedArgument n) {
    if (['tooltip', 'semanticsLabel'].contains(n.name.lexeme) && literal(n.argumentExpression)) {
      edits.add((n.argumentExpression.offset, n.argumentExpression.length, 'ui(context, ${n.argumentExpression.toSource()})'));
      runtimeContext(n);
    }
    super.visitNamedArgument(n);
  }
  @override
  void visitMethodInvocation(MethodInvocation n) {
    if (n.target == null && n.methodName.name == 'Text' && n.argumentList.arguments.isNotEmpty && literal(n.argumentList.arguments.first.argumentExpression)) {
      edits.add((n.methodName.offset, n.methodName.length, 'UiText'));
    }
    if (n.target == null && n.methodName.name == 'InputDecoration') {
      for (final a in n.argumentList.arguments.whereType<NamedArgument>()) {
        final name = a.name.lexeme;
        if (['labelText', 'hintText', 'helperText'].contains(name) && literal(a.argumentExpression)) {
          final field = name == 'labelText' ? 'label' : name == 'hintText' ? 'hint' : 'helper';
          edits.add((a.offset, a.length, '$field: UiText(${a.argumentExpression.toSource()})'));
        }
      }
    }
    super.visitMethodInvocation(n);
  }
  @override
  void visitInstanceCreationExpression(InstanceCreationExpression n) {
    final type = n.constructorName.type.name.lexeme;
    if (type == 'Text' && n.constructorName.name == null && n.argumentList.arguments.isNotEmpty && literal(n.argumentList.arguments.first.argumentExpression)) {
      edits.add((n.constructorName.offset, n.constructorName.length, 'UiText'));
    }
    if (type == 'InputDecoration') {
      for (final a in n.argumentList.arguments.whereType<NamedArgument>()) {
        final name = a.name.lexeme;
        if (['labelText', 'hintText', 'helperText'].contains(name) && literal(a.argumentExpression)) {
          final field = name == 'labelText' ? 'label' : name == 'hintText' ? 'hint' : 'helper';
          edits.add((a.offset, a.length, '$field: UiText(${a.argumentExpression.toSource()})'));
        }
      }
    }
    super.visitInstanceCreationExpression(n);
  }
}
void main(List<String> args) {
  final root = Directory('shared-ui/lib');
  final all = <String>{};
  var count = 0;
  for (final file in root.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart') && !f.path.contains('l10n') && !f.path.contains('generated'))) {
    var source = file.readAsStringSync();
    final parsed = parseString(content: source);
    final visitor = LabelVisitor(source); parsed.unit.accept(visitor);
    all.addAll(visitor.labels);
    if (visitor.edits.isEmpty) continue;
    for (final edit in visitor.edits..sort((a, b) => b.$1.compareTo(a.$1))) {
      source = source.replaceRange(edit.$1, edit.$1 + edit.$2, edit.$3);
    }
    if (!source.contains('part of ') && !source.contains("import '../l10n/ui_strings.dart';") && !source.contains("import 'l10n/ui_strings.dart';")) {
      final path = file.path.replaceAll('\\', '/').substring('shared-ui/lib/'.length);
      source = "import '${path.contains('/') ? '../' : ''}l10n/ui_strings.dart';\n$source";
    }
    file.writeAsStringSync(source); count += visitor.edits.length;
  }
  File('scripts/ui-literal-inventory.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(all.toList()..sort()));
  stdout.writeln('Migrated $count widgets; ${all.length} literal labels.');
}
