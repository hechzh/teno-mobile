import 'dart:convert';
import 'dart:io';
import 'dart:ui' as canvas;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/model.dart';
import '../lib/features/personal_ask.dart';
import '../lib/features/personal_import.dart';
import '../lib/features/personal_notes.dart';
import '../lib/features/personal_settings.dart';
import '../lib/main.dart';
import 'fixtures.dart';
import 'personal_test.dart' show CoreHost, coreModel;

class LanguageHost extends CoreHost {
  String locale = 'en';
  bool rejectLocale = false;
  final importArguments = <String, Json>{};
  @override
  Future<String> platformCommand(String command, String? body) async {
    if (command == 'import' || command == 'accept_imports') {
      importArguments[command] = Map<String, dynamic>.from(jsonDecode(body!));
    }
    if (command != 'interface_locale')
      return super.platformCommand(command, body);
    final args = body == null ? <String, dynamic>{} : jsonDecode(body);
    if (args['locale'] != null) {
      if (rejectLocale)
        throw PlatformException(
          code: 'SAVE',
          message: 'Could not save interface language.',
        );
      locale = args['locale'];
      calls.add('locale:$locale');
    }
    return jsonEncode({'locale': locale});
  }
}

Future<void> chooseLoginLanguage(WidgetTester tester, String label) async {
  await tester.tap(
    find.byKey(const ValueKey('interface-language-switch')).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(CheckedPopupMenuItem<String>, label));
  await tester.pumpAndSettle();
}

Future<void> openLanguageSettings(
  WidgetTester tester, {
  bool wide = false,
}) async {
  await tester.tap(
    find.widgetWithText(wide ? ListTile : NavigationDestination, 'Settings'),
  );
  await tester.pumpAndSettle();
  final entry = find.widgetWithText(ListTile, 'Interface language');
  await tester.scrollUntilVisible(entry, 130);
  await tester.ensureVisible(entry);
  await tester.pumpAndSettle();
  await tester.tap(entry);
  await tester.pumpAndSettle();
}

Future<void> chooseSettingsLanguage(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(RadioListTile<String>, label));
  await tester.pumpAndSettle();
}

Future<void> screenshot(WidgetTester tester, GlobalKey key, String name) async {
  expect(tester.takeException(), isNull, reason: name);
  final directory = Platform.environment['TENO_LANGUAGE_SCREENSHOTS'];
  if (directory == null) return;
  await tester.runAsync(() async {
    final render =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: canvas.ImageByteFormat.png);
    final file = File('$directory/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
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

  for (final view in [
    (360.0, 1.0, false),
    (390.0, 1.0, false),
    (360.0, 1.5, false),
    (1100.0, 1.0, true),
  ]) {
    testWidgets(
      'settings language preserves content and recording ${view.$1}/${view.$2}/web${view.$3}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(view.$1, 900);
        tester.platformDispatcher.textScaleFactorTestValue = view.$2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final host = LanguageHost();
        host.state.capture.phase = 'recording';
        final model = view.$3
            ? (TenoModel(host: host, webExperience: true)
                ..changed(host.state)
                ..personalCore = true)
            : coreModel(host);
        model.interfaceLanguage = 'en';
        final state = model.runtime, owner = model.runtime!.session.scope;
        final preferences = jsonEncode(host.prefs);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: TenoApp(model: model, initialize: false),
          ),
        );
        await tester.pumpAndSettle();
        final shortcut = find.byKey(
          const ValueKey('interface-language-switch'),
        );
        expect(shortcut, findsNothing);
        expect(find.text('Home'), findsWidgets);
        await screenshot(
          tester,
          boundary,
          'home-en-${view.$1.toInt()}-${view.$2}',
        );
        await tester.tap(
          find
              .widgetWithText(
                view.$3 ? ListTile : NavigationDestination,
                'Assistant',
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Keep this question 原文');
        expect(shortcut, findsNothing);
        await openLanguageSettings(tester, wide: view.$3);
        await chooseSettingsLanguage(tester, '简体中文');
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();
        tester.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('外观与语言'), 130);
        await tester.pumpAndSettle();
        expect(find.text('界面语言'), findsOneWidget);
        expect(shortcut, findsNothing);
        await screenshot(
          tester,
          boundary,
          'settings-zh-${view.$1.toInt()}-${view.$2}',
        );
        await tester.tap(
          find.widgetWithText(view.$3 ? ListTile : NavigationDestination, '首页'),
        );
        await tester.pumpAndSettle();
        await screenshot(
          tester,
          boundary,
          'home-zh-${view.$1.toInt()}-${view.$2}',
        );
        await tester.tap(
          find.widgetWithText(view.$3 ? ListTile : NavigationDestination, '助手'),
        );
        await tester.pumpAndSettle();
        expect(find.text('助手'), findsWidgets);
        expect(find.text('Keep this question 原文'), findsOneWidget);
        expect(model.runtime, same(state));
        expect(model.runtime!.session.scope, owner);
        expect(model.runtime!.capture.phase, 'recording');
        expect(jsonEncode(host.prefs), preferences);
        expect(host.requests.where((r) => !r.startsWith('GET ')), isEmpty);
        expect(
          host.calls.where(
            (c) =>
                c.startsWith('configure') ||
                c.startsWith('logout') ||
                c.startsWith('start'),
          ),
          isEmpty,
        );
        final reopened = TenoModel(host: host);
        await reopened.loadInterfaceLanguage();
        expect(reopened.interfaceLanguage, 'zh');
        reopened.dispose();
        await screenshot(
          tester,
          boundary,
          'assistant-zh-${view.$1.toInt()}-${view.$2}',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'login language is available before authentication and keeps form input',
    (tester) async {
      final host = LanguageHost()..state = reviewState(signedIn: false);
      final model = coreModel(host)..interfaceLanguage = 'en';
      await tester.pumpWidget(TenoApp(model: model, initialize: false));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'unchanged.user');
      await tester.enterText(
        find.byType(TextField).at(1),
        'synthetic-only-password',
      );
      await chooseLoginLanguage(tester, '简体中文');
      expect(find.text('用户名'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'unchanged.user',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        'synthetic-only-password',
      );
      expect(host.calls, ['locale:zh']);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'failed locale persistence keeps the prior interface and can retry',
    (tester) async {
      final host = LanguageHost()..rejectLocale = true;
      final model = coreModel(host)..interfaceLanguage = 'en';
      await tester.pumpWidget(TenoApp(model: model, initialize: false));
      await tester.pumpAndSettle();
      await openLanguageSettings(tester);
      await chooseSettingsLanguage(tester, '简体中文');
      expect(model.interfaceLanguage, 'en');
      expect(host.locale, 'en');
      expect(find.text('Could not save interface language.'), findsOneWidget);
      host.rejectLocale = false;
      await chooseSettingsLanguage(tester, '简体中文');
      expect(model.interfaceLanguage, 'zh');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('follow system remains a persistent global option', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('zh', 'CN')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final host = LanguageHost(),
        model = coreModel(host)..interfaceLanguage = 'en';
    await tester.pumpWidget(TenoApp(model: model, initialize: false));
    await tester.pumpAndSettle();
    await openLanguageSettings(tester);
    await chooseSettingsLanguage(tester, 'Follow system');
    expect(host.locale, 'system');
    expect(model.interfaceLanguage, 'system');
    expect(find.text('界面语言'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final web in [false, true]) {
    testWidgets('import uses the selected settings language on web=$web', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final host = LanguageHost();
      final model = web
          ? (TenoModel(host: host, webExperience: true)
              ..changed(host.state)
              ..personalCore = true)
          : coreModel(host);
      model.interfaceLanguage = 'en';
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: TenoApp(model: model, initialize: false),
        ),
      );
      await tester.pumpAndSettle();
      await openLanguageSettings(tester);
      await chooseSettingsLanguage(tester, '简体中文');
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(NavigationDestination, '首页'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('导入文件'));
      await tester.pumpAndSettle();
      expect(find.text('本次模板'), findsOneWidget);
      expect(find.text('输出语言'), findsNothing);
      await screenshot(
        tester,
        boundary,
        'import-zh-${web ? 'web' : 'android'}',
      );
      await tester.tap(find.text('从文件导入'));
      await tester.pumpAndSettle();
      expect(host.importArguments['import'], {
        'source': 'files',
        'template_id': '@default',
        'folder_id': '',
        'output_language': 'zh-CN',
        'output_language_origin': 'interface',
      });
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'template tabs, Chinese search and preview localize without translating custom content',
    (tester) async {
      final host = LanguageHost();
      host.overrides['/api/v1/personal/templates'] = {
        'items': [
          {
            'id': 'teno:meeting',
            'recommended': true,
            'favorite': true,
            'title': 'Meeting notes',
            'title_zh': '会议纪要',
            'description': 'Topics, decisions and next steps.',
            'description_zh': '议题、决策和行动项。',
            'category': 'Meeting',
            'prompt': 'Internal generation instructions stay unchanged.',
            'sections': [
              {'id': 'decisions', 'title': 'Decisions', 'title_zh': '决策'},
            ],
          },
          {
            'id': 'custom-template',
            'recommended': false,
            'favorite': true,
            'title': 'Home',
            'description': 'Original 自建说明',
            'prompt': 'Do not translate my custom instructions.',
            'category': 'General',
          },
        ],
      };
      final original = jsonEncode(host.overrides);
      final model = coreModel(host)..interfaceLanguage = 'zh';
      await tester.pumpWidget(TenoApp(model: model, initialize: false));
      await tester.pumpAndSettle();
      final nav = Navigator.of(tester.element(find.byType(Scaffold).first));
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: PersonalTemplates(
              model,
              collection: 'My templates',
              searching: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('收藏'), findsWidgets);
      expect(find.text('最近使用'), findsOneWidget);
      expect(find.text('我创建的'), findsOneWidget);
      expect(find.text('Favorites'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '会议');
      await tester.pumpAndSettle();
      expect(find.text('会议纪要'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      await tester.tap(find.text('会议纪要'));
      await tester.pumpAndSettle();
      expect(find.text('会议纪要'), findsWidgets);
      expect(find.text('议题、决策和行动项。'), findsWidgets);
      expect(find.text('决策'), findsOneWidget);
      expect(find.text('Meeting notes'), findsNothing);
      expect(
        find.text('Internal generation instructions stay unchanged.'),
        findsNothing,
      );
      expect(jsonEncode(host.overrides), original);
      expect(host.requests.where((r) => r.startsWith('POST ')), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'source counts and import account labels translate while account and filenames stay literal',
    (tester) async {
      final host = LanguageHost();
      host.commandOverrides['pending_imports'] = {
        'items': [
          {'id': 'pending-1', 'title': 'English 原文.pdf'},
        ],
      };
      final model = coreModel(host)..interfaceLanguage = 'zh';
      await tester.pumpWidget(TenoApp(model: model, initialize: false));
      await tester.pumpAndSettle();
      final nav = Navigator.of(tester.element(find.byType(Scaffold).first));
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => PersonalContextPicker(model, const []),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('使用 0 个来源'), findsOneWidget);
      expect(find.text('recording'), findsNothing);
      expect(find.text('录音'), findsWidgets);
      nav.pop();
      await tester.pumpAndSettle();
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => PersonalImportPage(model, pending: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('导入到账号 ${model.runtime!.session.username}'),
        findsOneWidget,
      );
      expect(find.text('English 原文.pdf'), findsOneWidget);
      expect(find.text('输出语言'), findsNothing);
      final accept = find.widgetWithText(FilledButton, '导入文件');
      await tester.ensureVisible(accept);
      await tester.tap(accept);
      await tester.pumpAndSettle();
      expect(
        host.importArguments['accept_imports']?['output_language'],
        'zh-CN',
      );
      expect(
        host.importArguments['accept_imports']?['output_language_origin'],
        'interface',
      );
      expect(host.requests.where((r) => !r.startsWith('GET ')), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('calendar month and weekdays follow the interface locale', (
    tester,
  ) async {
    final host = LanguageHost(),
        model = coreModel(host)..interfaceLanguage = 'zh';
    await tester.pumpWidget(TenoApp(model: model, initialize: false));
    await tester.pumpAndSettle();
    final nav = Navigator.of(tester.element(find.byType(Scaffold).first));
    nav.push(
      MaterialPageRoute<void>(builder: (_) => PersonalCalendarPage(model)),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(PersonalCalendarPage));
    expect(
      find.text(
        MaterialLocalizations.of(context).formatMonthYear(DateTime.now()),
      ),
      findsOneWidget,
    );
    expect(find.text('一'), findsWidgets);
    expect(find.text('Sun'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
