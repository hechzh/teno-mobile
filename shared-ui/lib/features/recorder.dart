import '../l10n/ui_strings.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/model.dart';
import '../platform/runtime.g.dart';
import '../ui/widgets.dart';
import '../ui/processing_progress.dart';
import '../ui/personal_widgets.dart';
import 'detail.dart';
import 'generation_options.dart';
import 'personal_import.dart';
import 'personal_recorders.dart';

Future<void> startPhone(BuildContext context, TenoModel model) async =>
    perform(context, () async {
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
  const DevicePage(this.model, {super.key, this.selectedHardwareId = ''});
  final TenoModel model;
  final String selectedHardwareId;
  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  TenoModel get model => widget.model;
  bool initiating = false;
  int scanAttempt = 0;
  bool showNearby = false;
  String deviceError = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          model.signedIn &&
          !model.runtime!.device.authorized &&
          !model.runtime!.device.connected &&
          !model.runtime!.device.busy &&
          !model.runtime!.device.scanning) {
        connectAutomatically();
      }
    });
  }

  @override
  void dispose() {
    final device = model.runtime?.device;
    if (device != null &&
        !device.authorized &&
        (initiating || device.scanning || device.busy || device.connected)) {
      unawaited(
        model.host
            .controlDevice(DeviceAction.disconnect, '', '')
            .catchError((_) {}),
      );
    }
    super.dispose();
  }

  Future<void> command(
    DeviceAction action, {
    String id = '',
    String name = '',
  }) async {
    if (action == DeviceAction.disconnect) {
      scanAttempt++;
      if (initiating) setState(() => initiating = false);
    }
    if (deviceError.isNotEmpty) setState(() => deviceError = '');
    try {
      await model.host.controlDevice(action, id, name);
    } catch (e) {
      if (mounted) setState(() => deviceError = TenoModel.friendly(e));
    }
  }

  Future<void> connectAutomatically([
    DeviceAction action = DeviceAction.scan,
  ]) async {
    if (initiating || !model.signedIn) return;
    final scope = model.runtime!.session.scope;
    final attempt = ++scanAttempt;
    setState(() {
      initiating = true;
      deviceError = '';
    });
    try {
      // Claim also provisions the key. Offline owners can still scan and reconnect.
      try {
        await model
            .api('POST', '/api/v1/recorders/prepare', {})
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
      if (!mounted ||
          attempt != scanAttempt ||
          !model.signedIn ||
          model.runtime!.session.scope != scope ||
          ModalRoute.of(context)?.isCurrent == false)
        return;
      final device = model.runtime!.device;
      if (!device.connected && !device.busy && !device.scanning)
        await command(action);
    } finally {
      if (mounted && attempt == scanAttempt) setState(() => initiating = false);
    }
  }

  Future<void> restoreDeviceCode(String id, String name) async {
    if (!model.signedIn) return;
    final key = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: const UiText('Restore original device code'),
        content: TextField(
          controller: key,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 16,
          decoration: const InputDecoration(
            label: UiText('Original 16-character key'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const UiText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const UiText('Use original key'),
          ),
        ],
      ),
    );
    final value = key.text;
    key.clear();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    key.dispose();
    if (accepted != true || !mounted) return;
    await perform(context, () => model.host.bindDevice(id, name, value, false));
  }

  Future<void> confirmPhysicalRecorder(Json row) async {
    final owner = model.runtime!.session.scope;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const UiText('Authorize this recorder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text(row['name']),
              style: Theme.of(dialog).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            UiText(
              row['operation_compat'] == true
                  ? 'Confirm that this is the recorder for your pending operation. Teno will verify its authorization and hardware ID before continuing.'
                  : 'Confirm that this is the recorder in your hand. An unbound recorder will store your account key. After its hardware ID and ownership are verified, recordings on this card can sync to your account.',
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
            child: const UiText('Confirm and authorize'),
          ),
        ],
      ),
    );
    if (!mounted ||
        accepted != true ||
        !model.signedIn ||
        model.runtime!.session.scope != owner)
      return;
    await perform(
      context,
      () => model.command('recorder_identity_compat', {
        'address': row['address'],
        'compat_token': row['compat_token'],
        'confirm': true,
        if (widget.selectedHardwareId.isNotEmpty)
          'selected_hardware_id': widget.selectedHardwareId,
      }),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) {
      final device = model.runtime!.device;
      if (!model.signedIn)
        return const PageFrame(
          title: 'Recorder',
          child: Center(child: UiText('Sign in to continue.')),
        );
      final connecting = initiating || device.busy || device.scanning;
      final nearby = jsonRows(device.candidatesJson)
          .where(
            (row) =>
                text(row['address']).isNotEmpty &&
                (row['scan_source'] != 'remembered' ||
                    row['gatt_status'] == 'verified'),
          )
          .toList();
      final rejected = nearby
          .where(
            (row) =>
                row['key_rejected'] == true && row['gatt_status'] == 'verified',
          )
          .firstOrNull;
      final physical = device.connected && !device.authorized && !device.busy
          ? nearby
                .where(
                  (row) =>
                      row['address'] == device.identifier &&
                      row['gatt_status'] == 'verified' &&
                      row['identity_timeout'] == true &&
                      text(row['compat_token']).isNotEmpty,
                )
                .firstOrNull
          : null;
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
              const UiText('Saved on recorder'),
              Text(
                statusText(context, device.status),
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
                  : ui(
                      context,
                      connecting
                          ? 'Connecting your JWD recorder'
                          : device.connected
                          ? 'Recorder found'
                          : 'Recorder not connected',
                    ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              statusText(
                context,
                deviceError.isEmpty ? device.status : deviceError,
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 24),
            if (physical != null)
              FilledButton.icon(
                onPressed: () => confirmPhysicalRecorder(physical),
                icon: const Icon(Icons.bluetooth_connected),
                label: const UiText('Authorize this recorder'),
              ),
            RecorderRegistration(model),
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
                onPressed: device.busy
                    ? null
                    : () => perform(context, () async {
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
                  model.capturing ? 'Return to recording' : 'Start recording',
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
              if (connecting) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 20),
                const UiText(
                  'Searching, verifying and connecting automatically.',
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () => command(DeviceAction.disconnect),
                  child: const UiText('Cancel connection'),
                ),
              ] else if (!device.connected) ...[
                FilledButton(
                  onPressed: connectAutomatically,
                  child: const UiText('Retry connection'),
                ),
                if (defaultTargetPlatform == TargetPlatform.android)
                  TextButton(
                    onPressed: () =>
                        connectAutomatically(DeviceAction.compatibilityScan),
                    child: const UiText('Compatibility scan'),
                  ),
                if (rejected != null)
                  TextButton(
                    onPressed: () => restoreDeviceCode(
                      text(rejected['address']),
                      text(rejected['name']),
                    ),
                    child: const UiText('Restore original device code'),
                  ),
              ] else
                TextButton(
                  onPressed: () => command(DeviceAction.disconnect),
                  child: const UiText('Disconnect'),
                ),
              if (!device.connected && nearby.isNotEmpty) ...[
                TextButton(
                  onPressed: () => setState(() => showNearby = !showNearby),
                  child: Text(
                    showNearby
                        ? ui(context, 'Hide other devices')
                        : context.strings.otherDeviceCount(nearby.length),
                  ),
                ),
                if (showNearby)
                  for (final row in nearby)
                    ListTile(
                      title: Text(
                        text(row['name']).isEmpty ||
                                row['name'] == 'Unnamed Bluetooth device'
                            ? text(row['address'])
                            : text(row['name']),
                      ),
                      subtitle: Text(
                        statusText(
                          context,
                          text(row['probe_error']).isNotEmpty
                              ? text(row['probe_error'])
                              : switch (row['gatt_status']) {
                                  'verified' =>
                                    'Recording service verified · Connect',
                                  'unsupported' =>
                                    'Recording service unavailable',
                                  _ =>
                                    row['jwd'] == true ||
                                            row['name_match'] == true
                                        ? 'Ready for device verification'
                                        : 'Unrecognized device · Check recording service',
                                },
                        ),
                      ),
                      enabled:
                          !initiating &&
                          !device.busy &&
                          row['gatt_status'] != 'unsupported',
                      onTap: () => command(
                        row['gatt_status'] == 'verified'
                            ? DeviceAction.connect
                            : DeviceAction.probe,
                        id: text(row['address']),
                        name: text(row['name']),
                      ),
                    ),
              ],
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
  bool writing = false;
  String ownerId = '';
  String template = '@default';
  String? outputLanguage;
  bool optionsTouched = false;
  @override
  void initState() {
    super.initState();
    ownerId = widget.model.runtime!.capture.localId;
    if (ownerId.isNotEmpty) unawaited(restoreOptions());
  }

  Future<void> restoreOptions() async {
    try {
      final value = await widget.model.command('note_template', {
        'id': ownerId,
      });
      if (mounted && !optionsTouched)
        setState(() {
          template = text(value['template_id']).isEmpty
              ? '@default'
              : text(value['template_id']);
          outputLanguage = value['output_language_origin'] == 'override'
              ? text(value['output_language'])
              : null;
        });
    } catch (_) {
      /* Older hosts keep defaults. */
    }
  }

  Future<void> saveOptions() async {
    final id = widget.model.runtime!.capture.localId;
    if (id.isNotEmpty)
      await widget.model.command('note_template', {
        'id': id,
        'template_id': template,
        ...widget.model.generationLanguage(outputLanguage),
      });
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
    // A preference write must never prevent the recorder from saving audio.
    if (stop) {
      try {
        await saveOptions();
      } catch (_) {}
    }
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
                ? .92
                : .82),
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
              if (!keyboardOpen && active)
                GenerationOptions(
                  widget.model,
                  template: template,
                  language: outputLanguage,
                  onLanguage: (value) async {
                    optionsTouched = true;
                    final old = outputLanguage;
                    outputLanguage = value;
                    try {
                      await saveOptions();
                      if (mounted) setState(() {});
                    } catch (_) {
                      outputLanguage = old;
                      rethrow;
                    }
                  },
                  onTemplate: (value) async {
                    optionsTouched = true;
                    final old = template;
                    template = value;
                    try {
                      await saveOptions();
                      if (mounted) setState(() {});
                    } catch (_) {
                      template = old;
                      rethrow;
                    }
                  },
                ),
              if (!keyboardOpen && widget.model.runtime!.device.receiving)
                ProcessingProgress({
                  'stage': 'syncing',
                  'stage_status': 'running',
                  'preserved': {'device_file': true},
                  if (widget.model.runtime!.device.expectedBytes > 0)
                    'percent':
                        (widget.model.runtime!.device.receivedBytes *
                                100 /
                                widget.model.runtime!.device.expectedBytes)
                            .floor(),
                }),
              if (!keyboardOpen &&
                  finished &&
                  c.localId.isNotEmpty &&
                  !c.localId.startsWith('jwd:'))
                TextButton(
                  onPressed: () =>
                      push(context, PersonalLocalPage(widget.model, c.localId)),
                  child: const UiText('Saved recording & template'),
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
                    statusText(context, c.status),
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
              ],
              Expanded(
                child: ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: UiText(
                        'Transcription starts after recording is saved and uploaded. Cloud processing settings apply.',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
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
