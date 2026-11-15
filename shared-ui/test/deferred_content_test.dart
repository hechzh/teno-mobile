import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teno_mobile/ui/deferred_content.dart';
import 'package:teno_mobile/l10n/ui_strings.dart';
import 'package:teno_mobile/ui/mvp_theme.dart';

Widget shell(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('a root loading route uses the bundled Chinese font', (
    tester,
  ) async {
    final pending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        theme: mvpTheme(false),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DeferredContent(
          load: () => pending.future,
          builder: (_) => const Text('Loaded'),
        ),
      ),
    );
    final context = tester.element(find.text('正在加载页面…'));
    expect(
      DefaultTextStyle.of(context).style.fontFamilyFallback,
      contains('NotoSansSC'),
    );
    await tester.pumpWidget(const SizedBox());
    pending.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed page download can retry without replacing the route', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      shell(
        DeferredContent(
          load: () async {
            if (++attempts == 1) throw StateError('offline');
          },
          builder: (_) => const Text('Library content'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Library content'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Library content'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('a late download cannot reopen a disposed page', (tester) async {
    final pending = Completer<void>();
    await tester.pumpWidget(
      shell(
        DeferredContent(
          load: () => pending.future,
          builder: (_) => const Text('Old account page'),
        ),
      ),
    );
    await tester.pumpWidget(shell(const Text('New account')));
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Old account page'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
