import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/model.dart';
import '../l10n/ui_strings.dart';
import '../ui/widgets.dart';
import '../ui/personal_widgets.dart';
import 'routes/recorder.dart';

String recorderOperationState(String state) => switch (state) {
  'prepared' => 'Ready to register',
  'awaiting_recipient' => 'Waiting for the recipient',
  'awaiting_owner' => 'Confirm the recipient',
  'ready' => 'Ready for device verification',
  'hardware_pending' => 'Device verification pending',
  'completed' => 'Recorder operation completed',
  'cancelled' => 'Cancelled',
  _ => state,
};

class MyRecordersPage extends StatelessWidget {
  const MyRecordersPage(this.model, {super.key});
  final TenoModel model;
  Future<Json> load() async {
    final values = await Future.wait([
      model.api('GET', '/api/v1/recorders'),
      model.api('GET', '/api/v1/recorders/operations/pending'),
    ]);
    return {'items': values[0]['items'], 'operations': values[1]['items']};
  }

  Future<void> change(
    BuildContext context,
    Json recorder,
    String kind,
    VoidCallback reload,
  ) async {
    final password = TextEditingController();
    bool confirmed = false;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          scrollable: true,
          title: UiText(
            kind == 'transfer'
                ? 'Transfer recorder'
                : 'Release recorder ownership',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const UiText(
                'Card recordings will remain on the card and can be received by the next owner. Your cloud library and local copies stay with your account.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: password,
                onChanged: (_) => update(() {}),
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  label: UiText('Account password'),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: confirmed,
                onChanged: (value) => update(() => confirmed = value == true),
                title: const UiText(
                  'I confirm that the card recordings may be transferred.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const UiText('Cancel'),
            ),
            FilledButton(
              onPressed: confirmed && password.text.isNotEmpty
                  ? () => Navigator.pop(dialog, true)
                  : null,
              child: const UiText('Continue'),
            ),
          ],
        ),
      ),
    );
    final secret = password.text;
    password.clear();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    password.dispose();
    if (approved != true || !context.mounted) return;
    await perform(context, () async {
      final operation = await model
          .api('POST', '/api/v1/recorders/${recorder['id']}/operations', {
            'client_id': requestId(),
            'kind': kind,
            'password': secret,
            'confirm_card_recordings': true,
          });
      if (context.mounted)
        await push(
          context,
          RecorderOperationPage(
            model,
            text(operation['id']),
            transferCode: text(operation['transfer_code']),
          ),
        );
      reload();
    });
  }

  Future<void> accept(BuildContext context, VoidCallback reload) async {
    final code = TextEditingController();
    bool confirmed = false;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          scrollable: true,
          title: const UiText('Receive a recorder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: code,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  label: UiText('Transfer code'),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: confirmed,
                onChanged: (value) => update(() => confirmed = value == true),
                title: const UiText(
                  'I agree to receive the recordings already on this card.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const UiText('Cancel'),
            ),
            FilledButton(
              onPressed: confirmed ? () => Navigator.pop(dialog, true) : null,
              child: const UiText('Receive recorder'),
            ),
          ],
        ),
      ),
    );
    final value = code.text.trim();
    code.clear();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    code.dispose();
    if (approved != true || !context.mounted) return;
    await perform(context, () async {
      final operation = await model.api(
        'POST',
        '/api/v1/recorders/operations/accept',
        {'transfer_code': value, 'confirm_card_recordings': true},
      );
      if (context.mounted)
        await push(
          context,
          RecorderOperationPage(model, text(operation['id'])),
        );
      reload();
    });
  }

  @override
  Widget build(BuildContext context) => CoreFrame(
    title: 'My recorders',
    child: CoreLoad(
      load: load,
      builder: (context, data, reload) => ListView(
        padding: const EdgeInsets.all(coreInset),
        children: [
          const UiText(
            'One account can own several recorders. Each recorder belongs to one account at a time.',
          ),
          if (model.webExperience)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: UiText(
                'Use the mobile app with your recorder nearby to register, restore or transfer it.',
              ),
            ),
          if (!model.webExperience) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                await push(context, DevicePage(model));
                reload();
              },
              icon: const Icon(Icons.bluetooth),
              label: const UiText('Connect a recorder'),
            ),
            TextButton(
              onPressed: () => accept(context, reload),
              child: const UiText('Receive a recorder'),
            ),
          ],
          for (final card in rows(data['items']))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text(card['name']),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${ui(context, 'Recorder identity')}: ${text(card['hardware_id'])}',
                    ),
                    Text(
                      '${ui(context, 'Authorization generation')}: ${card['epoch']}',
                    ),
                    if (card['recoverable'] == true)
                      const UiText('Authorization backed up for this account'),
                    if (!model.webExperience)
                      Wrap(
                        spacing: 10,
                        children: [
                          TextButton(
                            onPressed: () => perform(context, () async {
                              await model.command('recorder_select', {
                                'hardware_id': card['hardware_id'],
                              });
                              if (context.mounted)
                                await push(context, DevicePage(model));
                              reload();
                            }),
                            child: const UiText('Use this recorder'),
                          ),
                          if (text(card['operation_id']).isEmpty) ...[
                            TextButton(
                              onPressed: () =>
                                  change(context, card, 'transfer', reload),
                              child: const UiText('Transfer recorder'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  change(context, card, 'release', reload),
                              child: const UiText('Release recorder ownership'),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),
          if (rows(data['operations']).isNotEmpty)
            heading('Recorder operations'),
          for (final operation in rows(data['operations']))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(text(object(operation['recorder'])['name'])),
              subtitle: UiText(
                recorderOperationState(text(operation['state'])),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await push(
                  context,
                  RecorderOperationPage(model, text(operation['id'])),
                );
                reload();
              },
            ),
          if (rows(data['items']).isEmpty && rows(data['operations']).isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: UiText('No recorders registered to this account yet.'),
            ),
          TextButton(onPressed: reload, child: const UiText('Refresh')),
        ],
      ),
    ),
  );
}

class RecorderOperationPage extends StatefulWidget {
  const RecorderOperationPage(
    this.model,
    this.id, {
    super.key,
    this.transferCode = '',
  });
  final TenoModel model;
  final String id, transferCode;
  @override
  State<RecorderOperationPage> createState() => _RecorderOperationPageState();
}

class _RecorderOperationPageState extends State<RecorderOperationPage> {
  Timer? timer;
  VoidCallback? reload;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !busy && (ModalRoute.of(context)?.isCurrent ?? false))
        reload?.call();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> action(Future<void> Function() work) =>
      perform(context, () async {
        if (busy) return;
        setState(() => busy = true);
        try {
          await work();
          reload?.call();
        } finally {
          if (mounted) setState(() => busy = false);
        }
      });
  @override
  Widget build(BuildContext context) => CoreFrame(
    title: 'Recorder operation',
    child: CoreLoad(
      load: () async {
        final value = await widget.model.api(
          'GET',
          '/api/v1/recorders/operations/${widget.id}',
        );
        if (!widget.model.webExperience)
          value['native'] = await widget.model.command('recorder_ownership');
        return value;
      },
      builder: (context, data, refresh) {
        reload = refresh;
        final state = text(data['state']),
            mine = data['initiated_by_me'] == true,
            native = object(data['native']);
        return ListView(
          padding: const EdgeInsets.all(coreInset),
          children: [
            Text(
              text(object(data['recorder'])['name']),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            heading(recorderOperationState(state)),
            if (text(data['recipient']).isNotEmpty)
              Text('${ui(context, 'Recipient')}: ${data['recipient']}'),
            const UiText(
              'The app verifies the same recorder, checks all card files, changes authorization, and confirms that the old code is rejected. Keep the recorder nearby and do not start a recording.',
            ),
            if (state == 'awaiting_recipient' &&
                widget.transferCode.isNotEmpty) ...[
              const SizedBox(height: 16),
              SelectableText(widget.transferCode),
              TextButton(
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: widget.transferCode)),
                child: const UiText('Copy transfer code'),
              ),
              const UiText(
                'The recipient enters this code in My recorders. It does not grant access to your cloud library.',
              ),
            ],
            if (state != 'completed' && state != 'cancelled')
              Text(
                '${ui(context, 'Prepared at')}: ${dateLabel(data['updated_at'])}',
              ),
            if (widget.model.webExperience)
              const UiText('Continue this operation in the mobile app.'),
            if (!widget.model.webExperience && mine) ...[
              if (state == 'awaiting_owner')
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => action(() async {
                          final yes = await showDialog<bool>(
                            context: context,
                            builder: (dialog) => AlertDialog(
                              title: const UiText('Confirm the recipient'),
                              content: Text(text(data['recipient'])),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialog, false),
                                  child: const UiText('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(dialog, true),
                                  child: const UiText('Confirm'),
                                ),
                              ],
                            ),
                          );
                          if (yes == true)
                            await widget.model.api(
                              'POST',
                              '/api/v1/recorders/operations/${widget.id}/approve',
                            );
                        }),
                  child: const UiText('Confirm the recipient'),
                ),
              if (['prepared', 'ready', 'hardware_pending'].contains(state))
                FilledButton(
                  onPressed: busy || native['busy'] == true
                      ? null
                      : () => action(() async {
                          await widget.model.command('recorder_operation', {
                            'operation_id': widget.id,
                          });
                        }),
                  child: UiText(
                    state == 'hardware_pending'
                        ? 'Continue device verification'
                        : 'Verify recorder and finish',
                  ),
                ),
              if (native['operation_id'] == widget.id &&
                  text(native['message']).isNotEmpty)
                UiText(text(native['message'])),
              if (![
                'completed',
                'cancelled',
                'hardware_pending',
              ].contains(state))
                TextButton(
                  onPressed: busy
                      ? null
                      : () => action(() async {
                          await widget.model.api(
                            'POST',
                            '/api/v1/recorders/operations/${widget.id}/cancel',
                          );
                        }),
                  child: const UiText('Cancel operation'),
                ),
            ],
            if (state == 'completed')
              const UiText(
                'Cloud recordings and notes remain with their original account.',
              ),
            TextButton(onPressed: refresh, child: const UiText('Refresh')),
          ],
        );
      },
    ),
  );
}

class RecorderRegistration extends StatefulWidget {
  const RecorderRegistration(this.model, {super.key});
  final TenoModel model;
  @override
  State<RecorderRegistration> createState() => _RecorderRegistrationState();
}

class _RecorderRegistrationState extends State<RecorderRegistration> {
  Json value = {};
  Timer? timer;
  bool loading = false;
  @override
  void initState() {
    super.initState();
    poll();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => poll());
  }

  Future<void> poll() async {
    if (loading || !widget.model.signedIn) return;
    loading = true;
    try {
      final next = await widget.model.command('recorder_ownership');
      if (mounted) setState(() => value = next);
    } catch (_) {
    } finally {
      loading = false;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> claim() async {
    final key = TextEditingController();
    bool agreed = false;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          scrollable: true,
          title: const UiText('Register this recorder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${ui(context, 'Recorder identity')}: ${text(value['hardware_id'])}',
              ),
              const UiText(
                'This recorder will belong to your account. Existing card recordings will sync using your cloud processing settings.',
              ),
              TextField(
                controller: key,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 16,
                decoration: const InputDecoration(
                  label: UiText('Original device code, if needed'),
                ),
              ),
              const UiText(
                'Leave this blank for a new recorder or when the original code is already saved on this phone.',
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: agreed,
                onChanged: (value) => update(() => agreed = value == true),
                title: const UiText(
                  'I agree to receive the recordings already on this card.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const UiText('Cancel'),
            ),
            FilledButton(
              onPressed: agreed ? () => Navigator.pop(dialog, true) : null,
              child: const UiText('Register recorder'),
            ),
          ],
        ),
      ),
    );
    final original = key.text;
    key.clear();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    key.dispose();
    if (yes == true && mounted)
      await perform(
        context,
        () => widget.model.command('recorder_claim', {
          'confirm': true,
          'original_key': original,
        }),
      );
    await poll();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (value['claim_required'] == true)
        FilledButton(
          onPressed: value['busy'] == true ? null : claim,
          child: const UiText('Register this recorder'),
        ),
      if (text(value['operation_id']).isNotEmpty)
        TextButton(
          onPressed: () => push(
            context,
            RecorderOperationPage(widget.model, text(value['operation_id'])),
          ),
          child: const UiText('Open recorder operation'),
        ),
      TextButton.icon(
        onPressed: () => push(context, MyRecordersPage(widget.model)),
        icon: const Icon(Icons.devices_other),
        label: const UiText('My recorders'),
      ),
    ],
  );
}
