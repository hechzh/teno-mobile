import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/model.dart';
import '../platform/runtime.g.dart';
import '../ui/widgets.dart';
import 'ask.dart';
import 'settings.dart';

class AudioPlayerBar extends StatelessWidget {
  const AudioPlayerBar(this.model, this.id, {super.key, this.local = false});
  final TenoModel model;
  final String id;
  final bool local;
  Future<void> act(
    BuildContext context,
    PlaybackAction action, {
    int position = 0,
    double speed = 1,
  }) => perform(
    context,
    () => model.host.playback(action, id, local, position, speed),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) {
      final p = model.runtime!.playback;
      final selected = p.mediaId == id;
      final ready = selected && p.ready;
      return Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F1F1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAction(
                  ready && p.playing ? Icons.pause : Icons.play_arrow,
                  'Play or pause audio',
                  () => act(
                    context,
                    ready && p.playing
                        ? PlaybackAction.pause
                        : PlaybackAction.play,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Audio & transcript',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                PopupMenuButton<double>(
                  tooltip: 'Playback speed',
                  initialValue: p.speed,
                  onSelected: (v) =>
                      act(context, PlaybackAction.speed, speed: v),
                  itemBuilder: (_) => [
                    for (final v in [0.75, 1.0, 1.25, 1.5, 2.0])
                      PopupMenuItem(value: v, child: Text(v.toString() + '×')),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(p.speed.toString() + '×'),
                  ),
                ),
              ],
            ),
            Slider(
              value: ready ? p.positionMs.clamp(0, p.durationMs).toDouble() : 0,
              max: ready && p.durationMs > 0 ? p.durationMs.toDouble() : 1,
              onChanged: ready
                  ? (v) =>
                        act(context, PlaybackAction.seek, position: v.round())
                  : null,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  duration(ready ? p.positionMs : 0),
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
                Text(
                  duration(ready ? p.durationMs : 0),
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
            if (selected && p.error.isNotEmpty) ErrorNotice(p.error),
          ],
        ),
      );
    },
  );
}

class LocalPage extends StatelessWidget {
  const LocalPage(this.model, this.id, {super.key});
  final TenoModel model;
  final String id;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) {
      final matches = model.drafts.where((d) => d['id'] == id);
      if (matches.isEmpty)
        return const PageFrame(
          title: 'Local recording',
          child: EmptyState(
            'Recording unavailable',
            'Sign in to the recording’s account to access its local file.',
          ),
        );
      final d = matches.first;
      final record = text(d['recording_id']);
      return PageFrame(
        title: 'On this phone',
        child: ListView(
          padding: const EdgeInsets.all(23),
          children: [
            Text(
              text(d['title']),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              dateLabel(d['created_at']) + ' · ' + duration(d['duration_ms']),
              style: const TextStyle(color: muted),
            ),
            AudioPlayerBar(model, id, local: true),
            Text(
              recordingStatus(d['status']),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'The complete audio file stays on this phone.',
              style: TextStyle(color: muted),
            ),
            if (text(d['error']).isNotEmpty) ErrorNotice(text(d['error'])),
            if (text(d['note_error']).isNotEmpty)
              ErrorNotice(text(d['note_error'])),
            const SizedBox(height: 22),
            if (record.isNotEmpty)
              FilledButton(
                onPressed: () => push(context, DetailPage(model, record)),
                child: const Text('Open recording'),
              )
            else
              FilledButton(
                onPressed:
                    [
                      'recording',
                      'invalid',
                      'uploading',
                      'queued',
                    ].contains(text(d['status']))
                    ? null
                    : () => perform(context, () => model.host.retryUpload(id)),
                child: Text(
                  d['upload_requested'] == true
                      ? 'Queued for upload'
                      : 'Upload and process',
                ),
              ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recording notes',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit local notes',
                  onPressed: () => perform(context, () async {
                    final value = await inputDialog(
                      context,
                      'Local recording notes',
                      initial: text(d['notes']),
                      multiline: true,
                    );
                    if (value != null) await model.host.saveNotes(id, value);
                  }),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            SelectableText(
              text(d['notes']).isEmpty ? 'No notes added.' : text(d['notes']),
            ),
            if (record.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Edits here update the local note. Notes sent with the original upload remain on the server.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
            const SizedBox(height: 30),
            TextButton(
              onPressed: () => perform(context, () async {
                if (!await confirm(
                  context,
                  'Delete local copy?',
                  record.isEmpty
                      ? 'This recording has not been uploaded. Its local audio will be permanently deleted.'
                      : 'The cloud recording will stay in your library.',
                ))
                  return;
                await model.host.deleteLocal(id);
                if (context.mounted) Navigator.pop(context);
              }),
              child: const Text(
                'Delete local copy',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class DetailPage extends StatefulWidget {
  const DetailPage(this.model, this.id, {super.key, this.seekMs});
  final TenoModel model;
  final String id;
  final int? seekMs;
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  Json record = {}, transcript = {};
  List<Json> summaries = [];
  bool loading = false, transcribing = false;
  String error = '', jobId = '';
  int selected = 0, refreshCount = 0;
  Timer? timer;
  String get route => '/api/v1/recordings/' + widget.id;
  @override
  void initState() {
    super.initState();
    transcribing = widget.seekMs != null;
    unawaited(load());
    if (widget.seekMs != null) {
      unawaited(
        widget.model.host
            .playback(PlaybackAction.play, widget.id, false, widget.seekMs!, 1)
            .catchError((Object e) {
              if (mounted) setState(() => error = TenoModel.friendly(e));
            }),
      );
    }
  }

  Future<void> load() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final data = await Future.wait([
        widget.model.api('GET', route),
        widget.model.api('GET', route + '/transcriptions'),
        widget.model.list(route + '/summaries'),
      ]);
      if (!mounted) return;
      setState(() {
        record = object(data[0]);
        transcript = object(data[1]);
        summaries = rows(data[2]);
        selected = selected.clamp(
          0,
          summaries.isEmpty ? 0 : summaries.length - 1,
        );
      });
      if (jobId.isNotEmpty) {
        final job = await widget.model.api('GET', '/api/v1/jobs/' + jobId);
        if (job['status'] == 'failed') {
          throw StateError(
            text(object(job['error'])['message']).isEmpty
                ? 'Processing failed. Try again.'
                : text(object(job['error'])['message']),
          );
        }
        if (['done', 'succeeded', 'completed'].contains(job['status']))
          jobId = '';
      }
      if ((jobId.isNotEmpty ||
              summaries.isEmpty &&
                  !['failed', 'error'].contains(record['status'])) &&
          refreshCount++ < 24) {
        timer?.cancel();
        timer = Timer(const Duration(seconds: 5), () => unawaited(load()));
      }
    } catch (e) {
      if (mounted) setState(() => error = TenoModel.friendly(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> generate({bool transcriptOnly = false}) async => perform(
    context,
    () async {
      String? template;
      if (!transcriptOnly) {
        template = await push<String>(context, TemplatePicker(widget.model));
        if (template == null) return;
      }
      final result = await widget.model.api(
        'POST',
        route + (transcriptOnly ? '/transcriptions' : '/summaries'),
        {
          'client_id': requestId(),
          if (template != null && template.isNotEmpty) 'template_id': template,
        },
      );
      jobId = text(result['id']);
      refreshCount = 0;
      selected = 0;
      await load();
    },
  );
  Future<void> editSegment(Json segment) async => perform(context, () async {
    final value = await inputDialog(
      context,
      'Edit transcript',
      initial: text(segment['text']),
      multiline: true,
    );
    if (value == null) return;
    await widget.model.api('PATCH', route + '/transcriptions', {
      'revision': transcript['revision'],
      'segments': [
        {'id': segment['id'], 'text': value},
      ],
    });
    await load();
  });
  Future<void> menu() => showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MenuRow(Icons.edit_outlined, 'Rename', () {
              Navigator.pop(sheet);
              unawaited(
                perform(context, () async {
                  final value = await inputDialog(
                    context,
                    'Recording title',
                    initial: text(record['title']),
                  );
                  if (value == null || value.isEmpty) return;
                  await widget.model.api('PATCH', route, {'title': value});
                  await load();
                  await widget.model.refresh();
                }),
              );
            }),
            MenuRow(Icons.drive_file_move_outline, 'Move to folder', () {
              Navigator.pop(sheet);
              unawaited(move());
            }),
            MenuRow(Icons.auto_awesome_outlined, 'Generate summary', () {
              Navigator.pop(sheet);
              unawaited(generate());
            }),
            MenuRow(Icons.record_voice_over_outlined, 'Transcribe again', () {
              Navigator.pop(sheet);
              unawaited(
                perform(context, () async {
                  if (await confirm(
                    context,
                    'Transcribe again?',
                    'A new transcript version will be generated from the complete audio.',
                  ))
                    await generate(transcriptOnly: true);
                }),
              );
            }),
            MenuRow(Icons.ios_share, 'Export & share', () {
              Navigator.pop(sheet);
              unawaited(push(context, ExportPage(widget.model, widget.id)));
            }),
            MenuRow(Icons.delete_outline, 'Move to trash', () {
              Navigator.pop(sheet);
              unawaited(
                perform(context, () async {
                  if (!await confirm(
                    context,
                    'Move to trash?',
                    'You can restore this cloud recording from Trash.',
                  ))
                    return;
                  await widget.model.api('DELETE', route);
                  await widget.model.refresh();
                  if (mounted) Navigator.pop(context);
                }),
              );
            }),
          ],
        ),
      ),
    ),
  );
  Future<void> move() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: const Text('Move to folder'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialog, ''),
            child: const Text('All recordings'),
          ),
          for (final f in widget.model.folders)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialog, text(f['id'])),
              child: Text(text(object(f['data'])['title'])),
            ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    await perform(context, () async {
      await widget.model.api('PATCH', route, {
        'folder_id': choice.isEmpty ? null : choice,
      });
      await load();
    });
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Recording',
    actions: [CircleAction(Icons.more_horiz, 'Recording options', menu)],
    bottom: OutlinedButton.icon(
      onPressed: () =>
          push(context, ChatPage(widget.model, recordingIds: [widget.id])),
      icon: const Icon(Icons.auto_awesome_outlined, size: 18),
      label: const Text('Ask about this recording'),
    ),
    child: RefreshIndicator(
      onRefresh: load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(23),
        children: [
          if (loading) const LinearProgressIndicator(minHeight: 2),
          if (error.isNotEmpty) ErrorNotice(error, retry: load),
          Text(
            text(record['title']),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            dateLabel(record['created_at']) +
                ' · ' +
                duration(record['duration_ms']),
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          AudioPlayerBar(widget.model, widget.id),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => transcribing = false),
                child: Text(
                  'Summary',
                  style: TextStyle(
                    color: transcribing ? muted : ink,
                    fontWeight: transcribing
                        ? FontWeight.normal
                        : FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => transcribing = true),
                child: Text(
                  'Transcript',
                  style: TextStyle(
                    color: transcribing ? ink : muted,
                    fontWeight: transcribing
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
              const Spacer(),
              if (!transcribing && summaries.isNotEmpty)
                PopupMenuButton<int>(
                  tooltip: 'Summary versions',
                  onSelected: (v) => setState(() => selected = v),
                  itemBuilder: (_) => [
                    for (var i = 0; i < summaries.length; i++)
                      PopupMenuItem(
                        value: i,
                        child: Text(
                          (i == 0 ? 'Latest · ' : '') +
                              dateLabel(summaries[i]['created_at']),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          const Divider(),
          if (transcribing) ...[
            if (rows(transcript['segments']).isEmpty)
              EmptyState(
                record['status'] == 'transcribed'
                    ? 'No speech recognized'
                    : 'Transcript is being prepared',
                record['status'] == 'transcribed'
                    ? 'The complete audio remains available to play.'
                    : 'You can leave this page while processing continues.',
                action: TextButton(
                  onPressed: () => generate(transcriptOnly: true),
                  child: const Text('Transcribe again'),
                ),
              ),
            for (final s in rows(transcript['segments']))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          text(s['speaker']).isEmpty
                              ? 'Speaker'
                              : text(s['speaker']),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        TextButton(
                          onPressed: () => perform(
                            context,
                            () => widget.model.host.playback(
                              PlaybackAction.play,
                              widget.id,
                              false,
                              (s['start_ms'] as num? ?? 0).toInt(),
                              1,
                            ),
                          ),
                          child: Text(
                            duration(s['start_ms']),
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Edit segment',
                          onPressed: () => editSegment(s),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        ),
                      ],
                    ),
                    SelectableText(
                      text(s['text']),
                      style: const TextStyle(height: 1.8),
                    ),
                  ],
                ),
              ),
          ] else if (summaries.isEmpty)
            EmptyState(
              rows(transcript['segments']).isEmpty
                  ? 'Processing your recording'
                  : 'Ready to summarize',
              'Audio is kept while Teno prepares your notes.',
              action: FilledButton(
                onPressed: rows(transcript['segments']).isEmpty
                    ? null
                    : generate,
                child: const Text('Generate summary'),
              ),
            )
          else
            ...summaryWidgets(),
        ],
      ),
    ),
  );
  List<Widget> summaryWidgets() {
    final summary = summaries[selected], data = object(summary['data']);
    return [
      if (summary['stale'] == true)
        const ErrorNotice(
          'The transcript has changed since this summary was generated.',
        ),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F9),
          border: Border.all(color: const Color(0xFFDCE5E9)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MEETING NOTES',
              style: TextStyle(fontSize: 10, letterSpacing: 1, color: muted),
            ),
            const SizedBox(height: 10),
            Text(
              text(data['title']),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'Overview',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 10),
      SelectableText(
        text(data['summary']),
        style: const TextStyle(height: 1.7),
      ),
      if (data['key_points'] is List &&
          (data['key_points'] as List).isNotEmpty) ...[
        const SizedBox(height: 24),
        const Text(
          'Key points',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        for (final point in data['key_points'] as List)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '•  ' + text(point),
              style: const TextStyle(height: 1.7),
            ),
          ),
      ],
      if (rows(data['action_items']).isNotEmpty) ...[
        const SizedBox(height: 24),
        const Text(
          'Next steps',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        for (final action in rows(data['action_items']))
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '•  ' + text(action['title'] ?? action['text']),
              style: const TextStyle(height: 1.7),
            ),
          ),
      ],
      const SizedBox(height: 24),
      if (selected == 0)
        OutlinedButton.icon(
          onPressed: () async {
            await push(
              context,
              SummaryEditor(
                widget.model,
                widget.id,
                summary,
                (transcript['revision'] as num? ?? 0).toInt(),
              ),
            );
            await load();
          },
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit summary'),
        ),
    ];
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
}

class SummaryEditor extends StatefulWidget {
  const SummaryEditor(
    this.model,
    this.recordingId,
    this.summary,
    this.revision, {
    super.key,
  });
  final TenoModel model;
  final String recordingId;
  final Json summary;
  final int revision;
  @override
  State<SummaryEditor> createState() => _SummaryEditorState();
}

class _SummaryEditorState extends State<SummaryEditor> {
  late final data = object(widget.summary['data']);
  late final title = TextEditingController(text: text(data['title']));
  late final summary = TextEditingController(text: text(data['summary']));
  late final points = TextEditingController(
    text: data['key_points'] is List
        ? (data['key_points'] as List).join('\n')
        : '',
  );
  String clientId = requestId(), fingerprint = '', error = '';
  bool busy = false;
  Future<void> save() async {
    final body = <String, dynamic>{
      'base_id': widget.summary['id'],
      'revision': widget.revision,
      'title': title.text.trim(),
      'summary': summary.text.trim(),
      'key_points': points.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      'action_items': data['action_items'] ?? [],
    };
    final next = jsonEncode(body);
    if (fingerprint != next) {
      fingerprint = next;
      clientId = requestId();
    }
    body['client_id'] = clientId;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await widget.model.api(
        'POST',
        '/api/v1/recordings/' + widget.recordingId + '/summary-edits',
        body,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = TenoModel.friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Edit summary',
    bottom: FilledButton(
      onPressed: busy ? null : save,
      child: Text(busy ? 'Saving…' : 'Save new version'),
    ),
    child: ListView(
      padding: const EdgeInsets.all(23),
      children: [
        if (error.isNotEmpty) ErrorNotice(error),
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: summary,
          minLines: 6,
          maxLines: null,
          decoration: const InputDecoration(labelText: 'Summary'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: points,
          minLines: 4,
          maxLines: null,
          decoration: const InputDecoration(
            labelText: 'Key points · One per line',
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Previous versions and existing next steps are preserved.',
          style: TextStyle(color: muted),
        ),
      ],
    ),
  );
  @override
  void dispose() {
    title.dispose();
    summary.dispose();
    points.dispose();
    super.dispose();
  }
}

class ExportPage extends StatelessWidget {
  const ExportPage(this.model, this.id, {super.key});
  final TenoModel model;
  final String id;
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Export & share',
    child: ListView(
      padding: const EdgeInsets.all(23),
      children: [
        const Text(
          'Choose a format',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        const Text(
          'Save or share through your phone’s share menu.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 24),
        for (final option in [
          ('Audio', 'audio'),
          ('Markdown', 'md'),
          ('Plain text', 'txt'),
          ('JSON', 'json'),
        ])
          MenuRow(
            Icons.description_outlined,
            option.$1,
            () => perform(context, () => model.host.shareExport(id, option.$2)),
          ),
      ],
    ),
  );
}
