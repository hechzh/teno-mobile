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
import '../lib/features/personal_ask.dart';
import '../lib/features/personal_actions.dart';
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
  final requests = <String>[];
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
    requests.add('$method $path');
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
    if (route == '/api/v1/capabilities')
      return '{"personal_core":1,"library_filters":1,"library_stats":1}';
    if (route == '/api/v1/personal/preferences') {
      if (method == 'PATCH') prefs = {...prefs, ...data};
      return jsonEncode(prefs);
    }
    if (route == '/api/v1/library/items') {
      var values = [...libraryContent];
      final collections = [
        for (final kind in ['recording', 'imports', 'images', 'note'])
          {
            'id': kind,
            'count': values
                .where(
                  (v) => kind == 'imports'
                      ? v['type'] == 'file'
                      : kind == 'images'
                      ? v['kind'] == 'image'
                      : v['type'] == kind,
                )
                .length,
            'updated_at': '2026-11-07T09:00:00Z',
          },
      ];
      if (url.queryParameters.containsKey('folder_id')) {
        final folder = url.queryParameters['folder_id'];
        values = values
            .where(
              (v) => folder == ''
                  ? v['folder_id'] == null
                  : v['folder_id'] == folder,
            )
            .toList();
      }
      values = values
          .map(
            (v) => ({
              ...v,
              'folder_title': v['folder_id'] == null
                  ? 'Recordings'
                  : 'Research',
              if (v['type'] == 'folder')
                'child_count': libraryContent
                    .where((c) => c['folder_id'] == v['id'])
                    .length,
            }),
          )
          .toList();
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
      final total = values.length;
      values = values
          .skip(int.tryParse(url.queryParameters['offset'] ?? '0') ?? 0)
          .take(int.tryParse(url.queryParameters['limit'] ?? '100') ?? 100)
          .toList();
      return jsonEncode({
        'items': values,
        'total': total,
        if (url.queryParameters['include_stats'] == 'true')
          'collections': collections,
      });
    }
    if (route == '/api/v1/library/search/options')
      return jsonEncode({
        'folders': [
          {'id': 'folder-1', 'title': 'Research', 'parent_id': null},
        ],
        'types': ['recording', 'note', 'documents', 'images', 'folder'],
        'speakers': ['Alex', 'Maya'],
      });
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
  model.capabilities = {
    'personal_core': 1,
    'library_filters': 1,
    'library_stats': 1,
  };
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
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
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
    if ([
      'light/01-home',
      'light/04-library',
      'light/06-search',
      'light/14-recording-notes',
      'light/17-templates',
      'light/27-share',
    ].contains(name)) {
      final nodes = <Json>[];
      void visit(Element element) {
        final widget = element.widget;
        if (widget is Offstage && widget.offstage) return;
        final render = element.findRenderObject();
        if (render is RenderBox &&
            render.attached &&
            render.hasSize &&
            (widget is CoreAction ||
                widget is AskBar ||
                widget is CoreSurface ||
                widget is Text)) {
          final point = render.localToGlobal(Offset.zero, ancestor: target);
          if (point.dy >= 0 && point.dy < target.size.height) {
            final style = widget is Text
                ? DefaultTextStyle.of(element).style.merge(widget.style)
                : null;
            nodes.add({
              'type': widget.runtimeType.toString(),
              'label': widget is CoreAction
                  ? widget.label
                  : widget is AskBar
                  ? widget.label
                  : widget is Text
                  ? widget.data
                  : null,
              'x': point.dx,
              'y': point.dy,
              'width': render.size.width,
              'height': render.size.height,
              if (style != null) ...{
                'fontSize': style.fontSize,
                'fontWeight': style.fontWeight?.value,
                'lineHeight': style.height,
              },
              if (widget is CoreSurface) 'radius': widget.radius,
            });
          }
        }
        element.visitChildren(visit);
      }

      (boundary.currentContext! as Element).visitChildren(visit);
      final geometry = File('$directory/geometry/$name.json');
      geometry.parent.createSync(recursive: true);
      geometry.writeAsStringSync(
        jsonEncode({
          'logicalWidth': target.size.width,
          'logicalHeight': target.size.height,
          'systemTop': 24,
          'systemBottom': 24,
          'nodes': nodes,
        }),
      );
    }
    final img = await target.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$directory/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    img.dispose();
  }

  Future<void> navigatePage(
    WidgetTester tester,
    TenoModel model,
    String name,
  ) async {
    Future<void> tap(Finder finder) async {
      for (var i = 0; i < 12 && finder.evaluate().isEmpty; i++) {
        final lists = find.byType(ListView);
        if (lists.evaluate().isEmpty) break;
        await tester.drag(lists.last, const Offset(0, -220));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(finder, findsWidgets, reason: 'Navigation target $name');
      await tester.ensureVisible(finder.first);
      await tester.pump();
      await tester.tap(finder.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
    }

    Future<void> label(String value) => tap(find.text(value));
    Future<void> tip(String value) => tap(find.byTooltip(value));
    Future<void> section(String value) async {
      if (value == 'Tools') {
        await tap(find.widgetWithText(NavigationDestination, 'Settings'));
        await label('Templates');
      } else if (value == 'Library') {
        await tap(find.widgetWithText(OutlinedButton, 'Library'));
      } else {
        await tap(
          find.widgetWithText(
            NavigationDestination,
            value == 'Ask Teno' ? 'Assistant' : value,
          ),
        );
      }
    }

    Future<void> detail() async {
      await tap(
        find.byWidgetPredicate(
          (w) => w is CoreTile && w.item['id'] == 'record-1',
        ),
      );
    }

    Future<void> export(String kind) async {
      await detail();
      await tip('Recording options');
      await label('Export as');
      await label(kind == 'Audio' ? 'Export audio' : 'Export transcript');
    }

    switch (name) {
      case '01-home':
      case '25-login':
        break;
      case '04-library':
        await section('Library');
      case '05-recordings':
        await section('Library');
        await label('Recordings');
      case '06-search':
        await tip('Search');
      case '07-device-connect':
        await tip('Start recording');
      case '09-recording':
      case '10-paused':
        await tip('Start recording');
      case '14-recording-notes':
        await detail();
      case '15-transcript':
        await detail();
        await label('Source');
      case '17-templates':
        await section('Tools');
      case '18-chat-history':
        await section('Ask Teno');
        await tip('Chat history');
      case '19-new-chat':
        await section('Ask Teno');
      case '20-chat-context':
        await section('Ask Teno');
        await tip('Add context');
      case '21-settings':
        await section('Settings');
      case '22-preferences':
        await section('Settings');
        await label('Preferences');
      case '23-export':
        await export('Transcript');
      case '55-export-audio':
        await export('Audio');
      case '24-trash':
        await section('Library');
        await tip('Library options');
        await label('Trash');
      case '26-import':
        await label('Import files');
      case '27-share':
        await detail();
        await tip('Share recording');
        await label('Share link');
      case '28-calendar':
        await label('Calendar');
      case '29-photos':
      case '30-notes':
      case '35-local-files':
        await section('Library');
        await tip('My files views');
        await label(
          name == '29-photos'
              ? 'Photos'
              : name == '30-notes'
              ? 'Notes'
              : 'On this phone',
        );
      case '31-imports':
        await section('Library');
        await label('Imports');
      case '32-note':
        await navigatePage(tester, model, '30-notes');
        await label('Launch meeting notes');
      case '33-note-editor':
        await navigatePage(tester, model, '32-note');
        await tip('Note options');
        await label('Edit');
      case '34-document':
        await navigatePage(tester, model, '31-imports');
        await label('Interview notes.txt');
      case '36-local-recording':
        await navigatePage(tester, model, '35-local-files');
        await tap(
          find.byWidgetPredicate(
            (w) => w is CoreTile && w.item['id'] == 'local-1',
          ),
        );
      case '37-storage':
        await section('Settings');
        await label('Storage');
      case '38-links':
        await section('Settings');
        await label('Shared links');
      case '53-template-picker':
        await detail();
        await label('New note');
    }
  }

  final pages = [
    '01-home',
    '04-library',
    '05-recordings',
    '06-search',
    '14-recording-notes',
    '15-transcript',
    '17-templates',
    '18-chat-history',
    '19-new-chat',
    '20-chat-context',
    '21-settings',
    '22-preferences',
    '23-export',
    '24-trash',
    '26-import',
    '27-share',
    '28-calendar',
    '32-note',
    '33-note-editor',
    '34-document',
    '35-local-files',
    '36-local-recording',
    '37-storage',
    '38-links',
    '29-photos',
    '30-notes',
    '31-imports',
    '07-device-connect',
    '09-recording',
    '10-paused',
    '25-login',
  ];
  for (final mode in ['light', 'dark', 'large'])
    for (final pageName in pages) {
      testWidgets('personal page $pageName $mode has no layout errors', (
        tester,
      ) async {
        final model = coreModel();
        if (pageName == '09-recording' || pageName == '10-paused')
          model.changed(
            reviewState(
              phase: pageName == '09-recording' ? 'recording' : 'paused',
              connected: true,
            ),
          );
        await mount(
          tester,
          pageName == '25-login' ? LoginPage(model) : PersonalHome(model),
          dark: mode == 'dark',
          scale: mode == 'large' ? 1.5 : 1,
          width: mode == 'large' ? 360 : 390,
        );
        await navigatePage(tester, model, pageName);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() => screenshot('$mode/$pageName'));
        debugDisableShadows = true;
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
    '65-filter-folder',
    '66-filter-type',
    '67-filter-speaker',
    '68-filter-date',
    '69-search-filtered',
    '70-folder-expanded',
    '71-folder-selected',
    '72-my-files-views',
    '73-share-content',
    '74-my-templates',
    '75-template-search',
    '76-theme',
    '77-notifications',
    '78-account',
    '79-transcription-preferences',
    '80-calendar-actions',
    '81-export-menu',
    '82-search-sort',
    '83-audio-settings',
    '84-transcript-menu',
    '85-calendar-events',
  ];
  for (final mode in ['light', 'dark', 'large']) {
    for (final state in states) {
      testWidgets('personal state $state $mode', (tester) async {
        final host = CoreHost();
        switch (state) {
          case '70-folder-expanded':
          case '71-folder-selected':
            host.libraryContent = [
              for (final i in content)
                {...i, if (i['id'] == 'record-1') 'folder_id': 'folder-1'},
              {
                'id': 'folder-2',
                'type': 'folder',
                'title': 'Interviews',
                'folder_id': 'folder-1',
                'created_at': '2026-11-07T09:00:00Z',
              },
              {
                ...document,
                'id': 'file-child',
                'title': 'Customer interview.txt',
                'folder_id': 'folder-2',
              },
            ];
          case '39-home-empty':
          case '40-library-empty':
            host.libraryContent = [];
          case '41-library-offline':
            host.offline = true;
          case '42-home-loading':
            host.heldRoute = '/api/v1/library/items';
          case '56-calendar-permission':
            host.deniedCommand = 'calendar';
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
          case '62-processing-failed':
            host.overrides['/api/v1/personal/recordings/record-1/processing'] = {
              'status': 'failed',
              'job_id': 'job-1',
              'error': {
                'message':
                    'Transcription failed. Your audio is saved. Retry when connected.',
              },
            };
          case '63-calendar-upcoming':
          case '85-calendar-events':
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
        }
        final model = coreModel(host);
        if (state == '39-home-empty') model.runtime!.draftsJson = '[]';
        await mount(
          tester,
          PersonalHome(model),
          dark: mode == 'dark',
          scale: mode == 'large' ? 1.5 : 1,
          width: mode == 'large' ? 360 : 390,
        );
        final destination = switch (state) {
          '83-audio-settings' || '84-transcript-menu' => '15-transcript',
          '65-filter-folder' ||
          '66-filter-type' ||
          '67-filter-speaker' ||
          '68-filter-date' ||
          '69-search-filtered' ||
          '82-search-sort' => '06-search',
          '70-folder-expanded' ||
          '71-folder-selected' ||
          '72-my-files-views' => '04-library',
          '73-share-content' => '27-share',
          '74-my-templates' || '75-template-search' => '17-templates',
          '76-theme' ||
          '77-notifications' ||
          '78-account' ||
          '79-transcription-preferences' => '21-settings',
          '80-calendar-actions' || '85-calendar-events' => '28-calendar',
          '81-export-menu' => '14-recording-notes',
          '40-library-empty' => '05-recordings',
          '41-library-offline' => '04-library',
          '43-search-matches' => '06-search',
          '44-library-sort' ||
          '45-library-select' ||
          '46-library-create' ||
          '47-folder-menu' => '04-library',
          '48-recording-options' ||
          '49-speaker-names' ||
          '50-find-replace' ||
          '51-trim-audio' ||
          '62-processing-failed' => '14-recording-notes',
          '52-transcript-variants' => '15-transcript',
          '53-template-picker' => '53-template-picker',
          '54-note-versions' => '32-note',
          '55-export-audio' => '55-export-audio',
          '56-calendar-permission' => '28-calendar',
          '57-document-failed' || '58-document-processing' => '34-document',
          '59-import-pending' || '60-import-error' => '26-import',
          '61-note-keyboard' => '33-note-editor',
          '64-share-created' => '27-share',
          _ => '01-home',
        };
        await navigatePage(tester, model, destination);
        Future<void> tapText(String label) async {
          for (var i = 0; i < 10 && find.text(label).evaluate().isEmpty; i++) {
            await tester.drag(
              find.byType(ListView).last,
              const Offset(0, -220),
            );
            await tester.pump(const Duration(milliseconds: 100));
          }
          await tester.ensureVisible(find.text(label).last);
          await tester.pump();
          await tester.tap(find.text(label).last);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        }

        Future<void> tapTip(String label) async {
          await tester.tap(find.byTooltip(label).first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        }

        switch (state) {
          case '83-audio-settings':
            await tester.tap(
              find.byWidgetPredicate(
                (w) =>
                    w is Semantics && w.properties.label == 'Open audio player',
              ),
            );
            await tester.pumpAndSettle();
            await tapTip('Playback speed');
          case '84-transcript-menu':
            await tester.longPress(find.textContaining('Let’s begin').last);
            await tester.pumpAndSettle();
          case '65-filter-folder':
            await tapText('Folder');
          case '66-filter-type':
            await tapText('Type');
          case '67-filter-speaker':
            await tapText('Speaker');
          case '68-filter-date':
            await tapText('Date range');
          case '69-search-filtered':
            await tester.enterText(find.byType(TextField).first, 'launch');
            await tester.pump(const Duration(milliseconds: 500));
            await tapText('Folder');
            await tapText('Research');
            await tapText('Type');
            await tapText('Recordings');
            await tapText('Speaker');
            await tapText('Maya');
          case '70-folder-expanded':
            await tapText('Research');
            await tapText('Interviews');
          case '71-folder-selected':
            await tapTip('Library options');
            await tapText('Select');
            await tapText('Research');
          case '72-my-files-views':
            await tapTip('My files views');
          case '73-share-content':
            await tapText('Choose content to include');
          case '74-my-templates':
            await tapText('My templates');
          case '75-template-search':
            await tapText('Search');
          case '76-theme':
            await tapText('Theme');
          case '77-notifications':
            await tapText('Notifications');
          case '78-account':
            await tapText('Account & security');
          case '79-transcription-preferences':
            await tapText('Preferences');
            await tapText('Transcription & summary');
          case '80-calendar-actions':
            await tapTip('Calendar actions');
          case '81-export-menu':
            await tapTip('Recording options');
            await tapText('Export as');
          case '82-search-sort':
            await tester.enterText(find.byType(TextField).first, 'launch');
            await tester.pump(const Duration(milliseconds: 500));
            await tapTip('Sort search results');
          case '43-search-matches':
            await tester.enterText(find.byType(TextField).first, 'launch');
            await tester.pump(const Duration(milliseconds: 500));
          case '44-library-sort':
            await tapTip('Library options');
          case '45-library-select':
            await tapText('Recordings');
            await tapTip('Library options');
            await tapText('Select');
            await tester.tap(find.byIcon(Icons.circle_outlined).first);
            await tester.pump();
          case '46-library-create':
            await tapTip('New folder or note');
          case '47-folder-menu':
            await tester.tap(
              find.descendant(
                of: find.byWidgetPredicate(
                  (w) => w is CoreTile && w.item['id'] == 'folder-1',
                ),
                matching: find.byTooltip('File options'),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          case '48-recording-options':
            await tapTip('Recording options');
          case '49-speaker-names':
            await tapTip('Recording options');
            await tapText('Name speakers');
          case '50-find-replace':
            await tapTip('Recording options');
            await tapText('Find & replace');
          case '51-trim-audio':
            await tapTip('Recording options');
            await tapText('Trim audio');
          case '52-transcript-variants':
            await tapText('Edited text');
          case '54-note-versions':
            await tester.tap(find.byTooltip('Note options'));
            await tester.pumpAndSettle();
            await tapText('Version history');
          case '55-export-audio':
            break;
          case '56-calendar-permission':
            await tapTip('Calendar actions');
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
        debugDisableShadows = true;
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
      debugDisableShadows = true;
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
    expect(find.text('Source'), findsWidgets);
    expect(host.calls.any((v) => v.contains('record-1')), isTrue);
    debugDisableShadows = true;
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
    await tester.ensureVisible(find.text('Create link'));
    await tester.tap(find.text('Create link'));
    await tester.pumpAndSettle();
    final body = host.bodies['POST /api/v1/shares']!;
    expect(body['include_audio'], false);
    expect(body['include_transcript'], false);
    expect(body['days'], 7);
    debugDisableShadows = true;
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
    debugDisableShadows = true;
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
      debugDisableShadows = true;
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
    },
  );
  testWidgets(
    'Android personal entry is ready while legacy library loading waits',
    (tester) async {
      final host = CoreHost()..heldRoute = '/api/v1/recordings';
      host.state.session.optionsSet = false;
      final model = TenoModel(host: host);
      await mount(tester, TenoApp(model: model));
      await tester.pump();
      expect(model.personalCore, isTrue);
      expect(find.byType(PersonalHome), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Import files'));
      await tester.pumpAndSettle();
      expect(find.text('Import files'), findsOneWidget);
      expect(host.calls.where((v) => v.startsWith('configure')), isEmpty);
      debugDisableShadows = true;
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final mode in ['light', 'dark', 'large'])
    testWidgets('MVP navigation and import expose core destinations $mode', (
      tester,
    ) async {
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
      expect(find.byType(NavigationDestination), findsNWidgets(3));
      await tester.runAsync(() => screenshot('$mode/02-navigation'));
      for (final value in ['Work', 'Tasks', 'Skills', 'Connectors', 'PLAUD'])
        expect(find.text(value), findsNothing);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Import files'));
      await tester.pumpAndSettle();
      expect(find.text('Import files'), findsOneWidget);
      await tester.runAsync(() => screenshot('$mode/03-create-menu'));
      debugDisableShadows = true;
      await tester.pumpWidget(const SizedBox.shrink());
      if (mode != 'light') model.dispose();
    });
}
