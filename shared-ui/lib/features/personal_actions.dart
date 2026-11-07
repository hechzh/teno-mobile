import 'dart:async';
import 'package:flutter/material.dart';
import '../core/model.dart';
import '../ui/widgets.dart';
import '../ui/personal_widgets.dart';
import 'personal_library.dart';
import 'personal_notes.dart';
import 'personal_recording.dart';

Future<void> openPersonalItem(
  BuildContext context,
  TenoModel model,
  Json item, [
  Json? match,
]) async {
  await push(context, switch (text(item['type'])) {
    'folder' => PersonalListPage(
      model,
      title: text(item['title']),
      folderId: text(item['id']),
    ),
    'note' => PersonalNotePage(model, text(item['id'])),
    'file' => PersonalFilePage(
      model,
      text(item['id']),
      page: (match?['page'] as num?)?.toInt(),
    ),
    _ => PersonalRecordingPage(
      model,
      text(item['id']),
      seekMs: (match?['start_ms'] as num?)?.toInt(),
    ),
  });
}

Future<String?> choosePersonalFolder(
  BuildContext context,
  TenoModel model,
) async {
  final folders = await model.list('/api/v1/folders?limit=200');
  if (!context.mounted) return null;
  return showModalBottomSheet<String>(
    context: context,
    builder: (sheet) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(20),
        children: [
          heading('Move to folder'),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('My files'),
            onTap: () => Navigator.pop(sheet, ''),
          ),
          for (final folder in folders)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(text(object(folder['data'])['title'])),
              onTap: () => Navigator.pop(sheet, text(folder['id'])),
            ),
        ],
      ),
    ),
  );
}

Future<void> personalExport(
  BuildContext context,
  TenoModel model,
  Json item, {
  String? noteId,
}) => push(context, PersonalExportPage(model, item, noteId: noteId));

class PersonalExportPage extends StatefulWidget {
  const PersonalExportPage(this.model, this.item, {super.key, this.noteId});
  final TenoModel model;
  final Json item;
  final String? noteId;
  @override
  State<PersonalExportPage> createState() => _PersonalExportPageState();
}

class _PersonalExportPageState extends State<PersonalExportPage> {
  late String content = widget.item['type'] == 'recording'
      ? 'transcript'
      : 'note';
  String format = 'txt';
  bool timestamps = true, speakers = true, highlights = false, cover = true;
  @override
  Widget build(BuildContext context) {
    final formats = content == 'audio'
        ? ['mp3', 'wav']
        : content == 'transcript'
        ? ['txt', 'md', 'srt', 'docx', 'pdf', 'json']
        : ['txt', 'md', 'docx', 'pdf', 'json'];
    return CoreFrame(
      title: 'Export as',
      bottom: FilledButton(
        onPressed: () => perform(context, () async {
          final path =
              '/api/v1/personal/exports/${widget.item['type']}/${widget.item['id']}?content=$content&format=$format&timestamps=$timestamps&speakers=$speakers&highlights=$highlights&cover=$cover' +
              (widget.noteId == null ? '' : '&note_id=${widget.noteId}');
          await widget.model.command('export', {
            'path': path,
            'format': format,
          });
        }),
        child: const Text('Export'),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          heading('Content'),
          if (widget.item['type'] == 'recording')
            RadioGroup<String>(
              groupValue: content,
              onChanged: (v) => setState(() {
                content = v!;
                format = v == 'audio' ? 'mp3' : 'txt';
              }),
              child: Column(
                children: [
                  for (final value in ['audio', 'transcript', 'note'])
                    RadioListTile<String>(
                      value: value,
                      title: Text(
                        {
                          'audio': 'Audio',
                          'transcript': 'Transcript',
                          'note': 'Summary',
                        }[value]!,
                      ),
                    ),
                ],
              ),
            )
          else
            Text(text(widget.item['title'])),
          heading('Format'),
          Wrap(
            spacing: 8,
            children: [
              for (final value in formats)
                ChoiceChip(
                  label: Text(value.toUpperCase()),
                  selected: value == format,
                  onSelected: (_) => setState(() => format = value),
                ),
            ],
          ),
          if (format == 'json')
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('JSON includes the complete structured content and source references.')),
          if (content == 'transcript' && format != 'json') ...[
            SwitchListTile(
              title: const Text('Timestamps'),
              value: format == 'srt' || timestamps,
              onChanged: format == 'srt' ? null : (v) => setState(() => timestamps = v),
            ),
            SwitchListTile(
              title: const Text('Speaker labels'),
              value: speakers,
              onChanged: (v) => setState(() => speakers = v),
            ),
            if (format != 'srt') SwitchListTile(
              title: const Text('Highlights'),
              value: highlights,
              onChanged: (v) => setState(() => highlights = v),
            ),
          ],
          if (content == 'note' && format != 'json')
            SwitchListTile(
              title: const Text('Cover'),
              value: cover,
              onChanged: (v) => setState(() => cover = v),
            ),
        ],
      ),
    );
  }
}

class PersonalSharePage extends StatefulWidget {
  const PersonalSharePage(this.model, this.item, {super.key, this.noteId});
  final TenoModel model;
  final Json item;
  final String? noteId;
  @override
  State<PersonalSharePage> createState() => _PersonalSharePageState();
}

class _PersonalSharePageState extends State<PersonalSharePage> {
  bool summary = true, transcript = false, audio = false, busy = false;
  int days = 7;
  String url = '';
  @override
  Widget build(BuildContext context) => CoreFrame(
    title: 'Share',
    bottom: FilledButton(
      onPressed: busy
          ? null
          : () => perform(context, () async {
              if (url.isNotEmpty) {
                await widget.model.host.shareText(url);
                return;
              }
              setState(() => busy = true);
              try {
                final value = await widget.model.api('POST', '/api/v1/shares', {
                  'source': {
                    'type': widget.item['type'],
                    'id': widget.item['id'],
                  },
                  if (widget.noteId != null) 'note_id': widget.noteId,
                  'include_summary': summary,
                  'include_transcript': transcript,
                  'include_audio': audio,
                  'days': days,
                });
                if (mounted) setState(() => url = text(value['url']));
              } finally {
                if (mounted) setState(() => busy = false);
              }
            }),
      child: Text(
        busy
            ? 'Creating link…'
            : url.isEmpty
            ? 'Create link'
            : 'Share link',
      ),
    ),
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        heading('Anyone with the link can view'),
        const Text(
          'The link shares a fixed version. You can revoke it in Settings.',
        ),
        SwitchListTile(
          title: const Text('Summary'),
          value: summary,
          onChanged: url.isEmpty ? (v) => setState(() => summary = v) : null,
        ),
        if (widget.item['type'] == 'recording') ...[
          SwitchListTile(
            title: const Text('Transcript'),
            value: transcript,
            onChanged: url.isEmpty
                ? (v) => setState(() => transcript = v)
                : null,
          ),
          SwitchListTile(
            title: const Text('Audio'),
            value: audio,
            onChanged: url.isEmpty ? (v) => setState(() => audio = v) : null,
          ),
        ],
        DropdownButtonFormField<int>(
          initialValue: days,
          decoration: const InputDecoration(labelText: 'Link expires after'),
          items: [
            for (final d in [1, 7, 30])
              DropdownMenuItem(value: d, child: Text('$d days')),
          ],
          onChanged: url.isEmpty ? (v) => setState(() => days = v!) : null,
        ),
        if (url.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: SelectableText(url),
          ),
      ],
    ),
  );
}

class PersonalJobPage extends StatefulWidget {
  const PersonalJobPage(this.model, this.job, {super.key});
  final TenoModel model;
  final Json job;
  @override
  State<PersonalJobPage> createState() => _PersonalJobPageState();
}

class _PersonalJobPageState extends State<PersonalJobPage> {
  late Json job = widget.job;
  Timer? timer;
  String error = '';
  @override
  void initState() {
    super.initState();
    unawaited(poll());
  }

  Future<void> poll() async {
    try {
      final value = await widget.model.api('GET', '/api/v1/jobs/${job['id']}');
      if (!mounted) return;
      setState(() {
        job = value;
        error = '';
      });
      if (!['completed', 'failed'].contains(job['status']))
        timer = Timer(const Duration(seconds: 4), poll);
    } catch (e) {
      if (mounted) setState(() => error = TenoModel.friendly(e));
    }
  }

  @override
  Widget build(BuildContext context) => CoreFrame(
    title: 'Processing',
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (error.isNotEmpty) ErrorNotice(error, retry: poll),
        if (!['completed', 'failed'].contains(job['status'])) ...[
          const LinearProgressIndicator(minHeight: 2),
          heading('Preparing your note'),
          const Text(
            'You can leave this page. Processing continues in the background.',
          ),
        ],
        if (job['status'] == 'failed') ...[
          ErrorNotice(text(object(job['error'])['message'])),
          TextButton(
            onPressed: () => perform(context, () async {
              job = await widget.model.api(
                'POST',
                '/api/v1/jobs/${job['id']}/retry',
              );
              await poll();
            }),
            child: const Text('Retry'),
          ),
        ],
        if (job['status'] == 'completed') ...[
          heading('Ready'),
          FilledButton(
            onPressed: () async {
              final result = object(job['result']);
              if (result['note_id'] != null) {
                await push(
                  context,
                  PersonalNotePage(widget.model, text(result['note_id'])),
                );
              } else if (result['recording_id'] != null) {
                await push(
                  context,
                  PersonalRecordingPage(
                    widget.model,
                    text(result['recording_id']),
                  ),
                );
              }
            },
            child: const Text('Open result'),
          ),
        ],
      ],
    ),
  );
  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
}
