import '../l10n/ui_strings.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../core/model.dart';
import '../platform/runtime.g.dart';
import '../ui/widgets.dart';
import '../ui/personal_widgets.dart';
import 'detail.dart';

Future<bool> ensureOptions(BuildContext context, TenoModel model) async {
  if (model.personalCore) return true;
  if (!model.signedIn || model.runtime!.session.optionsSet) return true;
  bool cloud = true, wifi = false, live = true;
  final chosen = await showDialog<bool>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        scrollable: true,
        title: const UiText('Recording preferences'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const UiText(
              'A complete audio file is always kept on this phone. These choices are saved to this account on this device.',
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const UiText('Cloud processing'),
              value: cloud,
              onChanged: (v) => update(() => cloud = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const UiText('Upload on Wi-Fi only'),
              value: wifi,
              onChanged: (v) => update(() => wifi = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const UiText('Live transcript preview'),
              value: live,
              onChanged: (v) => update(() => live = v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const UiText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const UiText('Continue'),
          ),
        ],
      ),
    ),
  );
  if (chosen != true) return false;
  await model.host.configure(cloud, wifi, live);
  model.changed(await model.host.snapshot());
  return true;
}

Future<void> startPhone(BuildContext context, TenoModel model) async =>
    perform(context, () async {
      if (!await ensureOptions(context, model) || !context.mounted) return;
      if (!model.capturing)
        await model.host.startPhone(
          'Recording ' + dateLabel(DateTime.now().toIso8601String()),
        );
      model.changed(await model.host.snapshot());
      if (context.mounted) await showRecorder(context, model);
    });

Future<void> showRecorder(BuildContext context, TenoModel model) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .20),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: .7,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Material(
              color: Colors.transparent,
              child: RecorderSheet(model),
            ),
          ),
        ),
      ),
    );

class DevicePage extends StatefulWidget {
  const DevicePage(this.model, {super.key});
  final TenoModel model;
  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  TenoModel get model => widget.model;
  bool showOtherDevices = false, probeWasBusy = false;
  String? pendingProbe;
  Timer? probeTimeout;

  @override
  void initState() {
    super.initState();
    model.addListener(deviceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final device = model.runtime!.device;
      if (!device.connected && !device.busy && !device.scanning) {
        command(DeviceAction.scan);
      }
    });
  }

  @override
  void dispose() {
    model.removeListener(deviceChanged);
    probeTimeout?.cancel();
    super.dispose();
  }

  void deviceChanged() {
    if (pendingProbe == null || !mounted) return;
    final device = model.runtime!.device;
    probeWasBusy = probeWasBusy || device.busy;
    final matches = jsonRows(
      device.candidatesJson,
    ).where((row) => row['address'] == pendingProbe);
    if (matches.isNotEmpty && matches.first['gatt_status'] == 'verified') {
      final candidate = matches.first;
      pendingProbe = null;
      probeTimeout?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) connect(candidate);
      });
    } else if ((matches.isNotEmpty &&
            matches.first['gatt_status'] == 'unsupported') ||
        (probeWasBusy && !device.busy)) {
      setState(() => pendingProbe = null);
      probeTimeout?.cancel();
    }
  }

  int candidateRank(Json candidate) {
    if (candidate['gatt_status'] == 'unsupported') return 4;
    if (candidate['gatt_status'] == 'verified') return 0;
    if (candidate['has_key'] == true) return 1;
    if (candidate['jwd'] == true) return 2;
    if (candidate['name_match'] == true) return 3;
    return 4;
  }

  Future<void> command(
    DeviceAction action, {
    String id = '',
    String name = '',
  }) => perform(context, () => model.host.controlDevice(action, id, name));

  Future<void> connect(Json candidate) async {
    final id = text(candidate['address']), name = text(candidate['name']);
    if (candidate['has_key'] == true) {
      await command(DeviceAction.connect, id: id, name: name);
      return;
    }
    if (candidate['gatt_status'] != 'verified') {
      setState(() {
        pendingProbe = id;
        probeWasBusy = false;
      });
      probeTimeout?.cancel();
      probeTimeout = Timer(const Duration(seconds: 30), () {
        if (mounted) setState(() => pendingProbe = null);
      });
      await perform(context, () async {
        try {
          await model.host.controlDevice(DeviceAction.probe, id, name);
        } catch (_) {
          probeTimeout?.cancel();
          if (mounted) setState(() => pendingProbe = null);
          rethrow;
        }
      });
      return;
    }
    final key = TextEditingController();
    final choice = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: const UiText('Connect your recorder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const UiText(
              'For a recorder already used with Teno, enter its original device key. A new key is only for an unbound recorder.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: key,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              maxLength: 16,
              decoration: const InputDecoration(
                label: UiText('Original 16-character key'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const UiText('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, 'new'),
            child: const UiText('New unbound recorder'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, 'existing'),
            child: const UiText('Use original key'),
          ),
        ],
      ),
    );
    final value = key.text;
    key.clear();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    key.dispose();
    if (choice == null || !mounted) return;
    await perform(
      context,
      () => model.host.bindDevice(id, name, value, choice == 'new'),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) {
      final device = model.runtime!.device;
      final candidates = jsonRows(device.candidatesJson)
        ..sort((a, b) {
          final rank = candidateRank(a).compareTo(candidateRank(b));
          if (rank != 0) return rank;
          return ((b['rssi'] as num?) ?? -127).compareTo(
            (a['rssi'] as num?) ?? -127,
          );
        });
      final otherCount = candidates
          .where((row) => candidateRank(row) == 4)
          .length;
      final selecting = device.busy || pendingProbe != null;
      if (device.receiving) {
        return PageFrame(
          title: 'Saving recording',
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 60),
              const Icon(Icons.downloading_outlined, size: 72, color: muted),
              const SizedBox(height: 32),
              const UiText(
                'Saving to this phone',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              Text(
                device.status,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 36),
              LinearProgressIndicator(
                value: device.expectedBytes > 0
                    ? (device.receivedBytes / device.expectedBytes).clamp(0, 1)
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                device.expectedBytes > 0
                    ? ((device.receivedBytes / device.expectedBytes) * 100)
                              .clamp(0, 100)
                              .toStringAsFixed(0) +
                          '% received'
                    : 'Waiting for recorder',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              const UiText(
                'The complete file is checked before it is saved and uploaded. Originals stay on your recorder.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () => command(DeviceAction.cancelTransfer),
                child: const UiText('Pause transfer'),
              ),
            ],
          ),
        );
      }
      return PageFrame(
        title: device.authorized ? 'Your recorder' : 'Connect a recorder',
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 20),
            Icon(
              Icons.speaker_phone_outlined,
              size: 100,
              color: device.authorized
                  ? Theme.of(context).colorScheme.onSurface
                  : muted,
            ),
            const SizedBox(height: 28),
            Text(
              device.authorized
                  ? device.name
                  : 'Bring your JWD recorder closer',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              device.status,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 24),
            if (device.authorized) ...[
              MenuRow(
                Icons.battery_std,
                'Battery',
                null,
                trailing: Text(device.battery),
              ),
              MenuRow(
                Icons.key_outlined,
                'Device key backup',
                () => perform(context, model.host.showDeviceKey),
              ),
              FilledButton(
                onPressed: device.busy || !model.signedIn
                    ? null
                    : () => perform(context, () async {
                        if (!await ensureOptions(context, model) || !mounted)
                          return;
                        if (!model.capturing)
                          await model.host.controlDevice(
                            DeviceAction.start,
                            '',
                            '',
                          );
                        model.changed(await model.host.snapshot());
                        if (context.mounted) await showRecorder(context, model);
                      }),
                child: UiText(
                  !model.signedIn
                      ? 'Sign in to record'
                      : model.capturing
                      ? 'Return to recording'
                      : 'Start recording',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: device.busy || model.capturing
                    ? null
                    : () => command(DeviceAction.sync),
                child: const UiText('Sync recordings to this phone'),
              ),
              TextButton(
                onPressed: device.busy
                    ? null
                    : () => command(DeviceAction.refresh),
                child: const UiText('Refresh device status'),
              ),
              TextButton(
                onPressed: () => command(DeviceAction.disconnect),
                child: const UiText('Disconnect'),
              ),
            ] else ...[
              if (device.identifier.isNotEmpty)
                OutlinedButton(
                  onPressed: selecting
                      ? null
                      : () => command(
                          DeviceAction.connect,
                          id: device.identifier,
                          name: device.name,
                        ),
                  child: const UiText('Reconnect saved recorder'),
                ),
              FilledButton(
                onPressed: selecting || device.scanning
                    ? null
                    : () => command(DeviceAction.scan),
                child: UiText(
                  device.scanning ? 'Scanning…' : 'Scan for recorders',
                ),
              ),
              TextButton(
                onPressed: selecting || device.scanning
                    ? null
                    : () => command(DeviceAction.compatibilityScan),
                child: const UiText('Compatibility scan'),
              ),
              if (candidates.any((row) => candidateRank(row) < 4))
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: UiText(
                    'Matching recorders',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              for (final candidate in candidates.where(
                (row) => showOtherDevices || candidateRank(row) < 4,
              ))
                MenuRow(
                  Icons.bluetooth,
                  text(candidate['name']),
                  selecting ? null : () => connect(candidate),
                  localizeTitle: false,
                  subtitle: pendingProbe == candidate['address']
                      ? 'Checking recording service…'
                      : candidate['has_key'] == true
                      ? 'Saved recorder · Connect'
                      : candidate['gatt_status'] == 'verified'
                      ? 'Recording service verified · Connect'
                      : candidate['gatt_status'] == 'unsupported'
                      ? 'Recording service unavailable'
                      : candidateRank(candidate) < 4
                      ? 'JWD candidate · Tap to verify and connect'
                      : 'Unrecognized device · Check recording service',
                ),
              if (otherCount > 0)
                TextButton(
                  onPressed: () =>
                      setState(() => showOtherDevices = !showOtherDevices),
                  child: Text(
                    showOtherDevices
                        ? ui(context, 'Hide other devices')
                        : context.strings.otherDeviceCount(otherCount),
                  ),
                ),
            ],
            if (device.receiving) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: device.expectedBytes > 0
                    ? (device.receivedBytes / device.expectedBytes).clamp(0, 1)
                    : null,
              ),
              const SizedBox(height: 10),
              const UiText(
                'Receiving and verifying the complete recording. Originals stay on your recorder.',
                style: TextStyle(color: muted),
              ),
              TextButton(
                onPressed: () => command(DeviceAction.cancelTransfer),
                child: const UiText('Pause transfer'),
              ),
            ],
            const SizedBox(height: 24),
            if (model.signedIn)
              TextButton(
                onPressed: () => startPhone(context, model),
                child: const UiText('Record with phone'),
              ),
            const UiText(
              'Reconnecting does not start a recording. If Bluetooth disconnects, check the recorder before starting another recording.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      );
    },
  );
}

class RecorderSheet extends StatefulWidget {
  const RecorderSheet(this.model, {super.key});
  final TenoModel model;
  @override
  State<RecorderSheet> createState() => _RecorderSheetState();
}

class _RecorderSheetState extends State<RecorderSheet> {
  late final notes = TextEditingController(
    text: widget.model.runtime?.capture.notes,
  );
  Timer? debounce;
  bool preview = false, writing = false;
  String ownerId = '';
  @override
  void initState() {
    super.initState();
    ownerId = widget.model.runtime!.capture.localId;
  }

  Future<void> save() async {
    final id = widget.model.runtime!.capture.localId;
    if (id.isNotEmpty) ownerId = id;
    if (ownerId.isNotEmpty)
      await widget.model.host.saveNotes(ownerId, notes.text);
  }

  Future<void> control(bool stop) async => perform(context, () async {
    if (stop &&
        !await confirm(
          context,
          'Stop recording?',
          'The complete recording will be saved on this phone. Your cloud processing preference will apply.',
        ))
      return;
    debounce?.cancel();
    await save();
    final c = widget.model.runtime!.capture;
    if (c.source == 'device') {
      await widget.model.host.controlDevice(
        stop
            ? DeviceAction.stop
            : c.phase == 'paused'
            ? DeviceAction.resume
            : DeviceAction.pause,
        '',
        '',
      );
    } else {
      await widget.model.host.controlPhone(
        stop
            ? PhoneAction.stop
            : c.phase == 'paused'
            ? PhoneAction.resume
            : PhoneAction.pause,
      );
    }
  });
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.model,
    builder: (context, _) {
      final c = widget.model.runtime!.capture;
      final active =
          ['recording', 'paused'].contains(c.phase) &&
          (c.source != 'device' || !widget.model.runtime!.device.busy);
      final finished =
          !widget.model.capturing && !widget.model.runtime!.device.receiving;
      final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
      return SizedBox(
        height:
            MediaQuery.sizeOf(context).height *
            (keyboardOpen
                ? .94
                : MediaQuery.textScalerOf(context).scale(1) > 1.2
                ? .72
                : .51),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            0,
            22,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 4,
                  margin: const EdgeInsets.only(top: 6, bottom: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(74, 42),
                      shape: const StadiumBorder(),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
                    ),
                    onPressed: active ? () => control(false) : null,
                    child: UiText(c.phase == 'paused' ? 'Resume' : 'Pause'),
                  ),
                  Flexible(
                    child: Text(
                      duration(c.elapsedMs),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 42),
                      shape: const StadiumBorder(),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
                    ),
                    onPressed: active ? () => control(true) : null,
                    child: const UiText('Stop'),
                  ),
                ],
              ),
              if (!keyboardOpen) ...[
                const SizedBox(height: 14),
                const UiText(
                  'Recording highlights',
                  style: TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w300,
                    color: muted,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                if (!['recording', 'paused'].contains(c.phase))
                  Text(
                    ui(context, c.status),
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
              ],
              Expanded(
                child: ListView(
                  children: [
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const UiText(
                        'Live transcript',
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: UiText(
                        c.previewStatus ??
                            (widget.model.runtime!.session.livePreview
                                ? 'Preview · Final transcript follows processing'
                                : 'Live preview is off · Settings > Recorder'),
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                      initiallyExpanded: preview,
                      onExpansionChanged: (v) => preview = v,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: UiText(
                            'Live text is a preview. The complete recording is processed after it is saved and uploaded.',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ),
                        for (final segment in jsonRows(c.segmentsJson))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(text(segment['text'])),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            c.partial,
                            style: const TextStyle(color: muted),
                          ),
                        ),
                      ],
                    ),
                    if (writing || notes.text.isNotEmpty)
                      TextField(
                        controller: notes,
                        minLines: 4,
                        maxLines: null,
                        onChanged: (_) {
                          debounce?.cancel();
                          debounce = Timer(
                            const Duration(milliseconds: 400),
                            () => unawaited(perform(context, save)),
                          );
                        },
                        decoration: const InputDecoration(
                          hint: UiText('Type main ideas'),
                        ),
                      ),
                    if (!writing && notes.text.isEmpty)
                      Column(
                        children: [
                          for (final hint in [
                            (Icons.outlined_flag, 'Mark key moments'),
                            if (widget.model.personalCore)
                              (
                                Icons.camera_alt_outlined,
                                'Capture important visuals',
                              ),
                            (Icons.edit_outlined, 'Type main ideas'),
                          ])
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: Icon(
                                      hint.$1,
                                      color: subtle(context),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      ui(context, hint.$2),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: subtle(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              if (keyboardOpen)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    child: const UiText('Close keyboard'),
                  ),
                )
              else if (c.phase == 'interrupted')
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      navigator.push(
                        MaterialPageRoute<void>(
                          builder: (_) => DevicePage(widget.model),
                        ),
                      );
                    },
                    child: const UiText('Reconnect recorder'),
                  ),
                )
              else if (finished)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await perform(context, save);
                      if (!context.mounted) return;
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      final id = c.localId;
                      if (id.isNotEmpty && !id.startsWith('jwd:'))
                        unawaited(
                          navigator.push(
                            MaterialPageRoute<void>(
                              builder: (_) => LocalPage(widget.model, id),
                            ),
                          ),
                        );
                    },
                    child: const UiText('Done'),
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        CoreAction(
                          Icons.edit_outlined,
                          'Type note',
                          () => setState(() => writing = true),
                          size: 60,
                        ),
                        const SizedBox(height: 8),
                        const UiText(
                          'Type',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                    if (widget.model.personalCore)
                      Column(
                        children: [
                          CoreAction(
                            Icons.camera_alt_outlined,
                            'Photo',
                            active
                                ? () => perform(context, () async {
                                    await widget.model.command('photo', {
                                      'local_id': c.localId,
                                      'at_ms': c.elapsedMs,
                                    });
                                  })
                                : null,
                            size: 60,
                          ),
                          const SizedBox(height: 8),
                          const UiText(
                            'Photo',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                    Column(
                      children: [
                        CoreAction(
                          Icons.flag_outlined,
                          'Add highlight',
                          active
                              ? () {
                                  final addition =
                                      '[' +
                                      duration(c.elapsedMs) +
                                      '] Highlight';
                                  notes.text = notes.text.isEmpty
                                      ? addition
                                      : notes.text + '\n' + addition;
                                  setState(() => writing = true);
                                  unawaited(perform(context, save));
                                }
                              : null,
                          size: 60,
                        ),
                        const SizedBox(height: 8),
                        const UiText(
                          'Highlight',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    },
  );
  @override
  void dispose() {
    debounce?.cancel();
    if (ownerId.isNotEmpty)
      unawaited(
        widget.model.host
            .saveNotes(ownerId, notes.text)
            .catchError((Object _) {}),
      );
    notes.dispose();
    super.dispose();
  }
}
