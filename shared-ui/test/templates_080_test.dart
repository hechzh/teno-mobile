import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as canvas;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/model.dart';
import '../lib/features/login.dart';
import '../lib/features/recorder.dart';
import '../lib/features/personal_notes.dart';
import '../lib/features/personal_settings.dart';
import '../lib/ui/personal_widgets.dart';
import '../lib/l10n/ui_strings.dart';
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
  setUpAll(() async {
    for (final font in [
      ('Inter', 'assets/fonts/InterVariable.ttf'),
      ('NotoSansSC', 'assets/fonts/NotoSansSC-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
  });
  for (final language in ['en', 'zh']) {
    for (final width in [360.0, 1100.0]) {
      testWidgets('template picker and account default $language $width', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.reset);
        final host = fixtures.CoreHost();
        final definitions = [
          ('general', 'General notes', '通用笔记'),
          ('meeting', 'Meeting notes', '会议纪要'),
          ('interview', 'Interview insights', '访谈'),
          ('lecture', 'Lecture notes', '课堂'),
          ('inspiration', 'Inspiration', '灵感'),
          ('actions', 'Action items', '待办'),
          ('brief', 'Key insights', '关键见解'),
        ];
        host.overrides['/api/v1/personal/templates'] = {
          'items': [
            for (final t in definitions)
              {
                'id': 'teno:${t.$1}',
                'title': t.$2,
                'title_zh': t.$3,
                'recommended': true,
                'favorite': t.$1 == 'interview',
                'recent': t.$1 == 'meeting',
                'category': 'General',
                'description': 'Synthetic template acceptance',
                'description_zh': '仅整理有原文依据的内容',
                'prompt': 'Only supported source content',
                'version': '1',
                'sections': [],
              },
          ],
        };
        host.prefs['recent_templates'] = ['teno:meeting'];
        host.prefs['favorite_templates'] = ['teno:interview'];
        final model = fixtures.coreModel(host)..interfaceLanguage = language;
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: TenoApp(model: model, initialize: false),
          ),
        );
        await tester.pumpAndSettle();
        final nav = Navigator.of(tester.element(find.byType(Scaffold).first));
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(body: PersonalSettings(model)),
          ),
        );
        await tester.pumpAndSettle();
        final ctx = tester.element(find.byType(PersonalSettings));
        await tester.ensureVisible(find.text(ui(ctx, 'Default note template')));
        await tester.tap(find.text(ui(ctx, 'Default note template')));
        await tester.pumpAndSettle();
        expect(find.byType(PersonalTemplatePicker), findsOneWidget);
        expect(tester.takeException(), isNull);
        final directory = Platform.environment['TENO_TEMPLATE_SCREENSHOTS'];
        if (directory != null)
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: canvas.ImageByteFormat.png,
            );
            final file = File(
              '$directory/templates-$language-${width.toInt()}.png',
            );
            file.parent.createSync(recursive: true);
            file.writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        expect(find.text(ui(ctx, 'Recently used')), findsOneWidget);
        expect(find.text(ui(ctx, 'Favorites')), findsOneWidget);
        final chosen = language == 'zh' ? '会议纪要' : 'Meeting notes';
        await tester.ensureVisible(find.text(chosen).first);
        await tester.tap(find.text(chosen).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(ui(ctx, 'Use this template')));
        await tester.pumpAndSettle();
        expect(host.prefs['default_template_id'], 'teno:meeting');
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final hasNote in [false, true]) {
    testWidgets(
      'settings default and explicit recording template, existing note $hasNote',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 800);
        addTearDown(tester.view.reset);
        final host = fixtures.CoreHost(), model = fixtures.coreModel(host);
        const recordingNotes = '/api/v1/recordings/record-1/notes';
        if (!hasNote) host.overrides[recordingNotes] = {'items': <Json>[]};
        await tester.pumpWidget(TenoApp(model: model, initialize: false));
        await tester.pumpAndSettle();
        final defaultControl = find.text('Default note template');
        expect(defaultControl, findsNothing);
        await tester.tap(
          find.widgetWithText(NavigationDestination, 'Settings'),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(defaultControl);
        expect(defaultControl.hitTestable(), findsOneWidget);
        await tester.tap(defaultControl);
        await tester.pumpAndSettle();
        final defaultCard = find.text('Meeting notes').first;
        await tester.ensureVisible(defaultCard);
        await tester.tap(defaultCard);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Use this template'));
        await tester.pumpAndSettle();
        expect(host.prefs['default_template_id'], 'teno:meeting');
        await tester.tap(find.widgetWithText(NavigationDestination, 'Home'));
        await tester.pumpAndSettle();
        final recording = find.byWidgetPredicate(
          (w) => w is CoreTile && w.item['id'] == 'record-1',
        );
        await tester.scrollUntilVisible(
          recording.hitTestable(),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(recording.hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(
          hasNote ? find.byTooltip('New note') : find.text('Generate'),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PersonalTemplatePicker), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(
          host.requests.where((r) => r == 'POST $recordingNotes'),
          isEmpty,
        );
        await tester.tap(
          hasNote ? find.byTooltip('New note') : find.text('Generate'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Search'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Interview');
        await tester.pumpAndSettle();
        final custom = find.text('Interview insights').hitTestable();
        expect(custom, findsOneWidget);
        await tester.tap(custom);
        await tester.pumpAndSettle();
        expect(
          host.requests.where((r) => r == 'POST $recordingNotes'),
          isEmpty,
        );
        host.overrides.remove(recordingNotes);
        await tester.tap(find.widgetWithText(FilledButton, 'Generate note'));
        await tester.pumpAndSettle();
        final body = host.bodies['POST $recordingNotes']!;
        expect(body['template_id'], 'template-1');
        expect(body.containsKey('note_id'), isFalse);
        expect(host.prefs['default_template_id'], 'teno:meeting');
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
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
