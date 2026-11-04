import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/ui/widgets.dart';
import '../lib/features/home.dart';
import '../lib/features/login.dart';
import '../lib/features/library.dart';
import '../lib/features/recorder.dart';
import '../lib/features/detail.dart';
import '../lib/features/settings.dart';
import '../lib/features/ask.dart';
import '../lib/core/model.dart';
import 'fixtures.dart';

void main() {
  final ios = Platform.environment['TENO_PLATFORM'] == 'ios';
  final boundary = GlobalKey();
  setUpAll(() async {
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  void pageTest(String description, WidgetTesterCallback callback) {
    testWidgets(
      description,
      callback,
      variant: TargetPlatformVariant({
        ios ? TargetPlatform.iOS : TargetPlatform.android,
      }),
    );
  }

  Future<void> mount(
    WidgetTester tester,
    Widget page, {
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    tester.view.padding = ios
        ? const FakeViewPadding(top: 44, bottom: 34)
        : const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: tenoTheme(),
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
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    expect(
      tester.takeException(),
      isNull,
      reason: 'No overflow or framework error on $name',
    );
    final folder = Platform.environment['TENO_SCREENSHOTS'];
    if (folder != null) {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final file = File('$folder/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
    }
  }

  final pages = <String, Widget Function(TenoModel)>{
    '01-home': (m) => HomePage(m),
    '04-library': (m) => HomePage(m),
    '05-folder': (m) => RecordListPage(
      m,
      title: 'Research',
      folder: {
        'id': 'folder-1',
        'data': {'title': 'Research'},
      },
    ),
    '06-search': (m) => SearchPage(m),
    '07-device-connect': (m) => DevicePage(m),
    '14-summary': (m) => DetailPage(m, 'record-1'),
    '18-ask-history': (m) => HomePage(m),
    '19-ask-chat': (m) => ChatPage(m, chatId: 'chat-1'),
    '41-new-chat': (m) => ChatPage(m),
    '20-ask-context': (m) => ContextPicker(m, ['record-1']),
    '23-tools': (m) => HomePage(m),
    '24-template-picker': (m) => TemplatePicker(m),
    '25-template-editor': (m) => TemplateEditor(m, null),
    '29-settings': (m) => HomePage(m),
    '30-preferences': (m) => PreferencesPage(m),
    '32-trash': (m) => TrashPage(m),
    '33-export': (m) => ExportPage(m, 'record-1'),
    '34-login': (m) => LoginPage(m),
    '35-local-files': (m) => LocalListPage(m),
    '36-local-recording': (m) => LocalPage(m, 'local-1'),
    '42-summary-editor': (m) => SummaryEditor(m, 'record-1', reviewSummary, 1),
  };
  for (final page in pages.entries) {
    pageTest('individual page ' + page.key, (tester) async {
      final model = reviewModel();
      addTearDown(model.dispose);
      await mount(tester, page.value(model));
      final section = {
        '04-library': 'Library',
        '18-ask-history': 'Ask Teno',
        '23-tools': 'Tools',
        '29-settings': 'Settings',
      }[page.key];
      if (section != null) {
        await tester.tap(find.byTooltip('Navigation'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(section));
        await tester.pumpAndSettle();
      }
      await capture(tester, page.key);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  pageTest('navigation and create menu retain separate review pages', (
    tester,
  ) async {
    final model = reviewModel();
    addTearDown(model.dispose);
    await mount(tester, HomePage(model));
    await tester.tap(find.byTooltip('Navigation'));
    await tester.pumpAndSettle();
    await capture(tester, '02-navigation');
    Navigator.of(tester.element(find.text('Teno').last)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Create'));
    await tester.pumpAndSettle();
    await capture(tester, '03-create-menu');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  pageTest('transcript and recording controls have separate evidence', (
    tester,
  ) async {
    final model = reviewModel();
    addTearDown(model.dispose);
    await mount(tester, DetailPage(model, 'record-1'));
    await tester.tap(find.text('Audio & transcript'));
    await tester.pumpAndSettle();
    await capture(tester, '15-transcript');
    await tester.tap(find.byTooltip('Edit segment').first);
    await tester.pumpAndSettle();
    await capture(tester, '16-transcript-editor');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Summary'), findsOneWidget);
    expect(find.byTooltip('Edit segment'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await mount(tester, pages['05-folder']!(model));
    await tester.tap(find.byTooltip('Folder options'));
    await tester.pumpAndSettle();
    await capture(tester, '45-folder-options');
    await tester.pumpWidget(const SizedBox.shrink());
    await mount(tester, DevicePage(model));
    model.changed(
      reviewState(sequence: 2, phase: 'recording', connected: true),
    );
    await tester.pumpAndSettle();
    await capture(tester, '08-device-connected');
    await tester.tap(find.text('Return to recording'));
    await tester.pumpAndSettle();
    await capture(tester, '09-recording');
    model.changed(reviewState(sequence: 3, phase: 'paused', connected: true));
    await tester.pumpAndSettle();
    await capture(tester, '10-paused');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  pageTest('narrow screen and larger text remain operable', (tester) async {
    final model = reviewModel();
    addTearDown(model.dispose);
    for (final name in [
      '01-home',
      '07-device-connect',
      '14-summary',
      '19-ask-chat',
      '20-ask-context',
      '24-template-picker',
      '29-settings',
      '30-preferences',
      '32-trash',
      '33-export',
      '34-login',
      '36-local-recording',
    ]) {
      await mount(tester, pages[name]!(model), width: 360, scale: 1.5);
      if (name == '29-settings') {
        await tester.tap(find.byTooltip('Navigation'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
      }
      await capture(tester, 'large-text/$name');
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
  pageTest('recording keyboard and confirmation fit a narrow screen', (
    tester,
  ) async {
    final model = reviewModel();
    addTearDown(model.dispose);
    model.changed(
      reviewState(sequence: 2, phase: 'recording', connected: true),
    );
    await mount(tester, DevicePage(model), width: 360, scale: 1.5);
    await tester.tap(find.text('Return to recording'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    await capture(tester, '11-stop-confirmation');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 310);
    await tester.pumpAndSettle();
    await capture(tester, '37-recording-keyboard');
    await tester.enterText(find.byType(TextField), 'A note while recording');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Close keyboard'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  pageTest(
    'recording interruption, transfer and preview have distinct states',
    (tester) async {
      final model = reviewModel();
      addTearDown(model.dispose);
      var state = reviewState(sequence: 2, phase: 'recording', connected: true);
      model.changed(state);
      await mount(tester, DevicePage(model));
      await tester.tap(find.text('Return to recording'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Live transcript'));
      await tester.pumpAndSettle();
      await capture(tester, '38-live-preview');
      state = reviewState(sequence: 3, phase: 'interrupted');
      state.capture.status =
          'Connection interrupted. Your recorder may still be recording.';
      model.changed(state);
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsNothing);
      await capture(tester, '39-device-interrupted');
      await tester.pumpWidget(const SizedBox.shrink());
      state = reviewState(sequence: 4);
      state.device.receiving = true;
      state.device.busy = true;
      state.device.expectedBytes = 1000;
      state.device.receivedBytes = 600;
      state.device.status = 'Receiving audio · Original stays on your recorder';
      model.changed(state);
      await mount(tester, DevicePage(model));
      await tester.pump(const Duration(milliseconds: 100));
      await capture(tester, '12-device-transfer');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  pageTest('local upload failure never hides the saved recording', (
    tester,
  ) async {
    final model = reviewModel();
    addTearDown(model.dispose);
    final state = reviewState(sequence: 2);
    final drafts = jsonRows(state.draftsJson);
    drafts.first['status'] = 'failed';
    drafts.first['error'] =
        'Connection unavailable. The original audio is kept.';
    state.draftsJson = jsonEncode(drafts);
    model.changed(state);
    await mount(tester, LocalPage(model, 'local-1'));
    await capture(tester, '40-upload-failed');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  pageTest('permission denial and offline library remain actionable', (
    tester,
  ) async {
    final host = FixtureHost()
      ..phoneError =
          'Microphone permission is required. Allow access in Settings and try again.';
    final model = TenoModel(host: host);
    model.changed(host.state);
    addTearDown(model.dispose);
    await mount(tester, HomePage(model));
    await tester.tap(find.byTooltip('Create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record with phone'));
    await tester.pumpAndSettle();
    await capture(tester, '43-microphone-denied');
    expect(host.calls.contains('phone'), isTrue);
    model.error =
        'Connection unavailable. Your recordings are kept on this phone.';
    await tester.pumpWidget(const SizedBox.shrink());
    await mount(tester, HomePage(model));
    await capture(tester, '44-offline-library');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
