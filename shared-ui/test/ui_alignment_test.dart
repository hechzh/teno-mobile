import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/calendar_view.dart';
import '../lib/core/model.dart';
import '../lib/main.dart';
import '../lib/features/personal_actions.dart';
import '../lib/features/personal_import.dart';
import '../lib/features/personal_library.dart';
import '../lib/features/personal_recording.dart';
import '../lib/platform/runtime.g.dart';
import '../lib/ui/personal_widgets.dart';
import '../lib/ui/widgets.dart';
import 'personal_test.dart' as fixture;

class SearchHost extends fixture.CoreHost {
  final searches = <Uri>[];
  final delayed = Completer<String>();
  bool delayFirst = false;
  @override
  Future<String> request(String method, String path, String? body) async {
    final uri = Uri.parse(path);
    if (uri.path == '/api/v1/library/search') {
      searches.add(uri);
      if (delayFirst && uri.queryParameters['q'] == 'first')
        return delayed.future;
      final offset = int.parse(uri.queryParameters['offset'] ?? '0');
      return jsonEncode({
        'total': 51,
        'items': [
          for (var i = offset; i < (offset == 0 ? 50 : 51); i++)
            {
              'item': {
                'id': 'result-$i',
                'title': '${uri.queryParameters['q']} result $i',
                'type': 'recording',
                'created_at': '2026-11-07T09:00:00Z',
              },
              'matches': [],
            },
        ],
      });
    }
    return super.request(method, path, body);
  }
}

class PlaybackHost extends fixture.CoreHost {
  final actions = <Json>[];
  @override
  Future<void> playback(
    PlaybackAction action,
    String mediaId,
    bool local,
    int positionMs,
    double speed,
  ) async {
    actions.add({
      'action': action.name,
      'id': mediaId,
      'position': positionMs,
      'speed': speed,
    });
    state.playback.speed = speed;
  }
}

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target.last);
  await tester.pumpAndSettle();
  await tester.tap(target.last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets(
    'Android signed-out app uses the shared controls before capabilities load',
    (tester) async {
      final model = fixture.coreModel();
      model.personalCore = false;
      model.runtime!.session.signedIn = false;
      await tester.pumpWidget(TenoApp(model: model, initialize: false));
      await tester.pumpAndSettle();
      final input = find.byType(TextField).first;
      await tester.tap(input);
      await tester.pumpAndSettle();
      final actual = Theme.of(tester.element(input)).inputDecorationTheme;
      expect(
        actual.focusedBorder!.borderSide,
        personalTheme(false).inputDecorationTheme.focusedBorder!.borderSide,
      );
      expect(find.text('Sign in'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  Future<void> mount(WidgetTester tester, TenoModel model, Widget page) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: personalTheme(false), home: page),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
    });
  }

  testWidgets(
    'combined filters persist across pagination and reset offset when changed',
    (tester) async {
      final host = SearchHost(), model = fixture.coreModel();
      model.dispose();
      final actual = fixture.coreModel(host);
      await mount(tester, actual, PersonalSearchPage(actual));
      await tester.enterText(find.byType(TextField), 'launch');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      for (final choice in [
        ('Folder', 'Research'),
        ('Type', 'Recordings'),
        ('Speaker', 'Maya'),
      ]) {
        await tap(tester, find.text(choice.$1));
        await tap(tester, find.widgetWithText(ListTile, choice.$2));
      }
      expect(
        host.searches.last.queryParameters,
        containsPair('folder_id', 'folder-1'),
      );
      expect(
        host.searches.last.queryParameters,
        containsPair('type', 'recording'),
      );
      expect(
        host.searches.last.queryParameters,
        containsPair('speaker', 'Maya'),
      );
      await tester.scrollUntilVisible(
        find.text('Load more'),
        450,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
        maxScrolls: 30,
      );
      await tap(tester, find.text('Load more'));
      expect(host.searches.last.queryParameters, containsPair('offset', '50'));
      expect(
        host.searches.last.queryParameters,
        containsPair('speaker', 'Maya'),
      );
      expect(find.text('launch result 50'), findsOneWidget);
      await tap(tester, find.text('Maya'));
      await tap(tester, find.widgetWithText(ListTile, 'Any speaker'));
      expect(host.searches.last.queryParameters['offset'], '0');
      expect(host.searches.last.queryParameters.containsKey('speaker'), false);
      expect(host.searches.last.queryParameters['folder_id'], 'folder-1');
    },
  );

  testWidgets(
    'date range sends local midnight through exclusive next midnight',
    (tester) async {
      final host = SearchHost(), model = fixture.coreModel();
      model.dispose();
      final actual = fixture.coreModel(host);
      await mount(tester, actual, PersonalSearchPage(actual));
      await tap(tester, find.text('Date range'));
      await tap(tester, find.text('Choose dates'));
      await tap(tester, find.byTooltip('Switch to input'));
      final fields = find.descendant(
        of: find.byType(DateRangePickerDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), '11/7/2026');
      await tester.enterText(fields.at(1), '11/8/2026');
      await tap(tester, find.text('Save'));
      final params = host.searches.last.queryParameters;
      expect(
        DateTime.parse(params['date_from']!),
        DateTime(2026, 11, 7).toUtc(),
      );
      expect(DateTime.parse(params['date_to']!), DateTime(2026, 11, 9).toUtc());
      expect(params['q'], '');
    },
  );

  testWidgets(
    'old backend hides unsupported filters and sends legacy parameters',
    (tester) async {
      final host = SearchHost(),
          model = fixture.coreModel(host)..capabilities = {'personal_core': 1};
      await mount(tester, model, PersonalSearchPage(model));
      for (final label in ['Folder', 'Type', 'Speaker', 'Date range']) {
        expect(find.text(label), findsNothing);
      }
      expect(
        host.requests.where((r) => r.contains('/search/options')),
        isEmpty,
      );
      await tester.enterText(find.byType(TextField), 'launch');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(host.searches.single.queryParameters.keys.toSet(), {
        'q',
        'sort',
        'limit',
        'offset',
      });
    },
  );

  testWidgets('late search response cannot replace the newer query', (
    tester,
  ) async {
    final host = SearchHost()..delayFirst = true, model = fixture.coreModel();
    model.dispose();
    final actual = fixture.coreModel(host);
    await mount(tester, actual, PersonalSearchPage(actual));
    await tester.enterText(find.byType(TextField), 'first');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'second');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    host.delayed.complete(jsonEncode({'total': 0, 'items': []}));
    await tester.pumpAndSettle();
    expect(find.text('second result 0'), findsOneWidget);
    expect(find.text('51 results'), findsOneWidget);
  });

  testWidgets(
    'folder selection edits the folder without a file batch mutation',
    (tester) async {
      final host = fixture.CoreHost(), model = fixture.coreModel(host);
      await mount(tester, model, PersonalListPage(model, title: 'Library'));
      await tap(tester, find.byTooltip('Sort and select'));
      await tap(tester, find.text('Select'));
      await tap(tester, find.text('Research'));
      await tap(tester, find.text('Edit'));
      await tester.enterText(find.byType(TextField), 'Interviews');
      await tap(tester, find.text('Save'));
      expect(
        host.bodies['PATCH /api/v1/library/items/folder/folder-1']?['title'],
        'Interviews',
      );
      expect(host.bodies.containsKey('POST /api/v1/library/batch'), false);
    },
  );

  testWidgets(
    'share content cancellation preserves scope and confirmation pins selected note',
    (tester) async {
      final host = fixture.CoreHost(), model = fixture.coreModel(host);
      await mount(
        tester,
        model,
        PersonalSharePage(model, {
          'id': 'record-1',
          'type': 'recording',
        }, noteId: 'note-1'),
      );
      await tap(tester, find.text('Choose content to include'));
      await tap(tester, find.widgetWithText(CheckboxListTile, 'Audio'));
      await tap(tester, find.byTooltip('Close'));
      expect(find.text('1 selected'), findsOneWidget);
      await tap(tester, find.text('Choose content to include'));
      await tap(tester, find.widgetWithText(CheckboxListTile, 'Transcript'));
      await tap(tester, find.text('Done'));
      expect(find.text('2 selected'), findsOneWidget);
      await tap(tester, find.text('Create link'));
      final body = host.bodies['POST /api/v1/shares']!;
      expect(body['note_id'], 'note-1');
      expect(body['include_summary'], true);
      expect(body['include_transcript'], true);
      expect(body['include_audio'], false);
      expect(
        find
                .widgetWithText(ListTile, 'Choose content to include')
                .evaluate()
                .single
                .widget
            is ListTile,
        true,
      );
      expect(
        tester
            .widget<ListTile>(
              find.widgetWithText(ListTile, 'Choose content to include'),
            )
            .onTap,
        isNull,
      );
    },
  );

  testWidgets(
    'cancelled import remains usable and permission error does not discard saved data',
    (tester) async {
      final host = fixture.CoreHost(), model = fixture.coreModel(host);
      await mount(tester, model, PersonalImportPage(model));
      await tap(tester, find.text('From Files'));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Saved on this phone'), findsNothing);
      host.deniedCommand = 'import';
      await tap(tester, find.text('From Photos'));
      expect(find.byType(ErrorNotice), findsOneWidget);
      expect(host.calls.where((r) => r == 'native:discard_imports'), isEmpty);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'transcript timestamps, forward skip and speed sheet call playback with real positions',
    (tester) async {
      final host = PlaybackHost(), model = fixture.coreModel(host);
      await mount(
        tester,
        model,
        PersonalRecordingPage(model, 'record-1', transcriptOnly: true),
      );
      await tap(tester, find.text('00:00:14'));
      expect(host.actions.last['position'], 14000);
      expect(host.actions.last['id'], 'record-1');
      await tap(
        tester,
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Open audio player',
        ),
      );
      await tap(tester, find.byTooltip('Forward 15 seconds'));
      expect(host.actions.last['position'], 15000);
      await tap(tester, find.byTooltip('Playback speed'));
      expect(find.text('Audio settings'), findsOneWidget);
      await tap(tester, find.text('1.75×'));
      expect(host.actions.last['speed'], 1.75);
      expect(host.actions.last['action'], 'speed');
    },
  );

  test(
    'calendar splits local overnight events but excludes a midnight endpoint',
    () {
      final start = DateTime(2026, 11, 7, 23), end = DateTime(2026, 11, 9);
      final agenda = calendarAgenda(
        [
          {
            'id': 'event',
            'data': {
              'starts_at': start.toUtc().toIso8601String(),
              'ends_at': end.toUtc().toIso8601String(),
            },
          },
        ],
        DateTime(2026, 11, 7),
        DateTime(2026, 11, 11),
      );
      expect(agenda.keys.toList(), [
        DateTime(2026, 11, 7),
        DateTime(2026, 11, 8),
      ]);
      expect(agenda.values.first.single['continues_after'], true);
      expect(agenda.values.last.single['continues_before'], true);
    },
  );
  test('calendar normalizes offset timestamps and bounds long events', () {
    final start = DateTime.parse('2026-11-07T23:30:00-08:00');
    final end = DateTime.parse('2027-11-08T09:00:00+09:00');
    final day = calendarDay(start.toLocal());
    final agenda = calendarAgenda(
      [
        {
          'id': 'event',
          'data': {
            'starts_at': start.toIso8601String(),
            'ends_at': end.toIso8601String(),
          },
        },
      ],
      day,
      DateTime(day.year, day.month, day.day + 3),
    );
    expect(agenda.length, 3);
    expect(agenda.values.first.single['local_start'], start.toLocal());
  });
  test(
    'calendar preserves zero-duration events and rejects invalid backwards dates',
    () {
      final day = DateTime(2026, 11, 8);
      final agenda = calendarAgenda(
        [
          {
            'id': 'instant',
            'data': {
              'starts_at': day.toIso8601String(),
              'ends_at': day.toIso8601String(),
            },
          },
          {
            'id': 'invalid',
            'data': {
              'starts_at': day.toIso8601String(),
              'ends_at': day
                  .subtract(const Duration(days: 1))
                  .toIso8601String(),
            },
          },
        ],
        day,
        DateTime(2026, 11, 9),
      );
      expect(agenda[day]!.map((v) => v['id']).toList(), ['instant']);
    },
  );
}
