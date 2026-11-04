import 'dart:io';
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
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
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
    '04-library': (m) => PageFrame(title: 'Library', child: LibraryBody(m)),
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
    '18-ask-history': (m) =>
        PageFrame(title: 'Ask Teno', child: AskHistoryBody(m)),
    '19-ask-chat': (m) => ChatPage(m, chatId: 'chat-1'),
    '20-ask-context': (m) => ContextPicker(m, ['record-1']),
    '23-tools': (m) => PageFrame(title: 'Tools', child: TemplatesBody(m)),
    '24-template-picker': (m) => TemplatePicker(m),
    '25-template-editor': (m) => TemplateEditor(m, null),
    '29-settings': (m) => PageFrame(title: 'Settings', child: SettingsBody(m)),
    '30-preferences': (m) => PreferencesPage(m),
    '32-trash': (m) => TrashPage(m),
    '33-export': (m) => ExportPage(m, 'record-1'),
    '34-login': (m) => LoginPage(m),
    '35-local-files': (m) => LocalListPage(m),
    '36-local-recording': (m) => LocalPage(m, 'local-1'),
  };
  for (final page in pages.entries) {
    testWidgets('individual page ' + page.key, (tester) async {
      final model = reviewModel();
      addTearDown(model.dispose);
      await mount(tester, page.value(model));
      await capture(tester, page.key);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('navigation and create menu retain separate review pages', (
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
  testWidgets('transcript and recording controls have separate evidence', (
    tester,
  ) async {
    final model = reviewModel();
    addTearDown(model.dispose);
    await mount(tester, DetailPage(model, 'record-1'));
    await tester.tap(find.text('Transcript'));
    await tester.pumpAndSettle();
    await capture(tester, '15-transcript');
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
  testWidgets('narrow screen and larger text remain operable', (tester) async {
    final model = reviewModel();
    addTearDown(model.dispose);
    for (final name in [
      '01-home',
      '14-summary',
      '19-ask-chat',
      '29-settings',
      '30-preferences',
      '34-login',
    ]) {
      await mount(tester, pages[name]!(model), width: 360, scale: 1.5);
      await capture(tester, 'large-text/$name');
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
