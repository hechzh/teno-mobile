import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/recorder.dart';
import '../lib/main.dart';
import '../lib/platform/runtime.g.dart';
import 'fixtures.dart';
import 'personal_test.dart' as personal;

class JwdHost extends personal.CoreHost {
  bool denyProbe = false;
  @override
  Future<void> controlDevice(
    DeviceAction action,
    String id,
    String name,
  ) async {
    if (denyProbe && action == DeviceAction.probe)
      throw StateError('Nearby devices permission denied');
    await super.controlDevice(action, id, name);
  }

  @override
  Future<void> bindDevice(
    String id,
    String name,
    String key,
    bool createNew,
  ) async {
    calls.add('bind:$createNew');
  }
}

final candidates = [
  {'name': 'Unrelated headphones', 'address': 'other', 'rssi': -20},
  {'name': 'HQ-10_P_FIXTURE', 'address': 'hq', 'name_match': true, 'rssi': -65},
  {'name': 'Advertised recorder', 'address': 'uuid', 'jwd': true, 'rssi': -70},
  {'name': 'Saved recorder', 'address': 'saved', 'has_key': true, 'rssi': -80},
  {
    'name': 'Unsupported recorder',
    'address': 'bad',
    'name_match': true,
    'gatt_status': 'unsupported',
  },
];

Future<void> openDevice(WidgetTester tester, JwdHost host) async {
  host.state.device.identifier = '';
  host.state.device.candidatesJson = jsonEncode(candidates);
  final model = personal.coreModel(host)..changed(host.state);
  await tester.pumpWidget(TenoApp(model: model, initialize: false));
  await tester.tap(find.byTooltip('Start recording'));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find
          .descendant(
            of: find.byType(DevicePage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets(
    'entry scans automatically and ranks recorder matches above unrelated Bluetooth devices',
    (tester) async {
      final host = JwdHost();
      await openDevice(tester, host);
      expect(host.calls.where((call) => call == 'device:scan').length, 1);
      expect(find.text('Unrelated headphones'), findsNothing);
      expect(find.text('Unsupported recorder'), findsNothing);
      expect(find.text('Saved recorder'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('HQ-10_P_FIXTURE'),
        180,
        scrollable: find
            .descendant(
              of: find.byType(DevicePage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('HQ-10_P_FIXTURE'), findsOneWidget);
      await tapVisible(tester, find.text('Other Bluetooth devices (2)'));
      expect(find.text('Unrelated headphones'), findsOneWidget);
      expect(find.text('Unsupported recorder'), findsOneWidget);
      expect(host.calls.where((call) => call == 'phone'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'saved recorder connects with its existing key without a new binding dialog',
    (tester) async {
      final host = JwdHost();
      await openDevice(tester, host);
      await tapVisible(tester, find.text('Saved recorder'));
      expect(host.calls, contains('device:connect'));
      expect(host.calls, isNot(contains('device:probe')));
      expect(host.calls.where((call) => call.startsWith('bind:')), isEmpty);
      expect(find.text('New unbound recorder'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('one tap verifies a new recorder before offering binding', (
    tester,
  ) async {
    final host = JwdHost();
    await openDevice(tester, host);
    final model = tester.widget<DevicePage>(find.byType(DevicePage)).model;
    await tapVisible(tester, find.text('HQ-10_P_FIXTURE'));
    expect(host.calls, contains('device:probe'));
    expect(find.text('New unbound recorder'), findsNothing);
    final state = reviewState(sequence: 2);
    state.device.candidatesJson = jsonEncode([
      {...candidates[1], 'gatt_status': 'verified'},
    ]);
    model.changed(state);
    await tester.pumpAndSettle();
    expect(find.text('Connect your recorder'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(host.calls.where((call) => call.startsWith('bind:')), isEmpty);
    expect(host.calls, isNot(contains('device:start')));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('leaving discovery cancels the pending connection flow', (
    tester,
  ) async {
    final host = JwdHost();
    await openDevice(tester, host);
    final page = find.byType(DevicePage);
    final model = tester.widget<DevicePage>(page).model;
    await tapVisible(tester, find.text('HQ-10_P_FIXTURE'));
    Navigator.of(tester.element(page)).pop();
    await tester.pumpAndSettle();
    final state = reviewState(sequence: 2);
    state.device.candidatesJson = jsonEncode([
      {...candidates[1], 'gatt_status': 'verified'},
    ]);
    model.changed(state);
    await tester.pumpAndSettle();
    expect(find.text('Connect your recorder'), findsNothing);
    expect(host.calls.where((call) => call.startsWith('bind:')), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'failed service verification does not offer binding or start a recording',
    (tester) async {
      final host = JwdHost();
      await openDevice(tester, host);
      final model = tester.widget<DevicePage>(find.byType(DevicePage)).model;
      await tapVisible(tester, find.text('HQ-10_P_FIXTURE'));
      final state = reviewState(sequence: 2);
      state.device.candidatesJson = jsonEncode([
        {...candidates[1], 'gatt_status': 'unsupported'},
      ]);
      model.changed(state);
      await tester.pumpAndSettle();
      expect(find.text('Connect your recorder'), findsNothing);
      expect(host.calls, isNot(contains('device:connect')));
      expect(host.calls, isNot(contains('device:start')));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'permission failure releases the pending connection immediately',
    (tester) async {
      final host = JwdHost()..denyProbe = true;
      await openDevice(tester, host);
      await tapVisible(tester, find.text('HQ-10_P_FIXTURE'));
      expect(find.text('Checking recording service…'), findsNothing);
      expect(
        find.textContaining('Nearby devices permission denied'),
        findsOneWidget,
      );
      expect(host.calls.where((call) => call.startsWith('bind:')), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final connected in [true, false]) {
    testWidgets('does not scan while ${connected ? 'connected' : 'busy'}', (
      tester,
    ) async {
      final host = JwdHost();
      host.state.device.connected = connected;
      host.state.device.authorized = connected;
      host.state.device.busy = !connected;
      await openDevice(tester, host);
      expect(host.calls, isNot(contains('device:scan')));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final status in [
    'Waiting for recorder audio · Connecting',
    'Live audio format is unsupported or damaged. Import the complete recording after stopping.',
    'Live preview is off · Settings > Recorder',
  ]) {
    testWidgets(
      'collapsed preview explains $status at narrow width and large text',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 844);
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final host = JwdHost()
          ..state = reviewState(connected: true, phase: 'recording');
        host.state.capture.previewStatus = status;
        final model = personal.coreModel(host)..changed(host.state);
        await tester.pumpWidget(TenoApp(model: model, initialize: false));
        await tester.tap(find.byTooltip('Start recording'));
        await tester.pumpAndSettle();

        final preview = find.text(status);
        await tester.scrollUntilVisible(
          preview,
          120,
          scrollable: find
              .descendant(
                of: find.byType(RecorderSheet),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(preview, findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final mode in ['light', 'dark', 'large']) {
    testWidgets('JWD release screenshots through actual navigation $mode', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(mode == 'large' ? 360 : 390, 844);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      tester.platformDispatcher.textScaleFactorTestValue = mode == 'large'
          ? 1.5
          : 1;
      debugDisableShadows = false;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(() => debugDisableShadows = true);
      final boundary = GlobalKey();
      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final directory = Platform.environment['TENO_PERSONAL_SCREENSHOTS'];
        if (directory == null) return;
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('$directory/$mode/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      final host = JwdHost();
      host.state.device.identifier = '';
      host.state.device.candidatesJson = jsonEncode(candidates);
      final model = personal.coreModel(host)..changed(host.state);
      model.personalSettings['theme'] = mode == 'dark' ? 'dark' : 'light';
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: TenoApp(model: model, initialize: false),
        ),
      );
      await tester.tap(find.byTooltip('Start recording'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('HQ-10_P_FIXTURE'),
        180,
        scrollable: find
            .descendant(
              of: find.byType(DevicePage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await capture('90-jwd-matches');
      await tapVisible(tester, find.text('Other Bluetooth devices (2)'));
      await tapVisible(tester, find.text('HQ-10_P_FIXTURE'));
      await capture('91-jwd-verifying');
      final verified = reviewState(sequence: 2);
      verified.device.identifier = '';
      verified.device.candidatesJson = jsonEncode([
        {...candidates[1], 'gatt_status': 'verified'},
      ]);
      model.changed(verified);
      await capture('92-jwd-binding');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      final recording = reviewState(
        sequence: 3,
        phase: 'recording',
        connected: true,
      );
      recording.capture.notes = '';
      recording.capture.partial = '';
      recording.capture.segmentsJson = '[]';
      recording.capture.previewStatus =
          'Waiting for recorder audio · Transcription connected';
      host.state = recording;
      model.changed(recording);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Return to recording'));
      await capture('93-jwd-preview-waiting');
      recording.capture.previewStatus =
          'Live audio format is unsupported or damaged. Import the complete recording after stopping.';
      model.changed(recording);
      await capture('94-jwd-preview-error');
      recording.capture.previewStatus =
          'Live preview is off · Settings > Recorder';
      model.changed(recording);
      await capture('95-jwd-preview-off');
      recording.capture.previewStatus = 'Live';
      recording.capture.segmentsJson = jsonEncode([
        {'text': 'Synthetic preview text for layout review.'},
      ]);
      model.changed(recording);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Live transcript'));
      await capture('96-jwd-preview-text');
      await tester.pumpWidget(const SizedBox.shrink());
      debugDisableShadows = true;
    });
  }
}
