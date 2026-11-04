import 'dart:async';
import 'package:flutter/material.dart';
import '../core/model.dart';
import '../ui/widgets.dart';
import 'library.dart';
import 'recorder.dart';

class SettingsBody extends StatelessWidget {
  const SettingsBody(this.model, {super.key});
  final TenoModel model;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(23),
    children: [
      const Text('Workspace', style: TextStyle(color: muted, fontSize: 12)),
      MenuRow(
        Icons.tune,
        'Preferences',
        () => push(context, PreferencesPage(model)),
      ),
      MenuRow(
        Icons.speaker_phone_outlined,
        'Recorder',
        () => push(context, DevicePage(model)),
      ),
      MenuRow(
        Icons.phone_android,
        'Local recordings',
        () => push(context, LocalListPage(model)),
      ),
      const Divider(height: 36),
      const Text('Account', style: TextStyle(color: muted, fontSize: 12)),
      MenuRow(
        Icons.person_outline,
        model.runtime!.session.username,
        null,
        subtitle: 'Your existing Teno account',
      ),
      MenuRow(
        Icons.cloud_outlined,
        'Server',
        null,
        subtitle: model.runtime!.session.server,
      ),
      const Divider(height: 36),
      const Text('General', style: TextStyle(color: muted, fontSize: 12)),
      MenuRow(
        Icons.delete_outline,
        'Trash',
        () => push(context, TrashPage(model)),
      ),
      MenuRow(
        Icons.help_outline,
        'Help & support',
        () => push(context, const HelpPage()),
      ),
      MenuRow(
        Icons.info_outline,
        'Teno',
        null,
        subtitle: '0.5.0 · Internal testing',
      ),
      const SizedBox(height: 24),
      OutlinedButton(
        onPressed: () => perform(context, () async {
          if (await confirm(
            context,
            'Sign out?',
            'Local recordings and device keys stay on this phone. Sign in to the same account to access its files again.',
          )) {
            await model.signOut();
          }
        }),
        child: const Text('Sign out'),
      ),
    ],
  );
}

class PreferencesPage extends StatefulWidget {
  const PreferencesPage(this.model, {super.key});
  final TenoModel model;
  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  Json preferences = {};
  String error = '';
  bool loading = false;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final me = await widget.model.api('GET', '/api/v1/me');
      if (mounted) setState(() => preferences = object(me['settings']));
    } catch (e) {
      if (mounted) setState(() => error = TenoModel.friendly(e));
    }
  }

  Future<void> configure({bool? cloud, bool? wifi, bool? live}) =>
      perform(context, () async {
        final s = widget.model.runtime!.session;
        await widget.model.host.configure(
          cloud ?? s.cloudUpload,
          wifi ?? s.wifiOnly,
          live ?? s.livePreview,
        );
        widget.model.changed(await widget.model.host.snapshot());
      });
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.model,
    builder: (context, _) {
      final s = widget.model.runtime!.session;
      return PageFrame(
        title: 'Preferences',
        child: ListView(
          padding: const EdgeInsets.all(23),
          children: [
            if (error.isNotEmpty) ErrorNotice(error, retry: load),
            const Text(
              'Recording',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cloud processing'),
              subtitle: const Text(
                'Automatically upload saved audio for transcription and summary.',
              ),
              value: s.cloudUpload,
              onChanged: (v) => configure(cloud: v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Upload on Wi-Fi only'),
              value: s.wifiOnly,
              onChanged: (v) => configure(wifi: v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Live transcript preview'),
              subtitle: const Text(
                'Applies to your next recording. Complete audio is processed again after recording.',
              ),
              value: s.livePreview,
              onChanged: (v) => configure(live: v),
            ),
            const Divider(height: 36),
            const Text(
              'Transcription & summary',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            const MenuRow(
              Icons.translate,
              'Audio language',
              null,
              trailing: Text('Automatic', style: TextStyle(color: muted)),
            ),
            const Text(
              'Language detection is automatic for recordings and imports.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue:
                  text(preferences['summary_language']).startsWith('zh')
                  ? 'zh-CN'
                  : 'en-US',
              decoration: const InputDecoration(
                labelText: 'Generated content language',
              ),
              items: const [
                DropdownMenuItem(value: 'en-US', child: Text('English')),
                DropdownMenuItem(value: 'zh-CN', child: Text('Chinese')),
              ],
              onChanged: loading || preferences.isEmpty
                  ? null
                  : (value) => perform(context, () async {
                      if (value == null) return;
                      setState(() => loading = true);
                      try {
                        await widget.model.api('PATCH', '/api/v1/me', {
                          'language': 'auto',
                          'summary_language': value,
                          'timezone':
                              preferences['timezone'] ?? 'Asia/Shanghai',
                        });
                        await load();
                      } finally {
                        if (mounted) setState(() => loading = false);
                      }
                    }),
            ),
            const SizedBox(height: 28),
            const Text(
              'Local storage',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            const Text(
              'Complete recordings are automatically kept on this phone. Cloud upload never removes a local recording.',
            ),
          ],
        ),
      );
    },
  );
}

class TemplatesBody extends StatefulWidget {
  const TemplatesBody(this.model, {super.key});
  final TenoModel model;
  @override
  State<TemplatesBody> createState() => _TemplatesBodyState();
}

class _TemplatesBodyState extends State<TemplatesBody> {
  late Future<List<Json>> pending;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    setState(() => pending = widget.model.list('/api/v1/templates?limit=200'));
  }

  Future<void> edit([Json? original]) async {
    await push(context, TemplateEditor(widget.model, original));
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Json>>(
    future: pending,
    builder: (context, snapshot) => ListView(
      padding: const EdgeInsets.all(23),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Templates',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
              ),
            ),
            CircleAction(Icons.add, 'New template', () => edit()),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: line),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_outlined),
              SizedBox(height: 24),
              Text('Default summary', style: TextStyle(fontSize: 22)),
              SizedBox(height: 10),
              Text(
                'Overview, key points and next steps from your conversation.',
                style: TextStyle(color: muted),
              ),
              SizedBox(height: 22),
              Text('Teno', style: TextStyle(color: muted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'My templates',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
        ),
        if (snapshot.hasError)
          ErrorNotice(TenoModel.friendly(snapshot.error!), retry: reload),
        if (!snapshot.hasData && !snapshot.hasError)
          const LinearProgressIndicator(minHeight: 2),
        for (final item in snapshot.data ?? <Json>[])
          MenuRow(
            Icons.description_outlined,
            text(object(item['data'])['title']),
            () => edit(item),
            subtitle: text(object(item['data'])['prompt']),
          ),
      ],
    ),
  );
}

class TemplatePicker extends StatefulWidget {
  const TemplatePicker(this.model, {super.key});
  final TenoModel model;
  @override
  State<TemplatePicker> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends State<TemplatePicker> {
  late Future<List<Json>> pending = widget.model.list(
    '/api/v1/templates?limit=200',
  );
  String selected = '';
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Generate',
    bottom: FilledButton(
      onPressed: () => Navigator.pop(context, selected),
      child: const Text('Generate'),
    ),
    child: RadioGroup<String>(
      groupValue: selected,
      onChanged: (value) => setState(() => selected = value ?? ''),
      child: ListView(
        padding: const EdgeInsets.all(23),
        children: [
          const Text(
            'Transcription & summary',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          const MenuRow(
            Icons.translate,
            'Audio language',
            null,
            trailing: Text('Automatic', style: TextStyle(color: muted)),
          ),
          const Divider(height: 36),
          const Text('Summary template', style: TextStyle(fontSize: 18)),
          RadioListTile<String>(
            value: '',
            title: const Text('Default summary'),
            subtitle: const Text('Overview, key points and next steps'),
          ),
          FutureBuilder<List<Json>>(
            future: pending,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return ErrorNotice(
                  TenoModel.friendly(snapshot.error!),
                  retry: () => setState(
                    () => pending = widget.model.list(
                      '/api/v1/templates?limit=200',
                    ),
                  ),
                );
              if (!snapshot.hasData)
                return const LinearProgressIndicator(minHeight: 2);
              return Column(
                children: [
                  for (final item in snapshot.data!)
                    RadioListTile<String>(
                      value: text(item['id']),
                      title: Text(text(object(item['data'])['title'])),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

class TemplateEditor extends StatefulWidget {
  const TemplateEditor(this.model, this.original, {super.key});
  final TenoModel model;
  final Json? original;
  @override
  State<TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<TemplateEditor> {
  late final title = TextEditingController(
    text: text(object(widget.original?['data'])['title']),
  );
  late final prompt = TextEditingController(
    text: text(object(widget.original?['data'])['prompt']),
  );
  bool busy = false;
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Summary template',
    bottom: FilledButton(
      onPressed: busy
          ? null
          : () => perform(context, () async {
              if (title.text.trim().isEmpty || prompt.text.trim().isEmpty)
                throw StateError('Add a title and instructions.');
              setState(() => busy = true);
              try {
                await widget.model.api(
                  widget.original == null ? 'POST' : 'PATCH',
                  '/api/v1/templates' +
                      (widget.original == null
                          ? ''
                          : '/' + text(widget.original!['id'])),
                  {'title': title.text.trim(), 'prompt': prompt.text.trim()},
                );
                if (context.mounted) Navigator.pop(context);
              } finally {
                if (mounted) setState(() => busy = false);
              }
            }),
      child: const Text('Save template'),
    ),
    child: ListView(
      padding: const EdgeInsets.all(23),
      children: [
        TextField(
          controller: title,
          maxLength: 300,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: prompt,
          minLines: 8,
          maxLines: 16,
          maxLength: 4000,
          decoration: const InputDecoration(labelText: 'Summary instructions'),
        ),
        if (widget.original != null)
          TextButton(
            onPressed: () => perform(context, () async {
              if (!await confirm(
                context,
                'Delete template?',
                'Existing summaries will be preserved.',
              ))
                return;
              await widget.model.api(
                'DELETE',
                '/api/v1/templates/' + text(widget.original!['id']),
              );
              if (context.mounted) Navigator.pop(context);
            }),
            child: const Text(
              'Delete template',
              style: TextStyle(color: Colors.red),
            ),
          ),
      ],
    ),
  );
  @override
  void dispose() {
    title.dispose();
    prompt.dispose();
    super.dispose();
  }
}

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});
  @override
  Widget build(BuildContext context) => const PageFrame(
    title: 'Help & support',
    child: SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recording with Teno',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 20),
          Text(
            'Connect a JWD recorder, check its service, then authorize it with its device key. Keep the original key to connect from another phone.',
          ),
          SizedBox(height: 16),
          Text(
            'Pause, resume and stop wait for recorder confirmation. Bluetooth disconnection does not stop the recorder. Check the hardware before retrying.',
          ),
          SizedBox(height: 16),
          Text(
            'Complete files are verified and saved locally before cloud upload. Reconnect to retry an interrupted transfer. Device originals are not automatically deleted.',
          ),
          SizedBox(height: 16),
          Text(
            'Live text is a preview. The complete recording is processed after recording for the final transcript and summary.',
          ),
          SizedBox(height: 16),
          Text(
            'Phone recordings: up to 54 minutes. JWD Bluetooth imports: up to 60 minutes / 100 MiB. Audio file imports: up to 120 minutes / 250 MiB.',
          ),
          SizedBox(height: 16),
          Text(
            'iPhone background activity follows iOS rules. After force quitting, reopen Teno to resume queued work.',
          ),
        ],
      ),
    ),
  );
}
