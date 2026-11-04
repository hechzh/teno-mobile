import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/main.dart';
import 'fixtures.dart';

class DeferredHost extends FixtureHost {
  final pending = Completer<String>();
  @override
  Future<String> request(String method, String path, String? body) =>
      pending.future;
}

void main() {
  test('late API response cannot expose the previous account data', () async {
    final host = DeferredHost();
    final app = reviewModel(host);
    final pending = app.api('GET', '/api/v1/recordings');
    app.changed(reviewState(sequence: 2, scope: 'new-account'));
    host.pending.complete('{"items":[{"title":"Previous account"}]}');
    await expectLater(pending, throwsStateError);
    expect(app.recordings, isEmpty);
    app.dispose();
  });
  test('out of order snapshots cannot restore an old account', () {
    final model = reviewModel();
    model.changed(reviewState(sequence: 5, scope: 'new-account'));
    model.changed(reviewState(sequence: 4, scope: 'old-account'));
    expect(model.runtime!.session.scope, 'new-account');
    model.dispose();
  });
  testWidgets(
    'new recording keeps JWD primary and never silently starts the microphone',
    (tester) async {
      final host = FixtureHost(), model = reviewModel(host);
      await tester.pumpWidget(TenoApp(model: model, initialize: false));
      await tester.tap(find.byTooltip('Create'));
      await tester.pumpAndSettle();
      expect(find.text('Start recording'), findsOneWidget);
      expect(find.text('Record with phone'), findsOneWidget);
      await tester.tap(find.text('Start recording'));
      await tester.pumpAndSettle();
      expect(find.text('Connect a recorder'), findsOneWidget);
      expect(host.calls.where((call) => call == 'phone'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('navigation exposes only first-release destinations', (
    tester,
  ) async {
    await tester.pumpWidget(TenoApp(model: reviewModel(), initialize: false));
    await tester.tap(find.byTooltip('Navigation'));
    await tester.pumpAndSettle();
    for (final label in ['Home', 'Library', 'Ask Teno', 'Tools', 'Settings'])
      expect(find.text(label), findsWidgets);
    for (final label in [
      'Work',
      'Tasks',
      'Routines',
      'Skills',
      'Connectors',
      'PLAUD',
    ])
      expect(find.text(label), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('account change clears the complete route stack', (tester) async {
    final model = reviewModel();
    await tester.pumpWidget(TenoApp(model: model, initialize: false));
    await tester.tap(find.byTooltip('Create'));
    await tester.pumpAndSettle();
    model.changed(reviewState(sequence: 2, signedIn: false));
    await tester.pumpAndSettle();
    expect(find.text('Start recording'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
