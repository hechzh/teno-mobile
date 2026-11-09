import 'dart:convert';
import 'dart:io';
import 'dart:ui' as canvas;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/model.dart';
import '../lib/main.dart';
import '../lib/l10n/ui_strings.dart';
import '../lib/features/personal_home.dart';
import '../lib/ui/personal_widgets.dart';
import 'personal_test.dart' show CoreHost, coreModel;

class LocaleHost extends CoreHost {
  String locale = 'system';
  @override
  Future<String> platformCommand(String command, String? body) async {
    if (command == 'interface_locale') {
      final data = body == null ? <String, dynamic>{} : jsonDecode(body);
      if (data['locale'] != null) locale = data['locale'];
      calls.add('locale:$locale');
      return jsonEncode({'locale': locale});
    }
    return super.platformCommand(command, body);
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
  testWidgets(
    'locale persists independently and switching keeps navigation, input and playback session',
    (tester) async {
      final host = LocaleHost(), model = coreModel(host);
      host.state.capture.phase = 'recording';
      final owner = model.runtime!.session.scope;
      await tester.pumpWidget(TenoApp(model: model, initialize: false));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(NavigationDestination, 'Assistant'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Keep this original question 原文',
      );
      final runtime = model.runtime;
      await model.setInterfaceLanguage('zh');
      await tester.pumpAndSettle();
      expect(find.text('助手'), findsWidgets);
      expect(find.text('Keep this original question 原文'), findsOneWidget);
      expect(model.runtime, same(runtime));
      expect(model.runtime!.session.scope, owner);
      expect(
        host.calls.where(
          (v) =>
              v.startsWith('configure') ||
              v.startsWith('start') ||
              v.startsWith('logout'),
        ),
        isEmpty,
      );
      final reopened = TenoModel(host: host);
      await reopened.loadInterfaceLanguage();
      expect(reopened.interfaceLanguage, 'zh');
      reopened.dispose();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final web in [false, true]) {
    for (final locale in ['en', 'zh']) {
      for (final mode in [
        'light',
        'dark',
        'large',
        if (web) ...['tablet', 'desktop', 'wide', 'landscape'],
      ]) {
        testWidgets(
          'MVP ${web ? 'web' : 'android'} $locale $mode actual navigation',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(switch (mode) {
              'large' => 360,
              'tablet' => 768,
              'desktop' => 1280,
              'wide' => 1440,
              'landscape' => 844,
              _ => 390,
            }, mode == 'landscape' ? 390 : 844);
            addTearDown(tester.view.reset);
            tester.platformDispatcher.textScaleFactorTestValue = mode == 'large'
                ? 1.5
                : 1;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final host = LocaleHost();
            final model = web
                ? (TenoModel(host: host, webExperience: true)
                    ..changed(host.state)
                    ..personalCore = true
                    ..capabilities = {'library_stats': 1, 'library_filters': 1})
                : coreModel(host);
            model.interfaceLanguage = locale;
            model.personalSettings = {
              ...host.prefs,
              'theme': mode == 'dark' ? 'dark' : 'light',
            };
            final boundary = GlobalKey();
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: TenoApp(model: model, initialize: false),
              ),
            );
            await tester.pumpAndSettle();
            String label(String source) => ui(
              tester.element(find.byType(PersonalHome, skipOffstage: false)),
              source,
            );
            Finder navigation(String title) => find.widgetWithText(
              ['desktop', 'wide'].contains(mode)
                  ? ListTile
                  : NavigationDestination,
              label(title),
            );
            Future<void> snap(String name) async {
              expect(tester.takeException(), isNull, reason: name);
              final directory = Platform.environment['TENO_MVP_SCREENSHOTS'];
              if (directory == null) return;
              await tester.runAsync(() async {
                final render =
                    boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await render.toImage(pixelRatio: 1);
                final data = await image.toByteData(
                  format: canvas.ImageByteFormat.png,
                );
                final file = File(
                  '$directory/${web ? 'web' : 'android'}-$locale-$mode-$name.png',
                );
                file.parent.createSync(recursive: true);
                file.writeAsBytesSync(data!.buffer.asUint8List());
                image.dispose();
              });
            }

            Future<void> click(Finder finder) async {
              if (finder.evaluate().isEmpty)
                await tester.scrollUntilVisible(
                  finder,
                  200,
                  scrollable: find.byType(Scrollable).last,
                );
              await tester.ensureVisible(finder.first);
              await tester.pumpAndSettle();
              await tester.tap(finder.first);
              await tester.pumpAndSettle();
            }

            await snap('home');
            await click(find.widgetWithText(OutlinedButton, label('Library')));
            await snap('library');
            await click(find.byTooltip(label('Search')));
            await snap('search');
            await click(find.byTooltip(label('Back')));
            await click(navigation('Home'));
            await click(
              find.byWidgetPredicate(
                (w) => w is CoreTile && w.item['id'] == 'record-1',
              ),
            );
            await snap('notes');
            await click(find.text(label('Source')));
            await snap('transcript');
            await click(find.text(label('Notes')));
            await click(find.byTooltip(label('Share recording')));
            await snap('share');
            await click(find.text(label('Share link')));
            await snap('share-link');
            await click(find.text(label('Done')));
            await click(find.text(label('New note')));
            await snap('templates');
            await click(find.byTooltip(label('Back')));
            await click(find.byTooltip(label('Back to library')));
            await click(navigation('Assistant'));
            await snap('assistant');
            await click(navigation('Settings'));
            await snap('settings');
            await click(find.text(label('Interface language')));
            await snap('language');
            expect(
              host.requests.where((v) => !v.startsWith('GET ')),
              isEmpty,
              reason: 'Browsing does not start model jobs',
            );
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
}
