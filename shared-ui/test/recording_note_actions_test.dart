import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/model.dart';
import '../lib/features/personal_recording.dart';
import '../lib/l10n/generated/app_localizations.dart';
import '../lib/ui/personal_widgets.dart';
import 'fixtures.dart';
import 'personal_test.dart' show CoreHost;

class _NoteTabsHost extends CoreHost {
  final saved = <Json>[
    {
      'id': 'note-1',
      'title': '由摘要生成的录音内容标题',
      'revision': 1,
      'template_id': 'teno:brief',
      'is_primary': true,
      'data': {'summary': '团队决定先完成样机，再根据首轮试用反馈调整价格。'},
    },
    {
      'id': 'note-2',
      'title': '另一个内容标题',
      'revision': 3,
      'template_id': 'template-1',
      'data': {
        'summary': '首轮试用将验证两个问题：用户能否顺利完成配对，以及录音能否及时同步。',
        'template_snapshot': {
          'id': 'template-1',
          'title': 'Action checklist',
          'title_zh': '行动清单',
        },
        'language': 'zh-CN',
        'output_language': 'zh-CN',
        'output_language_origin': 'override',
        'key_points': ['试用邀请先发给已有用户。', '团队将在周五集中复盘反馈。'],
      },
    },
  ];
  final trashed = <Json>[];
  @override
  Future<String> request(String method, String path, String? body) async {
    if (method == 'GET' && path == '/api/v1/recordings/record-1/notes') {
      return jsonEncode({'items': saved, 'primary_note_id': 'note-1'});
    }
    if (method == 'POST' && path == '/api/v1/library/batch') {
      final data = jsonDecode(body!) as Json;
      bodies['$method $path'] = data;
      final id = data['items'].single['id'];
      if (data['action'] == 'trash') {
        trashed.add(saved.firstWhere((n) => n['id'] == id));
        saved.removeWhere((n) => n['id'] == id);
      } else {
        saved.add(trashed.firstWhere((n) => n['id'] == id));
        trashed.removeWhere((n) => n['id'] == id);
      }
      return '{"ok":true,"count":1}';
    }
    if (method == 'POST' && path.endsWith('/regenerate')) {
      bodies['$method $path'] = jsonDecode(body!) as Json;
      throw PlatformException(code: 'JOB_FAILED', message: '测试生成失败');
    }
    if (method == 'POST' && path == '/api/v1/recordings/record-1/notes') {
      final args = object(jsonDecode(body!));
      bodies['$method $path'] = args;
      saved.add({
        'id': 'note-3',
        'title': '选择模板后创建的笔记',
        'template_id': args['template_id'],
        'revision': 1,
        'data': {'body': '这一篇使用手动选择的会议纪要模板。'},
      });
      return '{"id":"extra-note","status":"queued"}';
    }
    if (method == 'GET' && path == '/api/v1/jobs/extra-note') {
      return '{"id":"extra-note","status":"completed","result":{"note_id":"note-3"}}';
    }
    return super.request(method, path, body);
  }
}

void main() {
  final boundary = GlobalKey();
  setUpAll(() async {
    for (final asset in {
      'Inter': 'assets/fonts/InterVariable.ttf',
      'NotoSansSC': 'assets/fonts/NotoSansSC-Regular.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        asset.key,
      )..addFont(rootBundle.load(asset.value))).load();
    }
  });
  testWidgets(
    'selected note template and trash actions preserve other notes and the recording',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.reset);
      final host = _NoteTabsHost()..state = reviewState();
      host.overrides['/api/v1/recordings/record-1'] = {
        ...reviewRecordings.first,
        'title': '录音卡试用与产品定价讨论',
        'recorded_at': '2026-11-26T02:30:00Z',
      };
      host.overrides['/api/v1/personal/templates'] = {
        'items': [
          {
            'id': 'teno:meeting',
            'title': 'Meeting notes',
            'title_zh': '会议纪要',
            'category': 'Meeting',
            'description_zh': '整理决策与后续事项',
            'author': 'Teno',
            'recommended': true,
          },
          {
            'id': 'teno:brief',
            'title': 'Key insights',
            'title_zh': '关键见解',
            'category': 'Interview',
            'description_zh': '提炼主要观点',
            'author': 'Teno',
            'recommended': true,
          },
        ],
      };
      final model = TenoModel(host: host)
        ..changed(host.state)
        ..personalCore = true
        ..interfaceLanguage = 'zh';
      addTearDown(model.dispose);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: personalTheme(false),
            home: PersonalRecordingPage(model, 'record-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tap(Finder finder) async {
        if (finder.hitTestable().evaluate().isEmpty)
          await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      Future<void> snap(String name) async {
        final dir = Platform.environment['TENO_NOTE_TABS_SCREENSHOTS'];
        if (dir == null) return;
        await tester.runAsync(() async {
          final frame =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await frame.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(dir).create(recursive: true);
          await File(
            '$dir/$name-zh.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      final primary = find.byKey(const ValueKey('note-tab-note-1'));
      expect(
        find.descendant(of: primary, matching: find.text('关键见解')),
        findsOneWidget,
      );
      expect(find.text('上传时间'), findsNothing);
      expect(find.byTooltip('Play recording'), findsNothing);
      await snap('note-tabs');
      final current = find.byKey(const ValueKey('note-tab-note-2'));
      await tap(current);
      expect(find.text('录音卡试用与产品定价讨论'), findsOneWidget);
      expect(find.text('删除笔记'), findsNothing);
      await tap(primary);
      expect(find.text('选择模板'), findsOneWidget);
      expect(find.text('删除笔记'), findsNothing);
      await snap('primary-template-picker');
      await tap(find.byTooltip('返回'));
      expect(find.text('团队决定先完成样机，再根据首轮试用反馈调整价格。'), findsOneWidget);
      await tap(current);
      await tap(current);
      await snap('note-actions');
      await tap(find.text('删除笔记'));
      await snap('delete-note');
      await tap(find.text('取消'));
      expect(host.trashed, isEmpty);
      await tap(current);
      await tap(find.text('更换模板'));
      await snap('change-template');
      await tap(find.text('会议纪要').last);
      await tap(find.text('应用模板'));
      final job = host.bodies['POST /api/v1/notes/note-2/regenerate'];
      expect(job, containsPair('base_revision', 3));
      expect(job, containsPair('template_id', 'teno:meeting'));
      expect(job, containsPair('output_language', 'zh-CN'));
      expect(find.text('首轮试用将验证两个问题：用户能否顺利完成配对，以及录音能否及时同步。'), findsOneWidget);
      expect(host.saved.length, 2);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tap(current);
      await tap(find.text('删除笔记'));
      await tap(find.text('确认'));
      expect(host.saved.map((n) => n['id']), ['note-1']);
      expect(host.bodies['POST /api/v1/library/batch']!['items'], [
        {'type': 'note', 'id': 'note-2'},
      ]);
      expect(find.byKey(const ValueKey('note-tab-note-1')), findsOneWidget);
      expect(current, findsNothing);
      await tap(find.text('撤销'));
      expect(current, findsOneWidget);
      await tap(current);
      await tap(find.text('删除笔记'));
      await tap(find.text('确认'));
      await tap(primary);
      expect(find.text('选择模板'), findsOneWidget);
      expect(find.text('删除笔记'), findsNothing);
      await tap(find.byTooltip('返回'));
      await tap(find.byTooltip('新建笔记'));
      expect(find.text('选择模板'), findsOneWidget);
      expect(find.text('输出语言'), findsOneWidget);
      await tap(find.text('会议纪要').last);
      await tap(find.text('生成笔记'));
      final newNote = host.bodies['POST /api/v1/recordings/record-1/notes'];
      expect(newNote, containsPair('template_id', 'teno:meeting'));
      expect(newNote, containsPair('output_language', 'zh-CN'));
      await tap(find.byTooltip('返回'));
      expect(find.text('这一篇使用手动选择的会议纪要模板。'), findsOneWidget);
      expect(host.saved.map((n) => n['id']), ['note-1', 'note-3']);
      expect(find.text('录音卡试用与产品定价讨论'), findsOneWidget);
    },
  );
}
