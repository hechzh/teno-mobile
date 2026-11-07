import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/model.dart';
import '../lib/main.dart';
import '../lib/ui/personal_widgets.dart';
import '../lib/features/personal_home.dart';
import '../lib/features/personal_library.dart';
import '../lib/features/personal_import.dart';
import '../lib/features/personal_notes.dart';
import '../lib/features/personal_recording.dart';
import '../lib/features/personal_ask.dart';
import '../lib/features/personal_actions.dart';
import '../lib/features/personal_settings.dart';
import '../lib/features/recorder.dart';
import '../lib/features/login.dart';
import 'fixtures.dart';

// Contract-shaped synthetic fixtures. No production account, audio or private file.
final note = <String, dynamic>{
  'id': 'note-1',
  'type': 'note',
  'title': 'Launch meeting notes',
  'recording_id': 'record-1',
  'revision': 1,
  'source_revision': 1,
  'created_at': '2026-11-07T09:00:00Z',
  'updated_at': '2026-11-07T09:00:00Z',
  'data': {
    'summary':
        'The team reviewed the launch timeline and agreed to clarify the first recording and import experience.',
    'key_points': [
      'Keep the recorder as the primary capture source.',
      'Make imports and automatic processing easy to find.',
    ],
    'action_items': [
      {
        'title': 'Review the onboarding copy.',
        'assignee': null,
        'due_at': null,
      },
    ],
    'sources': [
      {
        'source_id': 'segment-1',
        'type': 'recording',
        'recording_id': 'record-1',
        'start_ms': 0,
        'title': 'Product launch review',
      },
    ],
    'chapters': [
      {'title': 'Launch timeline', 'source_id': 'segment-1'},
    ],
  },
};
final document = <String, dynamic>{
  'id': 'file-1',
  'type': 'file',
  'title': 'Interview notes.txt',
  'filename': 'Interview notes.txt',
  'kind': 'text',
  'mime': 'text/plain',
  'size': 820,
  'status': 'ready',
  'created_at': '2026-11-07T08:00:00Z',
  'updated_at': '2026-11-07T08:00:00Z',
  'pages': [
    {
      'id': 'file:file-1:page:1',
      'page': 1,
      'text':
          'Customers want a clear import entry and automatic transcription after saving a file.',
    },
  ],
};
final content = <Json>[
  for (final r in reviewRecordings)
    {...r, 'type': 'recording', 'updated_at': r['created_at']},
  note,
  document,
  {
    'id': 'folder-1',
    'type': 'folder',
    'title': 'Research',
    'folder_id': null,
    'created_at': '2026-11-07T08:00:00Z',
    'updated_at': '2026-11-07T08:00:00Z',
  },
];

class CoreHost extends FixtureHost {
  final bodies = <String, Json>{};
  final overrides = <String, Json>{};
  final commandOverrides = <String, Json>{};
  List<Json> libraryContent = [...content];
  String heldRoute = '', deniedCommand = '';
  Json prefs = {
    'theme': 'light',
    'notifications': true,
    'clean_transcript': true,
    'speaker_labels': true,
    'favorite_templates': <String>[],
    'recent_templates': <String>[],
  };
  bool offline = false;
  String jobStatus = 'completed';
  @override
  Future<String> platformCommand(String command, String? body) async {
    calls.add('native:$command');
    if (command == deniedCommand)
      throw PlatformException(
        code: 'PERMISSION_REQUIRED',
        message:
            'Calendar permission is required. You can add an event manually.',
      );
    if (commandOverrides.containsKey(command))
      return jsonEncode(commandOverrides[command]);
    return jsonEncode(switch (command) {
      'preferences' => {'personal_core': true, 'app_lock': false},
      'storage' => {'local_bytes': 10485760, 'cache_bytes': 1048576},
      'history' => {
        'items': ['launch', 'timeline'],
      },
      'dictate' => {'text': 'What are the next steps?'},
      _ => {'items': []},
    });
  }

  @override
  Future<String> request(String method, String path, String? body) async {
    if (offline)
      throw PlatformException(
        code: 'CONNECTION',
        message: 'No connection. Local files remain on this phone.',
      );
    final url = Uri.parse(path), route = url.path;
    if (route == heldRoute) return Completer<String>().future;
    if (overrides.containsKey(route)) return jsonEncode(overrides[route]);
    final data = body == null ? <String, dynamic>{} : object(jsonDecode(body));
    bodies['$method $route'] = data;
    if (route == '/api/v1/capabilities') return '{"personal_core":1}';
    if (route == '/api/v1/personal/preferences') {
      if (method == 'PATCH') prefs = {...prefs, ...data};
      return jsonEncode(prefs);
    }
    if (route == '/api/v1/library/items') {
      var values = [...libraryContent];
      final type = url.queryParameters['type'];
      if (type != null)
        values = values
            .where(
              (v) => type == 'imports'
                  ? v['type'] == 'file'
                  : type == 'images'
                  ? v['kind'] == 'image'
                  : v['type'] == type,
            )
            .toList();
      if (url.queryParameters['trash'] == 'true')
        values = [
          {...reviewRecordings[2], 'type': 'recording'},
        ];
      values.sort(
        (a, b) => text(b['created_at']).compareTo(text(a['created_at'])),
      );
      return jsonEncode({'items': values, 'total': values.length});
    }
    if (route == '/api/v1/library/search')
      return jsonEncode({
        'items': [
          {
            'item': content.first,
            'matches': [
              {
                'field': 'transcript',
                'text': 'The launch timeline should be clear.',
                'start_ms': 14000,
                'segment_id': 'segment-2',
              },
            ],
          },
        ],
        'total': 1,
      });
    if (route == '/api/v1/events') return jsonEncode({'items': <Json>[]});
    if (route.endsWith('/notes') && route.startsWith('/api/v1/recordings/'))
      return method == 'GET'
          ? jsonEncode({
              'items': [
                note,
                {...note, 'id': 'note-2', 'title': 'Action items'},
              ],
            })
          : '{"id":"job-1","status":"queued"}';
    if (route.startsWith('/api/v1/notes/'))
      return route.endsWith('/versions')
          ? jsonEncode({
              'items': [note],
            })
          : jsonEncode(note);
    if (route == '/api/v1/notes') return jsonEncode(note);
    if (route == '/api/v1/personal/templates')
      return jsonEncode({
        'items': [
          {
            'id': 'teno:meeting',
            'title': 'Meeting notes',
            'category': 'Meeting',
            'description': 'Decisions, discussion and next steps.',
            'prompt': 'Organize by topics, decisions and actions.',
            'author': 'Teno',
            'recommended': true,
            'favorite': (prefs['favorite_templates'] as List).contains(
              'teno:meeting',
            ),
            'recent': false,
          },
          {
            'id': 'template-1',
            'title': 'Interview insights',
            'category': 'Interview',
            'description': 'Questions, themes and findings.',
            'prompt': 'Keep the evidence and open questions.',
            'author': 'Alex',
            'recommended': false,
            'favorite': false,
            'recent': true,
          },
        ],
      });
    if (route.startsWith('/api/v1/files/')) return jsonEncode(document);
    if (route == '/api/v1/shares')
      return method == 'POST'
          ? '{"id":"share-1","url":"https://example.test/s/synthetic-review-link","expires_at":"2026-11-14T09:00:00Z"}'
          : jsonEncode({
              'items': [
                {
                  'id': 'share-1',
                  'title': 'Launch meeting notes',
                  'expires_at': '2026-11-14T09:00:00Z',
                  'revoked': false,
                },
              ],
            });
    if (route.startsWith('/api/v1/personal/chats'))
      return route.endsWith('/messages')
          ? '{"id":"job-1","status":"queued"}'
          : '{"id":"chat-1"}';
    if (route.startsWith('/api/v1/jobs/'))
      return jsonEncode({
        'id': 'job-1',
        'status': jobStatus,
        'result': {'note_id': 'note-1', 'recording_id': 'record-1'},
        'error': jobStatus == 'failed'
            ? {'message': 'Processing failed. Try again.', 'retryable': true}
            : null,
      });
    if (route == '/api/v1/personal/recordings/record-1/transcript')
      return jsonEncode({
        'revision': 1,
        'available': true,
        'segments': [
          {
            'id': 'segment-1',
            'start_ms': 0,
            'end_ms': 12000,
            'speaker': '1',
            'speaker_name': 'Maya',
            'text':
                'Let’s begin with the launch timeline. The recording flow should be ready for our next review.',
          },
          {
            'id': 'segment-2',
            'start_ms': 14000,
            'end_ms': 22000,
            'speaker': '2',
            'speaker_name': 'Alex',
            'text':
                'We will review onboarding and the export experience together.',
          },
        ],
      });
    if (route.endsWith('/metadata'))
      return '{"source":"import","marks":[],"photos":[]}';
    if (route.endsWith('/waveform'))
      return jsonEncode({
        'peaks': [for (var i = 0; i < 120; i++) (i % 13 + 1) / 20],
      });
    if (route.endsWith('/speakers'))
      return '{"revision":1,"items":[{"label":"1","name":"Maya"},{"label":"2","name":"Alex"}]}';
    return super.request(method, path, body);
  }
}

TenoModel coreModel([CoreHost? host]) {
  final h = host ?? CoreHost();
  final model = reviewModel(h);
  model.personalCore = true;
  model.capabilities = {'personal_core': 1};
  model.personalSettings = h.prefs;
  return model;
}

void main() {
  final boundary = GlobalKey();
  setUpAll(() async {
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  Future<void> mount(
    WidgetTester tester,
    Widget page, {
    bool dark = false,
    double scale = 1,
    double width = 390,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: personalTheme(dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: page,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> screenshot(String name) async {
    final directory = Platform.environment['TENO_PERSONAL_SCREENSHOTS'];
    if (directory == null) return;
    await Future<void>.delayed(Duration.zero);
    final target =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await target.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$directory/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    img.dispose();
  }

  final pages = <String, Widget Function(TenoModel)>{
    '01-home': (m) => PersonalHome(m),
    '04-library': (m) => PersonalHome(m, initialSection: 'Library'),
    '05-recordings': (m) =>
        PersonalListPage(m, title: 'Recordings', type: 'recording'),
    '06-search': (m) => PersonalSearchPage(m),
    '14-recording-notes': (m) => PersonalRecordingPage(m, 'record-1'),
    '15-transcript': (m) =>
        PersonalRecordingPage(m, 'record-1', transcriptOnly: true),
    '17-templates': (m) =>
        CoreFrame(title: 'Tools', child: PersonalTemplates(m)),
    '18-chat-history': (m) =>
        CoreFrame(title: 'Ask Teno', child: PersonalChatHistory(m)),
    '19-new-chat': (m) => PersonalChatPage(m),
    '20-chat-context': (m) => PersonalContextPicker(m, const []),
    '21-settings': (m) =>
        CoreFrame(title: 'Settings', child: PersonalSettings(m)),
    '22-preferences': (m) => PersonalPreferences(m),
    '23-export': (m) =>
        PersonalExportPage(m, {'type': 'recording', 'id': 'record-1'}),
    '24-trash': (m) => PersonalListPage(m, title: 'Trash', trash: true),
    '26-import': (m) => PersonalImportPage(m),
    '27-share': (m) =>
        PersonalSharePage(m, {'type': 'recording', 'id': 'record-1'}),
    '28-calendar': (m) => PersonalCalendarPage(m),
    '32-note': (m) => PersonalNotePage(m, 'note-1'),
    '33-note-editor': (m) => PersonalNoteEditor(m, note: note),
    '34-document': (m) => PersonalFilePage(m, 'file-1'),
    '35-local-files': (m) => PersonalLocalList(m),
    '36-local-recording': (m) => PersonalLocalPage(m, 'local-1'),
    '37-storage': (m) => PersonalStoragePage(m),
    '38-links': (m) => PersonalLinksPage(m),
    '29-photos': (m) => PersonalListPage(m, title: 'Photos', type: 'images'),
    '30-notes': (m) => PersonalListPage(m, title: 'Notes', type: 'note'),
    '31-imports': (m) => PersonalListPage(m, title: 'Imports', type: 'imports'),
    '07-device-connect': (m) => DevicePage(m),
    '09-recording': (m) {
      m.changed(reviewState(phase: 'recording', connected: true));
      return Scaffold(body: RecorderSheet(m));
    },
    '10-paused': (m) {
      m.changed(reviewState(phase: 'paused', connected: true));
      return Scaffold(body: RecorderSheet(m));
    },
    '25-login': (m) => LoginPage(m),
  };
  for (final mode in ['light', 'dark', 'large'])
    for (final entry in pages.entries) {
      testWidgets('personal page ${entry.key} $mode has no layout errors', (
        tester,
      ) async {
        final model = coreModel();
        await mount(
          tester,
          entry.value(model),
          dark: mode == 'dark',
          scale: mode == 'large' ? 1.5 : 1,
          width: mode == 'large' ? 360 : 390,
        );
        expect(tester.takeException(), isNull);
        await tester.runAsync(() => screenshot('$mode/${entry.key}'));
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
      });
    }

  final states = [
    '39-home-empty',
    '40-library-empty',
    '41-library-offline',
    '42-home-loading',
    '43-search-matches',
    '44-library-sort',
    '45-library-select',
    '46-library-create',
    '47-folder-menu',
    '48-recording-options',
    '49-speaker-names',
    '50-find-replace',
    '51-trim-audio',
    '52-transcript-variants',
    '53-template-picker',
    '54-note-versions',
    '55-export-audio',
    '56-calendar-permission',
    '57-document-failed',
    '58-document-processing',
    '59-import-pending',
    '60-import-error',
    '61-note-keyboard',
    '62-processing-failed',
    '63-calendar-upcoming',
    '64-share-created',
  ];
  for (final mode in ['light', 'dark', 'large']) {
    for (final state in states) {
      testWidgets('personal state $state $mode', (tester) async {
        final host = CoreHost();
        Widget Function(TenoModel) page = (m) => PersonalHome(m);
        switch (state) {
          case '39-home-empty':
          case '40-library-empty':
            host.libraryContent = [];
            if (state == '40-library-empty')
              page = (m) =>
                  PersonalListPage(m, title: 'Recordings', type: 'recording');
          case '41-library-offline':
            host.offline = true;
            page = (m) => PersonalListPage(m, title: 'Recordings');
          case '42-home-loading':
            host.heldRoute = '/api/v1/library/items';
          case '43-search-matches':
            page = (m) => PersonalSearchPage(m);
          case '44-library-sort':
          case '45-library-select':
          case '46-library-create':
          case '47-folder-menu':
            page = (m) => PersonalListPage(m, title: 'My files');
          case '48-recording-options':
          case '49-speaker-names':
          case '50-find-replace':
          case '51-trim-audio':
          case '52-transcript-variants':
            page = (m) => PersonalRecordingPage(
              m,
              'record-1',
              transcriptOnly: state == '52-transcript-variants',
            );
          case '53-template-picker':
            page = (m) => PersonalTemplatePicker(m);
          case '54-note-versions':
            page = (m) => PersonalNotePage(m, 'note-1');
          case '55-export-audio':
            page = (m) =>
                PersonalExportPage(m, {'type': 'recording', 'id': 'record-1'});
          case '56-calendar-permission':
            host.deniedCommand = 'calendar';
            page = (m) => PersonalCalendarPage(m);
          case '57-document-failed':
          case '58-document-processing':
            host.overrides['/api/v1/files/file-1'] = {
              ...document,
              'status': state == '57-document-failed' ? 'failed' : 'processing',
              'pages': [],
              'error': {
                'message':
                    'This document is encrypted or damaged. The original file is saved.',
              },
            };
            page = (m) => PersonalFilePage(m, 'file-1');
          case '59-import-pending':
          case '60-import-error':
            host.commandOverrides['pending_imports'] = {
              'items': state == '59-import-pending'
                  ? [
                      {
                        'id': 'pending-1',
                        'title': 'Interview.m4a',
                        'size': 12345,
                      },
                    ]
                  : [],
              'error': state == '60-import-error'
                  ? 'The shared file could not be read. Share it again with read permission.'
                  : '',
            };
            page = (m) => PersonalImportPage(m);
          case '61-note-keyboard':
            page = (m) => PersonalNoteEditor(
              m,
              note: {
                ...note,
                'title':
                    'A long meeting note title that remains editable on a narrow phone',
              },
            );
          case '62-processing-failed':
            host.overrides['/api/v1/personal/recordings/record-1/processing'] = {
              'status': 'failed',
              'job_id': 'job-1',
              'error': {
                'message':
                    'Transcription failed. Your audio is saved. Retry when connected.',
              },
            };
            page = (m) => PersonalRecordingPage(m, 'record-1');
          case '63-calendar-upcoming':
            host.overrides['/api/v1/events'] = {
              'items': [
                {
                  'id': 'event-1',
                  'data': {
                    'title': 'Product review',
                    'starts_at': DateTime.now()
                        .add(const Duration(hours: 2))
                        .toUtc()
                        .toIso8601String(),
                    'ends_at': DateTime.now()
                        .add(const Duration(hours: 3))
                        .toUtc()
                        .toIso8601String(),
                  },
                },
              ],
            };
          case '64-share-created':
            page = (m) =>
                PersonalSharePage(m, {'type': 'recording', 'id': 'record-1'});
        }
        final model = coreModel(host);
        if (state == '39-home-empty') model.runtime!.draftsJson = '[]';
        await mount(
          tester,
          page(model),
          dark: mode == 'dark',
          scale: mode == 'large' ? 1.5 : 1,
          width: mode == 'large' ? 360 : 390,
        );
        Future<void> tapText(String label) async {
          await tester.tap(find.text(label).first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        }

        Future<void> tapTip(String label) async {
          await tester.tap(find.byTooltip(label).first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        }

        switch (state) {
          case '43-search-matches':
            await tester.enterText(find.byType(TextField).first, 'launch');
            await tester.pump(const Duration(milliseconds: 500));
          case '44-library-sort':
            await tapTip('Sort and select');
          case '45-library-select':
            await tapTip('Sort and select');
            await tapText('Select');
            await tester.tap(find.byIcon(Icons.circle_outlined).first);
            await tester.pump();
          case '46-library-create':
            await tapTip('New folder or note');
          case '47-folder-menu':
            await tester.tap(
              find.descendant(
                of: find.byWidgetPredicate(
                  (w) => w is CoreTile && w.item['type'] == 'folder',
                ),
                matching: find.byTooltip('File options'),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          case '48-recording-options':
            await tapTip('Recording options');
          case '49-speaker-names':
            await tapText('2 Speakers');
          case '50-find-replace':
            await tapTip('Recording options');
            await tapText('Find & replace');
          case '51-trim-audio':
            await tapTip('Recording options');
            await tapText('Trim audio');
          case '52-transcript-variants':
            await tapText('Edited text');
          case '54-note-versions':
            await tester.tap(find.byType(PopupMenuButton<String>).first);
            await tester.pumpAndSettle();
            await tapText('Version history');
          case '55-export-audio':
            await tapText('Audio');
          case '56-calendar-permission':
            await tapText('Connect phone calendar');
          case '61-note-keyboard':
            tester.view.viewInsets = const FakeViewPadding(bottom: 280);
            await tester.showKeyboard(find.byType(TextField).last);
            await tester.pump();
          case '64-share-created':
            await tapText('Create link');
        }
        expect(tester.takeException(), isNull);
        await tester.runAsync(() => screenshot('$mode/$state'));
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
      });
    }
  }
  testWidgets(
    'import is available without the old first-recording preference gate',
    (tester) async {
      final host = CoreHost(), model = coreModel();
      model.runtime!.session.optionsSet = false;
      // Use the same host for command assertions.
      model.dispose();
      final actual = coreModel(host);
      actual.runtime!.session.optionsSet = false;
      await mount(tester, PersonalImportPage(actual));
      expect(find.textContaining('Cloud processing is on'), findsOneWidget);
      await tester.tap(find.text('From Files'));
      await tester.pumpAndSettle();
      expect(host.calls, contains('native:import'));
      expect(host.calls.where((v) => v.startsWith('configure')), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      actual.dispose();
    },
  );
  testWidgets('search navigates using nested item ID and timestamp', (
    tester,
  ) async {
    final host = CoreHost(), model = coreModel(host);
    await mount(tester, PersonalSearchPage(model));
    await tester.enterText(find.byType(TextField), 'launch');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('Product launch review'), findsOneWidget);
    await tester.tap(find.text('Product launch review'));
    await tester.pumpAndSettle();
    expect(find.text('Audio & transcript'), findsWidgets);
    expect(host.calls.any((v) => v.contains('record-1')), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });
  testWidgets('sharing defaults exclude raw audio and transcript', (
    tester,
  ) async {
    final host = CoreHost(), model = coreModel(host);
    await mount(
      tester,
      PersonalSharePage(model, {'type': 'recording', 'id': 'record-1'}),
    );
    await tester.tap(find.text('Create link'));
    await tester.pumpAndSettle();
    final body = host.bodies['POST /api/v1/shares']!;
    expect(body['include_audio'], false);
    expect(body['include_transcript'], false);
    expect(body['days'], 7);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });
  testWidgets('voice input fills editable text without submitting a question', (
    tester,
  ) async {
    final host = CoreHost(), model = coreModel(host);
    await mount(tester, PersonalChatPage(model));
    await tester.tap(find.byTooltip('Voice input'));
    await tester.pumpAndSettle();
    expect(find.text('What are the next steps?'), findsWidgets);
    expect(host.bodies.keys.where((v) => v.endsWith('/messages')), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });
  testWidgets(
    'recording can be dragged into a folder from the system directory',
    (tester) async {
      final host = CoreHost(), model = coreModel(host);
      await mount(
        tester,
        PersonalListPage(model, title: 'Recordings', type: 'recording'),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Product launch review')),
      );
      await tester.pump(const Duration(milliseconds: 650));
      expect(find.text('Drop into a folder'), findsOneWidget);
      await gesture.moveTo(tester.getCenter(find.text('Research').last));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pump();
      expect(
        host.bodies['POST /api/v1/library/batch']?['folder_id'],
        'folder-1',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
    },
  );
  testWidgets('Android personal entry is ready while legacy library loading waits', (tester) async {
    final host=CoreHost()..heldRoute='/api/v1/recordings';
    host.state.session.optionsSet=false;
    final model=TenoModel(host:host);
    await mount(tester,TenoApp(model:model));await tester.pump();
    expect(model.personalCore,isTrue);
    expect(find.byType(PersonalHome),findsOneWidget);
    await tester.tap(find.byTooltip('Create'));await tester.pumpAndSettle();
    expect(find.text('Import files'),findsOneWidget);
    expect(host.calls.where((v)=>v.startsWith('configure')),isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final mode in ['light', 'dark', 'large'])
    testWidgets(
      'navigation and creation menus use Teno and expose core destinations $mode',
      (tester) async {
        final model = coreModel();
        await mount(
          tester,
          mode == 'light'
              ? TenoApp(model: model, initialize: false)
              : PersonalHome(model),
          dark: mode == 'dark',
          scale: mode == 'large' ? 1.5 : 1,
          width: mode == 'large' ? 360 : 390,
        );
        await tester.tap(find.byTooltip('Navigation'));
        await tester.pumpAndSettle();
        await tester.runAsync(() => screenshot('$mode/02-navigation'));
        for (final value in ['Work', 'Tasks', 'Skills', 'Connectors', 'PLAUD'])
          expect(find.text(value), findsNothing);
        await tester.tap(find.text('Home'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Create'));
        await tester.pumpAndSettle();
        expect(find.text('Import files'), findsOneWidget);
        await tester.runAsync(() => screenshot('$mode/03-create-menu'));
        await tester.pumpWidget(const SizedBox.shrink());
        if (mode != 'light') model.dispose();
      },
    );
}
