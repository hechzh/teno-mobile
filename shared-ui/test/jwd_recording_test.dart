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
    if (denyProbe && action == DeviceAction.scan)
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
  await tester.pump(const Duration(milliseconds: 500));
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
  testWidgets('entry starts automatic connection with no device choices', (
    tester,
  ) async {
    final host = JwdHost();
    await openDevice(tester, host);
    expect(host.calls.where((call) => call == 'device:scan').length, 1);
    for (final row in candidates) {
      expect(find.text(row['name'] as String), findsNothing);
    }
    expect(find.textContaining('Other Bluetooth'), findsNothing);
    expect(find.text('Compatibility scan'), findsNothing);
    expect(find.text('Retry connection'), findsOneWidget);
    expect(host.calls, isNot(contains('device:start')));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('retry restarts automatic discovery without a selection page', (
    tester,
  ) async {
    final host = JwdHost();
    await openDevice(tester, host);
    await tapVisible(tester, find.text('Retry connection'));
    expect(host.calls.where((call) => call == 'device:scan').length, 2);
    expect(host.calls.where((call) => call.startsWith('bind:')), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('leaving automatic verification cancels late connections', (
    tester,
  ) async {
    final host = JwdHost();
    await openDevice(tester, host);
    final page = find.byType(DevicePage),
        model = tester.widget<DevicePage>(find.byType(DevicePage)).model;
    final state = reviewState(sequence: 2);
    state.device.busy = true;
    state.device.status = 'Verifying recorder protocol';
    model.changed(state);
    await tester.pump(const Duration(milliseconds: 300));
    Navigator.of(tester.element(page)).pop();
    await tester.pumpAndSettle();
    expect(host.calls, contains('device:disconnect'));
    expect(host.calls, isNot(contains('device:start')));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('rejected code offers only original-code recovery', (
    tester,
  ) async {
    final host = JwdHost();
    await openDevice(tester, host);
    final model = tester.widget<DevicePage>(find.byType(DevicePage)).model;
    final state = reviewState(sequence: 2);
    state.device.identifier = 'hq';
    state.device.candidatesJson = jsonEncode([
      {'address': 'hq', 'gatt_status': 'verified', 'key_rejected': true},
    ]);
    model.changed(state);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Restore original device code'));
    expect(find.text('New unbound recorder'), findsNothing);
    await tester.enterText(find.byType(TextField), 'FixtureCode12345');
    await tester.tap(find.text('Use original key'));
    await tester.pumpAndSettle();
    expect(host.calls, contains('bind:false'));
    expect(host.calls, isNot(contains('bind:true')));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'scan permission failure can retry without binding or recording',
    (tester) async {
      final host = JwdHost()..denyProbe = true;
      await openDevice(tester, host);
      expect(
        find.textContaining('Nearby devices permission denied'),
        findsOneWidget,
      );
      expect(find.text('Retry connection'), findsOneWidget);
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
        await tester.pump(const Duration(milliseconds: 500));
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

      final scanning = reviewState(sequence: 2);
      scanning.device.scanning = true;
      scanning.device.status = 'Searching for your JWD recorder';
      model.changed(scanning);
      await capture('90-jwd-matches');
      scanning.device.scanning = false;
      scanning.device.busy = true;
      scanning.device.status = 'Verifying recorder protocol';
      model.changed(scanning);
      await capture('91-jwd-verifying');
      scanning.device.busy = false;
      scanning.device.identifier = 'hq';
      scanning.device.status =
          'Device key was rejected. Use the original key; the recorder was not reset.';
      scanning.device.candidatesJson = jsonEncode([
        {'address': 'hq', 'gatt_status': 'verified', 'key_rejected': true},
      ]);
      model.changed(scanning);
      await capture('92-jwd-binding');
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
