import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/model.dart';
import '../lib/features/login.dart';
import '../lib/features/recorder.dart';
import '../lib/main.dart';
import 'fixtures.dart';
import 'personal_test.dart' as fixtures;

class GenerationHost extends fixtures.CoreHost {
  final posted = <Json>[];
  Completer<String> response = Completer<String>();
  @override
  Future<String> request(String method, String path, String? body) {
    if (method == 'POST' && path.endsWith('/notes')) {
      posted.add(object(jsonDecode(body!)));
      return response.future;
    }
    return super.request(method, path, body);
  }
}

void main() {
  testWidgets('signed out UI has no device bypass or automatic scan', (
    tester,
  ) async {
    final host = fixtures.CoreHost()..state = reviewState(signedIn: false);
    final model = fixtures.coreModel(host)..changed(host.state);
    await tester.pumpWidget(TenoApp(model: model, initialize: false));
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Connect a recorder without signing in'), findsNothing);
    await tester.pumpWidget(MaterialApp(home: DevicePage(model)));
    await tester.pumpAndSettle();
    expect(host.calls.where((c) => c == 'device:scan'), isEmpty);
    expect(find.text('Sign in to continue.'), findsOneWidget);
  });
  test(
    'duplicate generation clicks share request and uncertain retry retains identity',
    () async {
      final host = GenerationHost();
      final model = fixtures.coreModel(host);
      const path = '/api/v1/recordings/record-1/notes';
      final a = model.api('POST', path, {
        'client_id': 'first',
        'template_id': 'teno:meeting',
      });
      final b = model.api('POST', path, {
        'client_id': 'second',
        'template_id': 'teno:meeting',
      });
      expect(host.posted.length, 1);
      final failureA = expectLater(a, throwsStateError),
          failureB = expectLater(b, throwsStateError);
      host.response.completeError(StateError('Network interrupted'));
      await failureA;
      await failureB;
      host.response = Completer<String>();
      final retry = model.api('POST', path, {
        'client_id': 'third',
        'template_id': 'teno:meeting',
      });
      expect(host.posted.last['client_id'], 'first');
      host.response.complete('{"id":"existing-job"}');
      expect((await retry)['id'], 'existing-job');
      host.response = Completer<String>();
      final other = model.api('POST', path, {
        'client_id': 'new',
        'template_id': 'teno:lecture',
      });
      expect(host.posted.last['client_id'], 'new');
      host.response.complete('{"id":"new-job"}');
      await other;
    },
  );
}
