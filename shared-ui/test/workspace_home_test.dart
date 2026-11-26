import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/model.dart';
import '../lib/features/personal_home.dart';
import '../lib/features/personal_library.dart';
import '../lib/l10n/generated/app_localizations.dart';
import '../lib/ui/personal_widgets.dart';
import 'fixtures.dart';
import 'personal_test.dart' show CoreHost;

class WorkspaceHost extends CoreHost {
  final workspaces = <Json>[
    {'id': 'personal', 'title': 'Personal workspace', 'folder_id': null},
    {'id': 'studio', 'title': '产品设计', 'folder_id': 'studio'},
  ];
  String selected = '';

  @override
  Future<String> platformCommand(String command, String? body) async {
    if (command != 'workspace_destination') {
      return super.platformCommand(command, body);
    }
    if (body != null) selected = text(object(jsonDecode(body))['folder_id']);
    return jsonEncode({'folder_id': selected});
  }

  @override
  Future<String> request(String method, String path, String? body) async {
    final uri = Uri.parse(path);
    if (uri.path == '/api/v1/personal/workspaces') {
      if (method == 'GET') return jsonEncode({'items': workspaces});
      final changed = {
        'id': 'new-space',
        'title': object(jsonDecode(body!))['title'],
        'folder_id': 'new-space',
      };
      workspaces.add(changed);
      return jsonEncode(changed);
    }
    if (uri.path == '/api/v1/library/items' &&
        uri.queryParameters.containsKey('workspace_id')) {
      requests.add(path);
      final space = uri.queryParameters['workspace_id'];
      final byType = uri.queryParameters['type'];
      final values = space == 'personal'
          ? (byType == 'folder'
                ? [
                    {
                      'id': 'project-folder',
                      'type': 'folder',
                      'title': '内部评审',
                      'child_count': 2,
                    },
                    {
                      'id': 'interview-folder',
                      'type': 'folder',
                      'title': '客户访谈',
                      'child_count': 1,
                    },
                  ]
                : [
                    {
                      ...reviewRecordings.first,
                      'type': 'recording',
                      'title': '录音卡试用与产品定价讨论',
                    },
                    {
                      ...reviewRecordings.first,
                      'id': 'record-2',
                      'type': 'recording',
                      'title': 'App 发布验收讨论',
                    },
                    {
                      'id': 'guide',
                      'type': 'file',
                      'title': '移动端验收清单',
                      'kind': 'document',
                    },
                  ])
          : space == 'studio' && byType != 'recent_files'
          ? [
              {
                'id': 'hardware-folder',
                'type': 'folder',
                'title': '硬件验证',
                'folder_id': 'studio',
                'child_count': 1,
              },
            ]
          : space == 'studio'
          ? [
              {
                ...reviewRecordings.first,
                'type': 'recording',
                'title': '样机交互讨论',
              },
            ]
          : <Json>[];
      return jsonEncode({'items': values, 'total': values.length});
    }
    if (uri.path.startsWith('/api/v1/library/search')) {
      requests.add(path);
      if (uri.path.endsWith('/options')) return '{"folders":[],"speakers":[]}';
      final match = uri.queryParameters['workspace_id'] == 'studio';
      return jsonEncode({
        'items': [
          if (match)
            {
              'item': {
                ...reviewRecordings.first,
                'type': 'recording',
                'title': '样机交互讨论',
              },
              'matches': [],
            },
        ],
        'total': match ? 1 : 0,
      });
    }
    return super.request(method, path, body);
  }
}

void main() {
  setUpAll(() async {
    for (final font in {
      'Inter': 'assets/fonts/InterVariable.ttf',
      'NotoSansSC': 'assets/fonts/NotoSansSC-Regular.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  testWidgets('personal home lists scoped files and creates a workspace', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.reset);
    final host = WorkspaceHost()..state = reviewState();
    host.state.draftsJson = jsonEncode([
      ...rows(jsonDecode(host.state.draftsJson)),
      {
        'id': 'local-studio',
        'title': '本机样机试用',
        'status': 'local',
        'folder_id': 'studio',
        'duration_ms': 11000,
      },
    ]);
    final model = TenoModel(host: host)
      ..changed(host.state)
      ..personalCore = true
      ..capabilities = {'library_stats': 1, 'library_filters': 1};
    addTearDown(model.dispose);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: personalTheme(false),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PersonalHome(model),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> tap(Finder finder) async {
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> screenshot(String name) async {
      final dir = Platform.environment['TENO_NOTE_TABS_SCREENSHOTS'];
      if (dir == null) return;
      await tester.runAsync(() async {
        final frame =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await frame.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(dir).create(recursive: true);
        await File('$dir/$name-zh.png').writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
    }

    expect(find.text('录音卡试用与产品定价讨论'), findsOneWidget);
    expect(find.text('最近文件'), findsOneWidget);
    expect(find.text('内容简报'), findsNothing);
    await screenshot('workspace-home');
    await tap(find.text('个人空间'));
    await screenshot('workspace-switch');
    await tap(find.widgetWithText(CheckedPopupMenuItem<String>, '产品设计'));
    expect(host.selected, 'studio');
    expect(find.text('样机交互讨论'), findsOneWidget);
    expect(find.text('录音卡试用与产品定价讨论'), findsNothing);
    await tap(find.text('查看全部'));
    expect(
      find.descendant(
        of: find.byType(PersonalListBody),
        matching: find.text('硬件验证'),
      ),
      findsOneWidget,
    );
    await screenshot('workspace-library');
    await tap(find.byTooltip('我的文件分类'));
    await tap(find.text('本机文件'));
    expect(find.text('本机样机试用'), findsOneWidget);
    expect(find.text('Design review'), findsNothing);
    await tap(find.byTooltip('返回'));
    await tap(find.widgetWithText(NavigationDestination, '首页'));
    await tap(find.byTooltip('搜索'));
    await tester.enterText(find.byType(TextField), '样机');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('样机交互讨论'), findsOneWidget);
    expect(
      host.requests,
      contains('/api/v1/library/search/options?workspace_id=studio'),
    );
    await tap(find.byTooltip('返回'));
    await tap(find.text('产品设计'));
    await tap(find.text('新建工作空间'));
    await tester.enterText(find.byType(TextField), '试验空间');
    await tap(find.text('保存'));
    expect(host.selected, 'new-space');
    expect(find.text('试验空间'), findsOneWidget);
    expect(find.text('这个工作空间还没有文件'), findsOneWidget);
    expect(
      host.requests.any(
        (request) => request.contains('workspace_id=new-space'),
      ),
      true,
    );
  });
}
