import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/model.dart';
import '../lib/main.dart';
import '../lib/features/personal_home.dart';
import '../lib/features/personal_import.dart';
import '../lib/features/personal_settings.dart';
import '../lib/features/personal_ask.dart';
import 'personal_test.dart' show CoreHost;
import 'fixtures.dart';

TenoModel browserModel({bool signedIn = true}) {
  final host = CoreHost();
  host.state = reviewState(signedIn: signedIn)..draftsJson = '[]';
  final model = TenoModel(host: host, webExperience: true);
  model.changed(host.state);
  model.personalCore = signedIn;
  model.personalSettings = host.prefs;
  return model;
}

void main() {
  for (final web in [true, false]) {
    testWidgets('chat history uses the ${web ? "Web" : "native"} contract', (
      tester,
    ) async {
      final host = CoreHost();
      host.state = reviewState();
      final path = web
          ? '/api/v1/personal/chats/chat-web/messages'
          : '/api/v1/chats/chat-web/messages';
      host.overrides['GET /api/v1/chats/chat-web'] = {
        'data': {'contexts': <Json>[]},
      };
      host.overrides['GET $path'] = {'items': <Json>[]};
      final model = TenoModel(host: host, webExperience: web);
      model.changed(host.state);
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(home: PersonalChatPage(model, chatId: 'chat-web')),
      );
      await tester.pumpAndSettle();
      expect(host.requests, contains('GET $path'));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'iPhone browser uses current personal home and no hardware entry',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final model = browserModel();

      await tester.pumpWidget(TenoApp(model: model, initialize: false));
      await tester.pumpAndSettle();
      expect(find.byType(PersonalHome), findsOneWidget);
      expect(find.text('Upcoming'), findsNothing);
      await tester.tap(find.byTooltip('Create'));
      await tester.pumpAndSettle();
      expect(find.text('Import files'), findsOneWidget);
      expect(find.text('Start recording'), findsNothing);
      expect(find.text('Record with phone'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'browser login uses existing account without device/server choices',
    (tester) async {
      final model = browserModel(signedIn: false);

      await tester.pumpWidget(TenoApp(model: model, initialize: false));
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Server settings'), findsNothing);
      expect(find.text('Connect a recorder without signing in'), findsNothing);
    },
  );
  testWidgets(
    'browser import states promise browser storage, not native persistence',
    (tester) async {
      final model = browserModel();
      addTearDown(model.dispose);
      await tester.pumpWidget(MaterialApp(home: PersonalImportPage(model)));
      await tester.pumpAndSettle();
      expect(find.text('From Files'), findsOneWidget);
      expect(find.text('From other apps'), findsNothing);
      expect(find.textContaining('saved in this browser'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final setting in [('light', 1.0), ('dark', 1.0), ('light', 1.5)]) {
    testWidgets('browser settings at 360dp ${setting.$1} ${setting.$2}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = browserModel();
      model.personalSettings['theme'] = setting.$1;
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(setting.$2)),
            child: Scaffold(body: PersonalSettings(model)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recorder'), findsNothing);
      expect(find.text('Notifications'), findsNothing);
      expect(find.text('Cloud processing'), findsNothing);
      expect(find.text('Theme'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('browser Ask retains typed input and context, omits dictation', (
    tester,
  ) async {
    final model = browserModel();
    addTearDown(model.dispose);
    await tester.pumpWidget(MaterialApp(home: PersonalChatPage(model)));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add context'), findsOneWidget);
    expect(find.byTooltip('Voice input'), findsNothing);
    await tester.enterText(find.byType(TextField), 'What was decided?');
    await tester.pump();
    expect(find.byTooltip('Send question'), findsOneWidget);
  });
}
