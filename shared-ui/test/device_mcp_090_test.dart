import 'dart:convert';
import 'dart:io';
import 'dart:ui' as canvas;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/main.dart';
import '../lib/core/model.dart';
import '../lib/features/personal_mcp.dart';
import '../lib/features/personal_recorders.dart';
import 'personal_test.dart' as fixture;

final source = <String, dynamic>{
  'key': 'note:note-1:r1',
  'type': 'note',
  'id': 'note-1',
  'title': 'Design review · 设计评审',
  'revision': 1,
  'source_revision': 1,
  'saved_at': '2026-11-19T09:00:00Z',
};
final connection = <String, dynamic>{
  'id': 'connection-1',
  'name': 'Design context · 设计资料',
  'state': 'active',
  'revision': 1,
  'snapshot_id': 'snapshot-1',
  'url': 'https://example.test/mcp/personal/connection-1',
  'updated_at': '2026-11-19T09:00:00Z',
  'sources': [source],
};
final recorder = <String, dynamic>{
  'id': 'recorder-1',
  'name': 'VTR7860_P_8CBEDB9C',
  'hardware_id': 'A0B1C2D3E4F5',
  'epoch': 2,
  'recoverable': true,
};

class Host extends fixture.CoreHost {
  final sent = <String, Json>{};
  @override
  Future<String> request(String method, String path, String? body) async {
    final route = Uri.parse(path).path;
    if (route.startsWith('/api/v1/mcp') ||
        route.startsWith('/api/v1/recorders')) {
      requests.add('$method $path');
      sent['$method $route'] = body == null ? {} : object(jsonDecode(body));
      if (route == '/api/v1/mcp/connections')
        return jsonEncode(
          method == 'POST'
              ? connection
              : {
                  'items': [connection],
                },
        );
      if (route.endsWith('/preview') || route.endsWith('/preview-update'))
        return jsonEncode({
          'preview_hash': 'a' * 64,
          'base_revision': 1,
          'sources': [source],
        });
      if (route.endsWith('/read'))
        return jsonEncode({
          'snapshot_id': 'snapshot-1',
          'source': source,
          'items': [
            {'text': 'We chose the green button. 选择绿色按钮。', 'start_ms': 1200},
          ],
          'next_offset': null,
        });
      if (route == '/api/v1/recorders')
        return jsonEncode({
          'items': [recorder],
        });
      if (route == '/api/v1/recorders/operations/pending')
        return '{"items":[]}';
      if (route.startsWith('/api/v1/recorders/operations/'))
        return jsonEncode({
          'id': 'operation-1',
          'state': 'awaiting_recipient',
          'kind': 'transfer',
          'initiated_by_me': true,
          'recorder': recorder,
          'transfer_code': 'synthetic-transfer-code',
          'updated_at': '2026-11-19T09:00:00Z',
        });
      return jsonEncode(connection);
    }
    return super.request(method, path, body);
  }
}

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
  Future<GlobalKey> mount(
    WidgetTester tester,
    TenoModel model,
    Widget page,
  ) async {
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: TenoApp(model: model, initialize: false),
      ),
    );
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.byType(Scaffold).first),
    ).push(MaterialPageRoute<void>(builder: (_) => page));
    await tester.pumpAndSettle();
    return boundary;
  }

  for (final language in ['en', 'zh']) {
    for (final width in [360.0, 390.0, 1100.0]) {
      for (final screen in [
        'connections',
        'choose',
        'connection',
        'read',
        'recorders',
        'transfer',
      ]) {
        testWidgets('0.9.0 $screen $language $width', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 940);
          addTearDown(tester.view.reset);
          final host = Host();
          final actual = fixture.coreModel(host)..interfaceLanguage = language;
          final page = switch (screen) {
            'connections' => McpConnectionsPage(actual),
            'choose' => McpCreatePage(
              actual,
              initial: const [
                {'type': 'note', 'id': 'note-1', 'revision': 1},
              ],
            ),
            'connection' => McpConnectionPage(actual, 'connection-1'),
            'read' => McpReadPage(
              actual,
              'connection-1',
              'snapshot-1',
              'note:note-1:r1',
            ),
            'recorders' => MyRecordersPage(actual),
            _ => RecorderOperationPage(actual, 'operation-1'),
          };
          final boundary = await mount(tester, actual, page);
          expect(tester.takeException(), isNull);
          if (screen == 'transfer')
            expect(find.text('synthetic-transfer-code'), findsOneWidget);
          if (screen == 'choose')
            expect(
              host.requests,
              contains('GET /api/v1/notes/note-1?revision=1'),
            );
          final dir =
              Platform.environment['TENO_090_SCREENSHOTS'] ??
              (Platform.environment['TENO_PERSONAL_SCREENSHOTS'] == null
                  ? null
                  : '${Platform.environment['TENO_PERSONAL_SCREENSHOTS']}/device-mcp');
          if (dir != null)
            await tester.runAsync(() async {
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: canvas.ImageByteFormat.png,
              );
              final file = File('$dir/$screen-$language-${width.toInt()}.png');
              file.parent.createSync(recursive: true);
              file.writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
  testWidgets(
    'historical note selection is explicit and review does not create a connection',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final host = Host();
      final actual = fixture.coreModel(host)..interfaceLanguage = 'en';
      await mount(
        tester,
        actual,
        McpCreatePage(
          actual,
          initial: const [
            {'type': 'note', 'id': 'note-1', 'revision': 1},
          ],
        ),
      );
      await tester.tap(find.text('Review selected content'));
      await tester.pumpAndSettle();
      expect(host.sent['POST /api/v1/mcp/preview']!['selection'], [
        {
          'type': 'note',
          'id': 'note-1',
          'revision': 1,
          'include_source': false,
        },
      ]);
      expect(host.sent.containsKey('POST /api/v1/mcp/connections'), isFalse);
      expect(find.text('Create MCP link'), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      expect(find.text('Create MCP link'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
