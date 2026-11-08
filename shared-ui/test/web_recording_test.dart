import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/model.dart';
import '../lib/platform/runtime.g.dart';
import '../lib/features/personal_recording.dart';
import '../lib/features/personal_notes.dart';
import '../lib/features/personal_ask.dart';
import '../lib/ui/personal_widgets.dart';
import 'personal_test.dart' show CoreHost, note;
import 'fixtures.dart';

class NotesHost extends CoreHost {
  bool sharesUnavailable = false;
  final playbackCalls = <(PlaybackAction, String, int)>[];
  @override
  Future<String> request(String method, String path, String? body) {
    if (sharesUnavailable && path == '/api/v1/shares') {
      return Future.error(StateError('Unavailable'));
    }
    return super.request(method, path, body);
  }

  @override
  Future<void> playback(
    PlaybackAction action,
    String mediaId,
    bool local,
    int positionMs,
    double speed,
  ) async {
    playbackCalls.add((action, mediaId, positionMs));
  }
}

Json copyNote() => jsonDecode(jsonEncode(note)) as Json;

Future<TenoModel> openNotes(
  WidgetTester tester,
  NotesHost host, {
  bool web = true,
  bool dark = false,
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  host.state = reviewState();
  final model = TenoModel(host: host, webExperience: web)..changed(host.state);
  model.personalCore = true;
  addTearDown(model.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: personalTheme(dark, webExperience: web),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: PersonalRecordingPage(model, 'record-1'),
    ),
  );
  await tester.pumpAndSettle();
  return model;
}

void main() {
  testWidgets(
    'Web reading page preserves all generated content and real topics',
    (tester) async {
      final host = NotesHost();
      await openNotes(tester, host);
      expect(find.text('At a glance'), findsOneWidget);
      expect(find.text(object(note['data'])['summary']), findsOneWidget);
      expect(find.text('1 topic'), findsOneWidget);
      expect(
        find.text('Keep the recorder as the primary capture source.'),
        findsOneWidget,
      );
      expect(
        find.text('Make imports and automatic processing easy to find.'),
        findsOneWidget,
      );
      expect(find.text('Review the onboarding copy.'), findsOneWidget);
      expect(find.text('Transcript excerpt'), findsOneWidget);
      await tester.tap(find.text('Topics'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Launch timeline'));
      await tester.pumpAndSettle();
      expect(find.text('Launch timeline').hitTestable(), findsOneWidget);
      expect(find.byTooltip('Play recording').hitTestable(), findsOneWidget);
      expect(host.requests.where((r) => !r.startsWith('GET ')), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('native keeps its existing recording layout', (tester) async {
    await openNotes(tester, NotesHost(), web: false);
    expect(find.text('At a glance'), findsNothing);
    expect(find.text('Audio & transcript'), findsOneWidget);
    expect(find.byTooltip('Play recording'), findsNothing);
  });

  for (final stale in [true, false]) {
    testWidgets('old note never quotes a newer transcript (stale=$stale)', (
      tester,
    ) async {
      final host = NotesHost(), older = copyNote();
      older['source_revision'] = 0;
      older['stale'] = stale;
      host.overrides['/api/v1/recordings/record-1/notes'] = {
        'items': [older],
      };
      await openNotes(tester, host);
      expect(find.text('Transcript excerpt'), findsNothing);
      expect(
        find.textContaining('retains its earlier version'),
        stale ? findsOneWidget : findsNothing,
      );
    });
  }

  testWidgets(
    'manual body is not duplicated as an invented overview or topics',
    (tester) async {
      final host = NotesHost(), manual = copyNote();
      manual['data'] = {
        'body': 'Saved manual note.',
        'summary': 'Saved manual note.',
      };
      host.overrides['/api/v1/recordings/record-1/notes'] = {
        'items': [manual],
      };
      await openNotes(tester, host);
      expect(find.text('Saved manual note.'), findsOneWidget);
      expect(find.text('At a glance'), findsNothing);
      expect(find.text('Topics'), findsNothing);
    },
  );

  for (final state in ['active', 'expired', 'revoked', 'unavailable']) {
    testWidgets('privacy label follows actual $state share state', (
      tester,
    ) async {
      final host = NotesHost()..sharesUnavailable = state == 'unavailable';
      host.overrides['/api/v1/shares'] = {
        'items': [
          {
            'source_type': 'note',
            'source_id': 'note-1',
            'revoked': state == 'revoked',
            'expires_at': DateTime.now()
                .add(Duration(days: state == 'expired' ? -1 : 1))
                .toUtc()
                .toIso8601String(),
          },
        ],
      };
      await openNotes(tester, host);
      expect(
        find.text('Shared'),
        state == 'active' ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Private'),
        ['expired', 'revoked'].contains(state) ? findsOneWidget : findsNothing,
      );
    });
  }

  testWidgets('note selection edits latest selected note, not previous note', (
    tester,
  ) async {
    final host = NotesHost();
    final selected = {
      ...copyNote(),
      'id': 'note-2',
      'title': 'Action items',
      'revision': 3,
    };
    host.overrides['/api/v1/notes/note-2'] = selected;
    await openNotes(tester, host);
    await tester.ensureVisible(find.text('Launch meeting notes'));
    await tester.tap(find.text('Launch meeting notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Action items'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(host.requests, contains('GET /api/v1/notes/note-2'));
    final editor = tester.widget<PersonalNoteEditor>(
      find.byType(PersonalNoteEditor),
    );
    expect(editor.note?['id'], 'note-2');
    expect(editor.note?['revision'], 3);
  });

  testWidgets('viewing saved versions does not change current note revision', (
    tester,
  ) async {
    final host = NotesHost();
    host.overrides['/api/v1/notes/note-1/versions'] = {
      'items': [
        {
          ...copyNote(),
          'revision': 4,
          'selected_revision': 2,
          'data': {'body': 'Earlier saved wording.'},
        },
      ],
    };
    await openNotes(tester, host);
    await tester.ensureVisible(find.text('Version'));
    await tester.tap(find.text('Version'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Version 2'));
    await tester.pumpAndSettle();
    expect(find.text('Earlier saved wording.'), findsOneWidget);
    await tester.tap(find.byTooltip('Close panel'));
    await tester.pumpAndSettle();
    expect(find.text('Full note · v1'), findsOneWidget);
    expect(host.requests.where((r) => !r.startsWith('GET ')), isEmpty);
  });

  testWidgets(
    'source opens transcript and playback progress updates the fixed dock',
    (tester) async {
      final host = NotesHost();
      final model = await openNotes(tester, host);
      await tester.ensureVisible(find.text('View source'));
      await tester.tap(find.text('View source'));
      await tester.pumpAndSettle();
      expect(host.playbackCalls.single, (PlaybackAction.play, 'record-1', 0));
      expect(find.text('At a glance'), findsNothing);
      host.state.playback = PlaybackState(
        ready: true,
        playing: true,
        positionMs: 12000,
        durationMs: 1458000,
        speed: 1,
        mediaId: 'record-1',
        error: '',
      );
      model.changed(host.state);
      await tester.pumpAndSettle();
      expect(find.text('00:12 / 24:18'), findsOneWidget);
      await tester.tap(find.byTooltip('Pause recording'));
      await tester.pumpAndSettle();
      expect(host.playbackCalls.last, (
        PlaybackAction.pause,
        'record-1',
        12000,
      ));
      await tester.tap(find.text('Ask Teno'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PersonalChatPage>(find.byType(PersonalChatPage)).initial,
        [
          {'type': 'recording', 'id': 'record-1'},
        ],
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final setup in [(false, 1.0), (true, 1.0), (false, 1.5), (true, 1.5)]) {
    testWidgets('360dp reading and panels have no overflow: $setup', (
      tester,
    ) async {
      await openNotes(tester, NotesHost(), dark: setup.$1, scale: setup.$2);
      tester.view.physicalSize = const Size(360, 800);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Topics'));
      await tester.tap(find.text('Topics'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close panel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transcript'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
