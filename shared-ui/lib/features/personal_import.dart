import '../l10n/ui_strings.dart';
import 'package:flutter/material.dart';
import '../core/model.dart';
import '../ui/widgets.dart';
import '../ui/personal_widgets.dart';
import 'detail.dart';
import 'routes/personal_library.dart';
import 'routes/personal_recording.dart';

Future<void> showPersonalImport(
  BuildContext context,
  TenoModel model, {
  bool pending = false,
}) async {
  await showCoreSheet<void>(
    context,
    PersonalImportPage(model, pending: pending, sheet: true),
    height: pending ? 620 : 510,
  );
}

class PersonalImportPage extends StatefulWidget {
  const PersonalImportPage(
    this.model, {
    super.key,
    this.pending = false,
    this.sheet = false,
  });
  final TenoModel model;
  final bool pending, sheet;
  @override
  State<PersonalImportPage> createState() => _PersonalImportPageState();
}

class _PersonalImportPageState extends State<PersonalImportPage> {
  bool busy = false;
  List<Json> imported = [];
  String error = '';
  Future<void> pick(String source) async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final value = await widget.model.command('import', {'source': source});
      if (!mounted) return;
      setState(() => imported = rows(value['items']));
      widget.model.changed(await widget.model.host.snapshot());
      if (imported.length == 1 && imported.first['type'] == 'local' && mounted)
        await push(
          context,
          PersonalLocalPage(widget.model, text(imported.first['id'])),
        );
    } catch (e) {
      if (mounted) setState(() => error = TenoModel.friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CoreFrame(
    title: 'Import',
    sheet: widget.sheet,
    child: ListView(
      padding: const EdgeInsets.all(21),
      children: [
        if (error.isNotEmpty) ErrorNotice(error),
        if (busy) const LinearProgressIndicator(minHeight: 2),
        for (final row in [
          ('files', 'From Files', Icons.folder_outlined),
          ('photos', 'From Photos', Icons.photo_library_outlined),
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(row.$3),
            title: UiText(row.$2),
            trailing: const Icon(Icons.chevron_right, size: 19),
            onTap: busy ? null : () => pick(row.$1),
          ),
        if (!widget.model.webExperience)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.ios_share_outlined),
            title: const UiText('From other apps'),
            trailing: const Icon(Icons.chevron_right, size: 19),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              builder: (sheet) => const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: UiText(
                    'Open the file in another app, tap Share, then choose Teno.',
                  ),
                ),
              ),
            ),
          ),
        const Divider(height: 32),
        UiText(
          'Audio and video · Up to 120 minutes / 250 MiB',
          style: TextStyle(fontSize: 12, color: subtle(context)),
        ),
        UiText(
          'Images · 20 MB    Documents · 15 MB    Text · 2 MB',
          style: TextStyle(fontSize: 12, color: subtle(context)),
        ),
        const SizedBox(height: 12),
        UiText(
          widget.model.webExperience
              ? 'Files are saved in this browser. Choose Upload and process to send them to your signed-in account. Keep this tab open until upload finishes.'
              : widget.model.runtime!.session.cloudUpload
              ? 'Cloud processing is on. Imported files are saved on this phone, then uploaded and processed automatically.'
              : 'Cloud processing is off. Imported files stay on this phone until you choose Upload and process.',
          style: TextStyle(fontSize: 12, color: subtle(context)),
        ),
        CoreLoad(
          load: () => widget.model.command('pending_imports'),
          builder: (context, data, reload) {
            final pending = rows(data['items']);
            if (pending.isEmpty && text(data['error']).isEmpty)
              return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading('Shared with Teno'),
                if (text(data['error']).isNotEmpty)
                  ErrorNotice(text(data['error'])),
                Text('Import into ${widget.model.runtime!.session.username}'),
                for (final p in pending)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(text(p['title'])),
                  ),
                FilledButton(
                  onPressed: () => perform(context, () async {
                    final value = await widget.model.command('accept_imports');
                    widget.model.changed(await widget.model.host.snapshot());
                    if (mounted)
                      setState(() => imported = rows(value['items']));
                    reload();
                  }),
                  child: const UiText('Import files'),
                ),
                TextButton(
                  onPressed: () => perform(context, () async {
                    await widget.model.command('discard_imports');
                    reload();
                  }),
                  child: const UiText('Discard pending imports'),
                ),
              ],
            );
          },
        ),
        if (imported.isNotEmpty) ...[
          heading(
            widget.model.webExperience
                ? 'Saved in this browser'
                : 'Saved on this phone',
          ),
          for (final value in imported)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                text(value['title']).isEmpty
                    ? 'Imported'
                    : text(value['title']),
              ),
              subtitle: value['type'] == 'calendar'
                  ? Text('${value['count']} calendar events imported')
                  : null,
              trailing: value['type'] == 'calendar'
                  ? null
                  : const Icon(Icons.chevron_right, size: 18),
              onTap: value['type'] == 'calendar'
                  ? null
                  : () => push(
                      context,
                      PersonalLocalPage(widget.model, text(value['id'])),
                    ),
            ),
        ],
      ],
    ),
  );
}

class PersonalLocalList extends StatelessWidget {
  const PersonalLocalList(this.model, {super.key});
  final TenoModel model;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) => CoreFrame(
      title: model.webExperience ? 'Browser imports' : 'On this phone',
      actions: [
        PopupMenuButton<String>(
          onSelected: (_) => perform(context, () async {
            for (final d in model.drafts.where(
              (d) =>
                  text(d['recording_id']).isEmpty &&
                  text(d['file_id']).isEmpty &&
                  !['recording', 'invalid'].contains(d['status']),
            ))
              await model.host.retryUpload(text(d['id']));
          }),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'upload', child: UiText('Upload saved files')),
          ],
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(21),
        children: [
          if (model.drafts.isEmpty)
            EmptyState(
              'No local files',
              model.webExperience
                  ? 'Files selected for import appear here.'
                  : 'Recordings and imports are automatically kept on this phone.',
            ),
          for (final d in model.drafts)
            CoreTile({
              ...d,
              'type': d['kind'] == 'file' ? 'file' : 'recording',
            }, () => push(context, PersonalLocalPage(model, text(d['id'])))),
        ],
      ),
    ),
  );
}

class PersonalLocalPage extends StatelessWidget {
  const PersonalLocalPage(this.model, this.id, {super.key});
  final TenoModel model;
  final String id;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) {
      final draft = model.drafts.where((d) => d['id'] == id).firstOrNull;
      if (draft == null)
        return const CoreFrame(
          title: 'Local file',
          child: EmptyState(
            'File unavailable',
            'Sign in to its account or check local storage.',
          ),
        );
      final file = draft['kind'] == 'file',
          remote = text(draft[file ? 'file_id' : 'recording_id']);
      return CoreFrame(
        title: model.webExperience ? 'Browser imports' : 'On this phone',
        child: ListView(
          padding: const EdgeInsets.all(21),
          children: [
            Text(
              text(draft['title']),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              model.webExperience && draft['status'] == 'local'
                  ? 'Saved in this browser'
                  : recordingStatus(draft['status']),
              style: TextStyle(color: subtle(context)),
            ),
            if (model.webExperience)
              Text('Account: ${model.runtime!.session.username}'),
            if (model.webExperience && draft['status'] == 'uploading') ...[
              const LinearProgressIndicator(minHeight: 2),
              const UiText(
                'Uploading. Keep this tab open until upload finishes.',
              ),
              TextButton(
                onPressed: () => perform(
                  context,
                  () => model.command('cancelUpload', {'id': id}).then((_) {}),
                ),
                child: const UiText('Stop upload'),
              ),
            ],
            if (!file) AudioPlayerBar(model, id, local: true),
            if (text(draft['error']).isNotEmpty)
              ErrorNotice(text(draft['error'])),
            if (text(draft['processing_message']).isNotEmpty)
              Text(text(draft['processing_message'])),
            if (remote.isNotEmpty)
              FilledButton(
                onPressed: () => push(
                  context,
                  file
                      ? PersonalFilePage(model, remote)
                      : PersonalRecordingPage(model, remote),
                ),
                child: const UiText('Open file'),
              )
            else
              FilledButton(
                onPressed:
                    [
                      'recording',
                      'invalid',
                      'queued',
                      'uploading',
                    ].contains(draft['status'])
                    ? null
                    : () => perform(context, () => model.host.retryUpload(id)),
                child: UiText(
                  draft['status'] == 'queued'
                      ? 'Waiting to upload'
                      : 'Upload and process',
                ),
              ),
            const SizedBox(height: 14),
            UiText(
              model.webExperience
                  ? 'Keep your original file. Browser storage may be cleared or evicted.'
                  : 'A complete copy stays on this phone after upload.',
            ),
            TextButton.icon(
              onPressed: () => perform(
                context,
                () => model.command('local_export', {'id': id}).then((_) {}),
              ),
              icon: const Icon(Icons.ios_share, size: 18),
              label: const UiText('Export original'),
            ),
            TextButton(
              onPressed: () => perform(context, () async {
                if (await confirm(
                  context,
                  'Delete local copy?',
                  remote.isEmpty
                      ? 'This file has not been uploaded. Its local copy will be permanently deleted.'
                      : 'The cloud content will stay in your library.',
                )) {
                  await model.host.deleteLocal(id);
                  if (context.mounted) Navigator.pop(context);
                }
              }),
              child: const UiText('Delete local copy'),
            ),
          ],
        ),
      );
    },
  );
}
