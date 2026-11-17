import 'dart:io';
import 'dart:ui' as canvas;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/note_text.dart';
import '../lib/features/generation_options.dart';
import '../lib/features/template_examples.dart';
import '../lib/features/personal_ask.dart';
import '../lib/l10n/ui_strings.dart';
import '../lib/main.dart';
import '../lib/ui/processing_progress.dart';
import 'personal_test.dart' as fixture;

void main() {
  setUpAll(() async {
    for (final f in [
      ('Inter', 'assets/fonts/InterVariable.ttf'),
      ('NotoSansSC', 'assets/fonts/NotoSansSC-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(f.$1)..addFont(rootBundle.load(f.$2))).load();
    }
  });
  testWidgets(
    'resolved interface language wins over legacy account preference and one-off does not leak',
    (tester) async {
      final host = fixture.CoreHost();
      final model = fixture.coreModel(host);
      addTearDown(model.dispose);
      model.personalSettings['summary_language'] = 'en-US';
      model.interfaceLanguage = 'zh';
      expect(model.generationLanguage(), {
        'output_language': 'zh-CN',
        'output_language_origin': 'interface',
      });
      expect(
        model.generationLanguage('en-US')['output_language_origin'],
        'override',
      );
      expect(model.generationLanguage()['output_language'], 'zh-CN');
      model.interfaceLanguage = 'en';
      expect(model.outputLanguage, 'en-US');
      model.interfaceLanguage = 'system';
      tester.binding.platformDispatcher.localeTestValue = const Locale(
        'zh',
        'TW',
      );
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      expect(model.outputLanguage, 'zh-CN');
      tester.binding.platformDispatcher.localeTestValue = const Locale('fr');
      expect(model.outputLanguage, 'en-US');
    },
  );
  test(
    'copy preserves the generated template, language and all narrative fields',
    () {
      final data = <String, dynamic>{
        'schema_version': 'personal-notes-v2',
        'output_language': 'zh-CN',
        'language': 'zh-CN',
        'template_snapshot': {'title': 'Meeting notes', 'title_zh': '会议纪要'},
        'summary': '概览',
        'body': '完整正文',
        'key_points': ['要点一'],
        'action_items': [
          {'title': '行动一'},
        ],
      };
      expect(
        copyNoteText(data),
        '模板：会议纪要 · 输出语言：中文\n\n概览\n\n完整正文\n\n要点\n• 要点一\n\n行动项\n• 行动一',
      );
      expect(editableNoteText(data), isNot(contains('输出语言')));
    },
  );
  for (final language in ['en', 'zh']) {
    for (final width in [360.0, 1100.0]) {
      for (final screen in [
        'choices',
        'progress',
        'ask',
        ...TemplateExample.examples.keys,
      ]) {
        testWidgets('0.8.2 $screen $language $width', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 900);
          addTearDown(tester.view.reset);
          final model = fixture.coreModel(fixture.CoreHost())
            ..interfaceLanguage = language;

          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: TenoApp(model: model, initialize: false),
            ),
          );
          await tester.pumpAndSettle();
          final nav = Navigator.of(tester.element(find.byType(Scaffold).first));
          Widget page;
          if (screen == 'ask') {
            page = PersonalChatPage(model);
          } else {
            page = Scaffold(
              appBar: AppBar(
                title: Text(
                  screen == 'choices'
                      ? (language == 'zh' ? '本次处理' : 'Process this file')
                      : screen == 'progress'
                      ? (language == 'zh' ? '处理进度' : 'Processing progress')
                      : (language == 'zh' ? '模板示例' : 'Template example'),
                ),
              ),
              body: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (screen == 'choices')
                    GenerationOptions(
                      model,
                      template: 'teno:meeting',
                      onTemplate: (_) async {},
                      onLanguage: (_) async {},
                    ),
                  if (screen == 'progress') ...[
                    const ProcessingProgress({
                      'stage': 'saved',
                      'stage_status': 'idle',
                      'waiting_reason': 'cloud_disabled',
                      'preserved': {'local_file': true},
                    }),
                    const ProcessingProgress({
                      'stage': 'syncing',
                      'stage_status': 'running',
                      'percent': 42,
                      'preserved': {'device_file': true},
                    }),
                    const ProcessingProgress({
                      'stage': 'generating_note',
                      'stage_status': 'failed',
                      'preserved': {
                        'local_file': true,
                        'cloud_audio': true,
                        'transcript': true,
                        'notes': 1,
                      },
                    }),
                  ],
                  if (TemplateExample.examples.containsKey(screen))
                    TemplateExample(screen),
                ],
              ),
            );
          }
          nav.push(MaterialPageRoute<void>(builder: (_) => page));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final ctx = tester.element(find.byType(Scaffold).last);
          if (screen == 'choices')
            expect(find.text(ui(ctx, 'Output language')), findsOneWidget);
          if (screen == 'ask') {
            expect(find.text(ui(ctx, 'All my files')), findsWidgets);
            expect(find.text(ui(ctx, 'Selected files')), findsNothing);
          }
          if (screen == 'progress') {
            expect(find.text(ui(ctx, 'Existing notes kept')), findsOneWidget);
            expect(find.text('42%'), findsNothing);
          }
          if (TemplateExample.examples.containsKey(screen))
            expect(find.text(ui(ctx, 'Example result')), findsOneWidget);
          final directory = Platform.environment['TENO_082_SCREENSHOTS'];
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
                '$directory/${screen.replaceAll(':', '-')}-$language-${width.toInt()}.png',
              );
              file.parent.createSync(recursive: true);
              file.writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
}
