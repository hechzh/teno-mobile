import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/model.dart';
import '../lib/main.dart';
import '../lib/platform/runtime.g.dart';
import 'fixtures.dart';

const invalid =
    'Invalid username or password. Check your Teno account and try again.';

class RejectedLoginHost extends FixtureHost {
  @override
  Future<SessionState> login(
    String server,
    String username,
    String password,
  ) async {
    throw PlatformException(
      code: 'INVALID_CREDENTIALS',
      message: 'Your session expired. Sign in again.',
    );
  }
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final font in ['InterVariable', 'NotoSansSC-Regular']) {
      await (FontLoader(
        font == 'InterVariable' ? 'Inter' : 'NotoSansSC',
      )..addFont(rootBundle.load('assets/fonts/$font.ttf'))).load();
    }
  });
  test(
    'credentials and real expiry remain separate across the native bridge',
    () {
      expect(
        TenoModel.friendly(PlatformException(code: 'INVALID_CREDENTIALS')),
        invalid,
      );
      for (final code in ['UNAUTHORIZED', 'AUTH_EXPIRED', 'HTTP_401']) {
        expect(
          TenoModel.friendly(PlatformException(code: code)),
          'Your session expired. Sign in again.',
        );
      }
      expect(
        TenoModel.friendly(PlatformException(code: 'NETWORK_ERROR')),
        isNot(contains('expired')),
      );
    },
  );
  for (final language in ['en', 'zh']) {
    testWidgets('rejected login is correctly localized in $language', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final model = TenoModel(host: RejectedLoginHost())
        ..changed(reviewState(signedIn: false))
        ..interfaceLanguage = language;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: TenoApp(model: model, initialize: false),
        ),
      );
      final fields = find.byType(TextField);
      expect(tester.widget<TextField>(fields.first).autocorrect, false);
      await tester.enterText(fields.at(0), 'synthetic');
      await tester.enterText(fields.at(1), 'synthetic-secret');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(
        find.text(language == 'zh' ? '用户名或密码不正确，请检查 Teno 账号后重试。' : invalid),
        findsOneWidget,
      );
      expect(find.text('登录已过期，请重新登录。'), findsNothing);
      expect(find.text('Your session expired. Sign in again.'), findsNothing);
      expect(
        tester.widget<TextField>(fields.first).controller!.text,
        'synthetic',
      );
      expect(tester.widget<TextField>(fields.at(1)).controller!.text, isEmpty);
      final directory = Platform.environment['TENO_AUTH_SCREENSHOTS'];
      if (directory != null) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('$directory/login-invalid-$language.png');
          file.parent.createSync(recursive: true);
          file.writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
