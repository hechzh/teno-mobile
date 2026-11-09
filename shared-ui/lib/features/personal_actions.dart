import '../l10n/ui_strings.dart';
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
            title: const UiText('My files'),
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
}) async {
  String content = 'note';
  if (item['type'] == 'recording') {
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.sizeOf(context).width - 240,
        88,
        16,
        0,
      ),
      items: [
        for (final v in [
          ('audio', 'Audio'),
          ('transcript', 'Transcript'),
          ('note', 'Summary'),
        ])
          PopupMenuItem(
            value: v.$1,
            child: Row(
              children: [
                Expanded(child: UiText(v.$2)),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
      ],
    );
    if (value == null || !context.mounted) return;
    content = value;
  }
  await showCoreSheet<void>(
    context,
    PersonalExportPage(
      model,
      item,
      noteId: noteId,
      initialContent: content,
      sheet: true,
    ),
    height: 560,
  );
}

Future<void> personalShare(
  BuildContext context,
  TenoModel model,
  Json item, {
  String? noteId,
}) async {
  await showCoreSheet<void>(
    context,
    PersonalSharePage(model, item, noteId: noteId, sheet: true),
    height: MediaQuery.sizeOf(context).height - 64,
    edgeToEdge: true,
  );
}

class PersonalExportPage extends StatefulWidget {
  const PersonalExportPage(
    this.model,
    this.item, {
    super.key,
    this.noteId,
    this.initialContent,
    this.sheet = false,
  });
  final TenoModel model;
  final Json item;
  final String? noteId, initialContent;
  final bool sheet;
  @override
  State<PersonalExportPage> createState() => _PersonalExportPageState();
}

class _PersonalExportPageState extends State<PersonalExportPage> {
  late String content =
      widget.initialContent ??
      (widget.item['type'] == 'recording' ? 'transcript' : 'note');
  late String format = content == 'audio' ? 'mp3' : 'docx';
  bool timestamps = true, speakers = true, highlights = false, cover = true;
  @override
  Widget build(BuildContext context) {
    final formats = content == 'audio'
        ? ['mp3', 'wav']
        : content == 'transcript'
        ? ['docx', 'pdf', 'md', 'txt', 'srt', 'json']
        : ['docx', 'pdf', 'md', 'txt', 'json'];
    return CoreFrame(
      title: 'Export as',
      sheet: widget.sheet,
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
        child: const UiText('Export'),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.initialContent != null)
            UiText(
              {
                'audio': 'Audio',
                'transcript': 'Transcript',
                'note': 'Summary',
              }[content]!,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          if (widget.initialContent == null) heading('Content'),
          if (widget.item['type'] == 'recording' &&
              widget.initialContent == null)
            RadioGroup<String>(
              groupValue: content,
              onChanged: (v) => setState(() {
                content = v!;
                format = v == 'audio' ? 'mp3' : 'docx';
              }),
              child: Column(
                children: [
                  for (final value in ['audio', 'transcript', 'note'])
                    RadioListTile<String>(
                      value: value,
                      title: UiText(
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
          else if (widget.initialContent == null)
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: UiText(
                'JSON includes the complete structured content and source references.',
              ),
            ),
          if (content == 'transcript' && format != 'json') ...[
            SwitchListTile(
              title: const UiText('Timestamps'),
              value: format == 'srt' || timestamps,
              onChanged: format == 'srt'
                  ? null
                  : (v) => setState(() => timestamps = v),
            ),
            SwitchListTile(
              title: const UiText('Speaker labels'),
              value: speakers,
              onChanged: (v) => setState(() => speakers = v),
            ),
            if (format != 'srt')
              SwitchListTile(
                title: const UiText('Highlights'),
                value: highlights,
                onChanged: (v) => setState(() => highlights = v),
              ),
          ],
          if (content == 'note' && format != 'json')
            SwitchListTile(
              title: const UiText('Cover'),
              value: cover,
              onChanged: (v) => setState(() => cover = v),
            ),
        ],
      ),
    );
  }
}

class PersonalSharePage extends StatefulWidget {
  const PersonalSharePage(
    this.model,
    this.item, {
    super.key,
    this.noteId,
    this.sheet = false,
  });
  final TenoModel model;
  final Json item;
  final String? noteId;
  final bool sheet;
  @override
  State<PersonalSharePage> createState() => _PersonalSharePageState();
}

class _PersonalSharePageState extends State<PersonalSharePage> {
  bool summary = true, transcript = false, audio = false, busy = false;
  int days = 7;
  String url = '', error = '';
  late Json preview = widget.item;
  @override
  void initState() {
    super.initState();
    unawaited(loadPreview());
  }

  Future<void> loadPreview() async {
    try {
      final type = widget.item['type'];
      final value = await widget.model.api(
        'GET',
        '/api/v1/${type == 'recording'
            ? 'recordings'
            : type == 'note'
            ? 'notes'
            : 'files'}/${widget.item['id']}',
      );
      if (mounted) setState(() => preview = {...widget.item, ...value});
    } catch (e) {
      if (mounted) setState(() => error = TenoModel.friendly(e));
    }
  }

  Future<void> chooseContent() async {
    var draftSummary = summary,
        draftTranscript = transcript,
        draftAudio = audio;
    final result = await showCoreSheet<Json>(
      context,
      StatefulBuilder(
        builder: (sheet, change) => CoreFrame(
          title: 'Choose content',
          sheet: true,
          bottom: FilledButton(
            onPressed: !draftSummary && !draftTranscript && !draftAudio
                ? null
                : () => Navigator.pop(sheet, {
                    'summary': draftSummary,
                    'transcript': draftTranscript,
                    'audio': draftAudio,
                  }),
            child: const UiText('Done'),
          ),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              CheckboxListTile(
                controlAffinity: ListTileControlAffinity.trailing,
                title: UiText(
                  widget.item['type'] == 'recording' ? 'Summary' : 'Content',
                ),
                value: draftSummary,
                onChanged: (v) => change(() => draftSummary = v!),
              ),
              if (widget.item['type'] == 'recording') ...[
                CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.trailing,
                  title: const UiText('Transcript'),
                  value: draftTranscript,
                  onChanged: (v) => change(() => draftTranscript = v!),
                ),
                CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.trailing,
                  title: const UiText('Audio'),
                  value: draftAudio,
                  onChanged: (v) => change(() => draftAudio = v!),
                ),
              ],
            ],
          ),
        ),
      ),
      height: 410,
    );
    if (result != null && mounted)
      setState(() {
        summary = result['summary'] == true;
        transcript = result['transcript'] == true;
        audio = result['audio'] == true;
      });
  }

  Future<void> share() => perform(context, () async {
    if (url.isNotEmpty) {
      await widget.model.host.shareText(url);
      return;
    }
    setState(() => busy = true);
    try {
      final value = await widget.model.api('POST', '/api/v1/shares', {
        'source': {'type': widget.item['type'], 'id': widget.item['id']},
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
  });

  @override
  Widget build(BuildContext context) {
    final contents = [
      if (summary) widget.item['type'] == 'recording' ? 'Summary' : 'Content',
      if (transcript) 'Transcript',
      if (audio) 'Audio',
    ];
    return CoreFrame(
      title: 'Share',
      sheet: widget.sheet,
      sheetDone: widget.sheet,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(coreInset, 8, coreInset, 24),
        children: [
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const UiText(
              'Share link',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 18),
          heading('Share with link'),
          UiText(
            'Create a shareable link. Anyone with the link can access this file.',
            style: TextStyle(fontSize: 16, height: 1.3, color: subtle(context)),
          ),
          const SizedBox(height: 24),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < 3; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.circle,
                            size: 8,
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minHeight: 190),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text(preview['title']).isEmpty
                            ? 'Untitled'
                            : text(preview['title']),
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (preview['created_at'] != null)
                            Chip(
                              avatar: const Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                              ),
                              label: Text(
                                coreDate(
                                  preview['created_at'],
                                  time: true,
                                  context: context,
                                ),
                              ),
                            ),
                          for (final name in contents)
                            Chip(label: UiText(name)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (error.isNotEmpty) ErrorNotice(error, retry: loadPreview),
          const SizedBox(height: 20),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const UiText(
              'Choose content to include',
              style: TextStyle(fontSize: 15),
            ),
            subtitle: MediaQuery.textScalerOf(context).scale(1) > 1.2
                ? Text(contents.map((v) => ui(context, v)).join('、'))
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (MediaQuery.textScalerOf(context).scale(1) <= 1.2)
                  Text(
                    context.strings.selectedCount(contents.length),
                    style: TextStyle(fontSize: 12, color: subtle(context)),
                  ),
                const Icon(Icons.chevron_right, size: 22),
              ],
            ),
            onTap: url.isEmpty ? chooseContent : null,
          ),
          PopupMenuButton<int>(
            enabled: url.isEmpty,
            onSelected: (v) => setState(() => days = v),
            itemBuilder: (_) => [
              for (final d in [1, 7, 30])
                PopupMenuItem(
                  value: d,
                  child: Text(context.strings.dayCount(d)),
                ),
            ],
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const UiText(
                'Link expires after',
                style: TextStyle(fontSize: 14),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.strings.dayCount(days),
                    style: TextStyle(fontSize: 13, color: subtle(context)),
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 18),
                ],
              ),
            ),
          ),
          UiText(
            'A fixed version is shared. Revoke links in Settings → Shared links.',
            style: TextStyle(fontSize: 12, color: subtle(context)),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy || contents.isEmpty ? null : share,
            child: UiText(
              busy
                  ? 'Creating link…'
                  : url.isEmpty
                  ? 'Create link'
                  : 'Share link',
            ),
          ),
          if (url.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SelectableText(url, style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
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
          const UiText(
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
            child: const UiText('Retry'),
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
            child: const UiText('Open result'),
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
