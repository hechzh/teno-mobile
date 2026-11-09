import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/model.dart';
import 'web_recording_test.dart' show NotesHost, openNotes;

class CachedNotesHost extends NotesHost {
  Json cached = {};
  Completer<void>? networkGate, cacheGate;
  String failure = '';
  final saves = <Json>[];

  Future<void> seed() async {
    final base = NotesHost();
    Future<Json> get(String path) async =>
        object(jsonDecode(await base.request('GET', path, null)));
    cached = {
      'record': await get('/api/v1/recordings/record-1'),
      'transcript': await get(
        '/api/v1/personal/recordings/record-1/transcript?variant=edited',
      ),
      'notes': (await get('/api/v1/recordings/record-1/notes'))['items'],
      'metadata': await get('/api/v1/recordings/record-1/metadata'),
      'processing': await get(
        '/api/v1/personal/recordings/record-1/processing',
      ),
      'peaks': [.2, .7, .3],
    };
    (cached['record'] as Json)['title'] = 'Saved recording title';
    (cached['transcript'] as Json)['segments'] = [
      {
        'id': 'saved-segment',
        'text': 'Saved transcript words.',
        'start_ms': 0,
        'end_ms': 1000,
        'speaker': '1',
      },
    ];
  }

  @override
  Future<String> platformCommand(String command, String? body) async {
    if (command != 'recording_cache')
      return super.platformCommand(command, body);
    final args = object(jsonDecode(body!));
    if (args['action'] == 'write') {
      saves.add(args);
      return '{}';
    }
    if (cacheGate != null) await cacheGate!.future;
    return jsonEncode({'token': 'test-token', 'value': cached});
  }

  @override
  Future<String> request(String method, String path, String? body) async {
    if (networkGate != null) await networkGate!.future;
    if (failure.isNotEmpty) throw StateError(failure);
    return super.request(method, path, body);
  }
}

void main() {
  testWidgets(
    'cached text renders while network is pending, then refreshes without recomputing unchanged waveform',
    (tester) async {
      final host = CachedNotesHost();
      await host.seed();
      host.networkGate = Completer();
      await openNotes(tester, host);
      expect(find.text('Saved recording title'), findsOneWidget);
      expect(find.text('Saved copy · Checking for updates…'), findsOneWidget);
      await tester.tap(find.text('Source'));
      await tester.pumpAndSettle();
      expect(find.text('Saved transcript words.'), findsOneWidget);
      host.networkGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Saved recording title'), findsNothing);
      expect(find.text('Saved transcript words.'), findsNothing);
      expect(find.textContaining('Saved copy'), findsNothing);
      expect(host.requests.where((p) => p.endsWith('/waveform')), isEmpty);
      expect(host.saves, isNotEmpty);
    },
  );

  testWidgets(
    'an offline fetch finishing before storage still shows a labelled saved copy',
    (tester) async {
      final host = CachedNotesHost();
      await host.seed();
      host.failure = 'Connection interrupted.';
      host.cacheGate = Completer();
      // Network fails first; storage completes during the fallback grace period.
      Timer(
        const Duration(milliseconds: 200),
        () => host.cacheGate!.complete(),
      );
      await openNotes(tester, host);
      expect(find.text('Saved recording title'), findsOneWidget);
      expect(
        find.text('Saved copy · Could not check for updates'),
        findsOneWidget,
      );
      expect(host.saves, isEmpty);
    },
  );

  testWidgets(
    'deleted or inaccessible data replaces a cached recording with unavailable state',
    (tester) async {
      final host = CachedNotesHost();
      await host.seed();
      host.networkGate = Completer();
      await openNotes(tester, host);
      expect(find.text('Saved recording title'), findsOneWidget);
      host.failure = 'RECORDING_UNAVAILABLE';
      host.networkGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Saved recording title'), findsNothing);
      expect(
        find.text('This recording is no longer available.'),
        findsOneWidget,
      );
      expect(find.textContaining('Saved copy'), findsNothing);
    },
  );

  testWidgets('late IndexedDB results cannot replace fresh server content', (
    tester,
  ) async {
    final host = CachedNotesHost();
    await host.seed();
    host.cacheGate = Completer();
    await openNotes(tester, host);
    expect(find.text('Saved recording title'), findsNothing);
    host.cacheGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Saved recording title'), findsNothing);
    expect(find.textContaining('Saved copy'), findsNothing);
    expect(host.saves, isNotEmpty);
  });

  testWidgets('a changed recording revision invalidates the saved waveform', (
    tester,
  ) async {
    final host = CachedNotesHost();
    await host.seed();
    host.networkGate = Completer();
    (host.cached['record'] as Json)['revision'] = -1;
    await openNotes(tester, host);
    host.networkGate!.complete();
    await tester.pumpAndSettle();
    expect(host.requests.where((p) => p.endsWith('/waveform')), hasLength(1));
  });

  testWidgets(
    'account change immediately removes visible cached private data',
    (tester) async {
      final host = CachedNotesHost();
      await host.seed();
      host.networkGate = Completer();
      final model = await openNotes(tester, host);
      expect(find.text('Saved recording title'), findsOneWidget);
      host.state.session.scope = 'another-account';
      host.state.sequence++;
      model.changed(host.state);
      await tester.pumpAndSettle();
      expect(find.text('Saved recording title'), findsNothing);
      expect(
        find.text('Account changed. Open this recording again.'),
        findsOneWidget,
      );
      host.networkGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Saved recording title'), findsNothing);
    },
  );

  testWidgets('cache availability never changes native recording behavior', (
    tester,
  ) async {
    final host = CachedNotesHost();
    await host.seed();
    await openNotes(tester, host, web: false);
    expect(find.text('Source'), findsOneWidget);
    expect(find.text('Saved recording title'), findsNothing);
    expect(host.saves, isEmpty);
  });
}
