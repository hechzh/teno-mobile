import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/model.dart';
import '../platform/runtime.g.dart';
import '../ui/widgets.dart';
import '../ui/personal_widgets.dart';
import 'personal_actions.dart';
import 'personal_notes.dart';
import 'personal_ask.dart';
import 'personal_settings.dart';
import 'personal_library.dart';

class PersonalRecordingPage extends StatefulWidget {
  const PersonalRecordingPage(
    this.model,
    this.id, {
    super.key,
    this.seekMs,
    this.transcriptOnly = false,
  });
  final TenoModel model;
  final String id;
  final int? seekMs;
  final bool transcriptOnly;
  @override
  State<PersonalRecordingPage> createState() => _PersonalRecordingPageState();
}

class _PersonalRecordingPageState extends State<PersonalRecordingPage> {
  Json record = {}, transcript = {}, metadata = {}, processing = {};
  List<Json> notes = [];
  List<double> peaks = [];
  String error = '', variant = 'edited';
  int noteIndex = 0, currentSegment = -1;
  bool loading = true, follow = true;
  Timer? timer;
  final segmentKeys = <String, GlobalKey>{};
  bool get audio => widget.transcriptOnly || widget.seekMs != null;
  String get path => '/api/v1/recordings/${widget.id}';
  @override
  void initState() {
    super.initState();
    widget.model.addListener(playbackChanged);
    unawaited(load());
    if (widget.seekMs != null)
      unawaited(
        widget.model.host.playback(
          PlaybackAction.play,
          widget.id,
          false,
          widget.seekMs!,
          1,
        ),
      );
  }

  Future<void> load() async {
    timer?.cancel();
    try {
      final values = await Future.wait([
        widget.model.api('GET', path),
        widget.model.api(
          'GET',
          '/api/v1/personal/recordings/${widget.id}/transcript?variant=$variant',
        ),
        widget.model.api('GET', '$path/notes'),
        widget.model.api('GET', '$path/metadata'),
        widget.model.api(
          'GET',
          '/api/v1/personal/recordings/${widget.id}/processing',
        ),
      ]);
      if (!mounted) return;
      setState(() {
        record = values[0];
        transcript = values[1];
        notes = rows(values[2]['items']);
        metadata = values[3];
        processing = values[4];
        noteIndex = notes.isEmpty ? 0 : noteIndex.clamp(0, notes.length - 1);
        loading = false;
        error = '';
      });
      if (peaks.isEmpty && (record['duration_ms'] as num? ?? 0) > 0) {
        final wave = await widget.model.api('GET', '$path/waveform');
        if (mounted)
          setState(
            () => peaks = (wave['peaks'] as List? ?? [])
                .map((v) => (v as num).toDouble())
                .toList(),
          );
      }
      if (processing['status'] == 'processing')
        timer = Timer(const Duration(seconds: 6), load);
    } catch (e) {
      if (mounted)
        setState(() {
          error = TenoModel.friendly(e);
          loading = false;
        });
    }
  }

  void playbackChanged() {
    if (!audio || !mounted) return;
    final p = widget.model.runtime!.playback;
    if (p.mediaId != widget.id) return;
    final values = rows(transcript['segments']);
    final index = values.indexWhere(
      (s) =>
          p.positionMs >= (s['start_ms'] as num) &&
          p.positionMs < (s['end_ms'] as num),
    );
    if (index == currentSegment) return;
    setState(() => currentSegment = index);
    if (follow && p.playing && index >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = segmentKeys[text(values[index]['id'])]?.currentContext;
        if (c != null && mounted)
          unawaited(
            Scrollable.ensureVisible(
              c,
              alignment: .3,
              duration: const Duration(milliseconds: 250),
            ),
          );
      });
    }
  }

  Future<void> generate() async {
    final template = await push<String>(
      context,
      PersonalTemplatePicker(widget.model),
    );
    if (template == null || !mounted) return;
    await perform(context, () async {
      final job = await widget.model.api('POST', '$path/notes', {
        'client_id': requestId(),
        if (template.isNotEmpty) 'template_id': template,
      });
      if (mounted) await push(context, PersonalJobPage(widget.model, job));
      await load();
    });
  }

  Future<void> speakers() async {
    final values = await widget.model.api('GET', '$path/speakers');
    if (!mounted) return;
    final controllers = {
      for (final s in rows(values['items']))
        text(s['label']): TextEditingController(text: text(s['name'])),
    };
    try {
      final save = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (sheet) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              21,
              10,
              21,
              MediaQuery.viewInsetsOf(sheet).bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading('Name speakers'),
                  if (controllers.isEmpty)
                    const Text(
                      'No speaker labels are available for this transcript.',
                    ),
                  for (final entry in controllers.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: entry.value,
                        decoration: InputDecoration(
                          labelText: 'Speaker ${entry.key}',
                        ),
                      ),
                    ),
                  FilledButton(
                    onPressed: () => Navigator.pop(sheet, true),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (save == true) {
        await widget.model.api('PATCH', '$path/speakers', {
          'revision': values['revision'],
          'names': {
            for (final entry in controllers.entries)
              if (entry.value.text.trim().isNotEmpty)
                entry.key: entry.value.text.trim(),
          },
        });
        await load();
      }
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      for (final c in controllers.values) c.dispose();
    }
  }

  Future<void> findReplace() async {
    final find = TextEditingController(), replace = TextEditingController();
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Find & replace'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: find,
                decoration: const InputDecoration(labelText: 'Find'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: replace,
                decoration: const InputDecoration(labelText: 'Replace with'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Replace all'),
            ),
          ],
        ),
      );
      if (accepted == true && find.text.isNotEmpty) {
        final current = await widget.model.api('GET', '$path/transcriptions');
        final edits = [
          for (final s in rows(current['segments']))
            if (text(s['text']).contains(find.text))
              {
                'id': s['id'],
                'text': text(s['text']).replaceAll(find.text, replace.text),
              },
        ];
        if (edits.isEmpty) throw StateError('No matches found.');
        await widget.model.api('PATCH', '$path/transcriptions', {
          'revision': current['revision'],
          'segments': edits,
        });
        variant = 'edited';
        await load();
      }
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      find.dispose();
      replace.dispose();
    }
  }

  Future<void> edit(Json segment) async {
    if (variant == 'original')
      throw StateError(
        'Switch to Edited text to make changes. The original stays unchanged.',
      );
    final value = await inputDialog(
      context,
      'Edit transcript',
      initial: text(segment['text']),
      multiline: true,
    );
    if (value == null) return;
    await widget.model.api('PATCH', '$path/transcriptions', {
      'revision': transcript['revision'],
      'segments': [
        {'id': segment['id'], 'text': value},
      ],
    });
    variant = 'edited';
    await load();
  }

  Future<void> menu(String action) => perform(context, () async {
    switch (action) {
      case 'speakers':
        await speakers();
        return;
      case 'rename':
        final title = await inputDialog(
          context,
          'Rename',
          initial: text(record['title']),
        );
        if (title != null) {
          await widget.model.api(
            'PATCH',
            '/api/v1/library/items/recording/${widget.id}',
            {'title': title},
          );
          await load();
        }
        return;
      case 'move':
        final folder = await choosePersonalFolder(context, widget.model);
        if (folder != null)
          await widget.model.api('POST', '/api/v1/library/batch', {
            'action': 'move',
            'folder_id': folder.isEmpty ? null : folder,
            'items': [
              {'type': 'recording', 'id': widget.id},
            ],
          });
        return;
      case 'generate':
        await generate();
        return;
      case 'transcribe':
        final job = await widget.model.api('POST', '$path/transcriptions', {
          'client_id': requestId(),
          'personal_mode': true,
        });
        if (!mounted) return;
        await push(context, PersonalJobPage(widget.model, job));
        await load();
        return;
      case 'replace':
        await findReplace();
        return;
      case 'copy':
        await Clipboard.setData(
          ClipboardData(
            text: audio
                ? rows(
                    transcript['segments'],
                  ).map((s) => text(s['text'])).join('\n')
                : notes.isEmpty
                ? ''
                : text(
                    object(notes[noteIndex]['data'])['body'] ??
                        object(notes[noteIndex]['data'])['summary'],
                  ),
          ),
        );
        return;
      case 'export':
        await personalExport(context, widget.model, {
          'type': 'recording',
          'id': widget.id,
        }, noteId: notes.isEmpty ? null : text(notes[noteIndex]['id']));
        return;
      case 'calendar':
        final event = await push<String>(
          context,
          PersonalCalendarPage(widget.model, select: true),
        );
        if (event != null) {
          await widget.model.api('PATCH', '$path/metadata', {
            'source': metadata['source'] ?? 'recording',
            'event_id': event,
            'marks': metadata['marks'] ?? [],
          });
          await load();
        }
        return;
      case 'trim':
        final value = await inputDialog(
          context,
          'Trim range · start,end in seconds',
          initial: '0,${((record['duration_ms'] as num? ?? 0) / 1000).floor()}',
        );
        if (value == null) return;
        final range = value
            .split(',')
            .map((v) => double.tryParse(v.trim()))
            .toList();
        if (range.length != 2 || range.any((v) => v == null))
          throw StateError('Enter start and end seconds separated by a comma.');
        final job = await widget.model.api(
          'POST',
          '/api/v1/recordings/audio-edit',
          {
            'action': 'trim',
            'recording_ids': [widget.id],
            'start_ms': (range[0]! * 1000).round(),
            'end_ms': (range[1]! * 1000).round(),
            'title': '${record['title']} · Trimmed',
            'client_id': requestId(),
          },
        );
        if (mounted) await push(context, PersonalJobPage(widget.model, job));
        return;
      case 'trash':
        if (await confirm(
          context,
          'Move to trash?',
          'You can restore this recording from Trash.',
        )) {
          await widget.model.api('DELETE', path);
          if (mounted) Navigator.pop(context);
        }
        return;
    }
  });
  @override
  Widget build(BuildContext context) => CoreFrame(
    title: audio ? 'Audio & transcript' : '',
    actions: [
      CircleAction(
        Icons.ios_share_outlined,
        'Share',
        () => push(
          context,
          PersonalSharePage(widget.model, {
            'type': 'recording',
            'id': widget.id,
          }, noteId: notes.isEmpty ? null : text(notes[noteIndex]['id'])),
        ),
      ),
      PopupMenuButton<String>(
        tooltip: 'Recording options',
        onSelected: menu,
        itemBuilder: (_) => [
          for (final entry in [
            ('speakers', 'Name speakers'),
            ('rename', 'Rename'),
            ('move', 'Move to folder'),
            ('calendar', 'Link calendar event'),
            ('generate', 'New summary note'),
            ('transcribe', 'Transcribe again'),
            ('replace', 'Find & replace'),
            ('trim', 'Trim audio'),
            ('copy', 'Copy to clipboard'),
            ('export', 'Export as'),
            ('trash', 'Move to trash'),
          ])
            PopupMenuItem(value: entry.$1, child: Text(entry.$2)),
        ],
      ),
    ],
    bottom: AskBar(
      () => push(
        context,
        PersonalChatPage(
          widget.model,
          initial: [
            {'type': 'recording', 'id': widget.id},
          ],
        ),
      ),
      label: 'Ask me anything about this recording',
    ),
    child: ListView(
      padding: const EdgeInsets.all(21),
      children: [
        if (loading) const LinearProgressIndicator(minHeight: 2),
        if (error.isNotEmpty) ErrorNotice(error, retry: load),
        if (processing['status'] == 'failed') ...[
          ErrorNotice(text(object(processing['error'])['message'])),
          if (text(processing['job_id']).isNotEmpty)
            TextButton(
              onPressed: () => perform(context, () async {
                await widget.model.api(
                  'POST',
                  '/api/v1/jobs/${processing['job_id']}/retry',
                );
                await load();
              }),
              child: const Text('Retry processing'),
            ),
        ],
        if (text(processing['message']).isNotEmpty)
          Text(text(processing['message'])),
        if (!audio) ...[
          Text(
            text(record['title']),
            style: const TextStyle(
              fontSize: 24,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              ActionChip(
                avatar: const Icon(Icons.calendar_today_outlined, size: 14),
                label: Text(
                  dateLabel(record['created_at']),
                  style: const TextStyle(fontSize: 11),
                ),
                onPressed: () => menu('calendar'),
              ),
              ActionChip(
                avatar: const Icon(Icons.people_outline, size: 15),
                label: Text(
                  '${rows(transcript['segments']).map((s) => s['speaker']).where((s) => s != null).toSet().length} Speakers',
                  style: const TextStyle(fontSize: 11),
                ),
                onPressed: () => menu('speakers'),
              ),
              ActionChip(
                avatar: const Icon(Icons.folder_outlined, size: 15),
                label: const Text('Recordings', style: TextStyle(fontSize: 11)),
                onPressed: () => menu('move'),
              ),
            ],
          ),
        ],
        if (audio) ...[
          if (notes.isNotEmpty &&
              rows(object(notes.first['data'])['chapters']).isNotEmpty)
            PopupMenuButton<int>(
              tooltip: 'Chapters',
              onSelected: (ms) => widget.model.host.playback(
                PlaybackAction.play,
                widget.id,
                false,
                ms,
                1,
              ),
              itemBuilder: (_) => [
                for (final chapter in rows(
                  object(notes.first['data'])['chapters'],
                ))
                  PopupMenuItem(
                    value:
                        (rows(object(notes.first['data'])['sources'])
                                        .where(
                                          (s) =>
                                              s['source_id'] ==
                                              chapter['source_id'],
                                        )
                                        .firstOrNull?['start_ms']
                                    as num? ??
                                0)
                            .toInt(),
                    child: Text(text(chapter['title'])),
                  ),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'Chapters',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Icon(Icons.keyboard_arrow_down, size: 18),
                  ],
                ),
              ),
            ),
          PersonalAudioPlayer(
            widget.model,
            widget.id,
            peaks: peaks,
            durationMs: (record['duration_ms'] as num? ?? 0).toInt(),
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              const Text(
                'Transcript',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              DropdownButton<String>(
                value: variant,
                items: const [
                  DropdownMenuItem(
                    value: 'original',
                    child: Text('Original text'),
                  ),
                  DropdownMenuItem(value: 'edited', child: Text('Edited text')),
                  DropdownMenuItem(
                    value: 'cleaned',
                    child: Text('Cleaned-up text'),
                  ),
                ],
                onChanged: (v) {
                  setState(() => variant = v!);
                  unawaited(load());
                },
              ),
            ],
          ),
          if (variant == 'cleaned' && transcript['available'] == false)
            TextButton(
              onPressed: () => perform(context, () async {
                final job = await widget.model.api(
                  'POST',
                  '/api/v1/personal/recordings/${widget.id}/cleanup',
                );
                if (context.mounted)
                  await push(context, PersonalJobPage(widget.model, job));
                await load();
              }),
              child: const Text('Generate cleaned-up text'),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: FilterChip(
              label: const Text('Follow audio'),
              selected: follow,
              onSelected: (v) => setState(() => follow = v),
            ),
          ),
          for (var i = 0; i < rows(transcript['segments']).length; i++)
            segment(rows(transcript['segments'])[i], i),
          if (rows(transcript['segments']).isEmpty && !loading)
            EmptyState(
              record['status'] == 'transcribed'
                  ? 'No speech recognized'
                  : 'Preparing your transcript',
              'Your audio remains available.',
            ),
        ] else ...[
          const SizedBox(height: 14),
          Row(
            children: [
              if (notes.isEmpty)
                OutlinedButton.icon(
                  onPressed: generate,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New note'),
                )
              else ...[
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < notes.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: ChoiceChip(
                              label: Text(text(notes[i]['title'])),
                              selected: noteIndex == i,
                              onSelected: (_) => setState(() => noteIndex = i),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'New note',
                  onPressed: generate,
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => push(
              context,
              PersonalRecordingPage(
                widget.model,
                widget.id,
                transcriptOnly: true,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.graphic_eq, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Audio & transcript')),
                  Text(
                    duration(record['duration_ms']),
                    style: TextStyle(fontSize: 11, color: subtle(context)),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
          if (notes.isNotEmpty) ...[
            NoteContent(notes[noteIndex], widget.model),
            TextButton(
              onPressed: () async {
                await push(
                  context,
                  PersonalNotePage(widget.model, text(notes[noteIndex]['id'])),
                );
                await load();
              },
              child: const Text('Open note · Edit and versions'),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  Text(
                    record['status'] == 'transcribed' &&
                            rows(transcript['segments']).isEmpty
                        ? 'No speech recognized'
                        : 'Preparing your summary',
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: rows(transcript['segments']).isEmpty
                        ? null
                        : generate,
                    child: const Text('Generate summary'),
                  ),
                ],
              ),
            ),
        ],
        if (rows(metadata['photos']).isNotEmpty) ...[
          heading('Photos'),
          for (final photo in rows(metadata['photos']))
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(text(photo['title'])),
              subtitle: Text(duration(photo['at_ms'])),
              onTap: () => push(
                context,
                PersonalFilePage(widget.model, text(photo['id'])),
              ),
            ),
        ],
      ],
    ),
  );
  Widget segment(Json s, int index) {
    final key = segmentKeys.putIfAbsent(text(s['id']), () => GlobalKey());
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 7),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: currentSegment == index
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : null,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TextButton(
                onPressed: () => perform(
                  context,
                  () => widget.model.host.playback(
                    PlaybackAction.play,
                    widget.id,
                    false,
                    (s['start_ms'] as num).toInt(),
                    1,
                  ),
                ),
                child: Text(
                  duration(s['start_ms']),
                  style: TextStyle(fontSize: 11, color: subtle(context)),
                ),
              ),
              Expanded(
                child: Text(
                  text(s['speaker_name'] ?? s['speaker']).isEmpty
                      ? 'Speaker'
                      : text(s['speaker_name'] ?? s['speaker']),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) => perform(context, () async {
                  if (v == 'copy')
                    await Clipboard.setData(
                      ClipboardData(text: text(s['text'])),
                    );
                  else
                    await edit(s);
                }),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'copy', child: Text('Copy')),
                  if (variant != 'original')
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                ],
                icon: const Icon(Icons.more_horiz, size: 18),
              ),
            ],
          ),
          SelectableText(
            text(s['text']),
            style: const TextStyle(fontSize: 14, height: 1.7),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    widget.model.removeListener(playbackChanged);
    super.dispose();
  }
}

class PersonalAudioPlayer extends StatelessWidget {
  const PersonalAudioPlayer(
    this.model,
    this.id, {
    super.key,
    required this.peaks,
    required this.durationMs,
  });
  final TenoModel model;
  final String id;
  final List<double> peaks;
  final int durationMs;
  Future<void> act(
    BuildContext context,
    PlaybackAction action,
    int position, [
    double speed = 1,
  ]) => perform(
    context,
    () => model.host.playback(
      action,
      id,
      false,
      position.clamp(0, durationMs),
      speed,
    ),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) {
      final p = model.runtime!.playback, ready = p.mediaId == id && p.ready;
      final position = ready ? p.positionMs : 0;
      return Column(
        children: [
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) => GestureDetector(
              onTapDown: (d) => act(
                context,
                ready ? PlaybackAction.seek : PlaybackAction.play,
                (durationMs * d.localPosition.dx / c.maxWidth).round(),
              ),
              child: SizedBox(
                height: 66,
                width: double.infinity,
                child: CustomPaint(
                  painter: _Wave(
                    peaks,
                    durationMs == 0 ? 0 : position / durationMs,
                    Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(duration(position), style: const TextStyle(fontSize: 11)),
              Text(duration(durationMs), style: const TextStyle(fontSize: 11)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Play or pause',
                onPressed: () => act(
                  context,
                  ready && p.playing
                      ? PlaybackAction.pause
                      : PlaybackAction.play,
                  position,
                ),
                icon: Icon(
                  ready && p.playing
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  size: 32,
                ),
              ),
              IconButton(
                tooltip: 'Back 15 seconds',
                onPressed: () => act(
                  context,
                  ready ? PlaybackAction.seek : PlaybackAction.play,
                  position - 15000,
                ),
                icon: const Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.replay, size: 26),
                    Text('15', style: TextStyle(fontSize: 8)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Forward 15 seconds',
                onPressed: () => act(
                  context,
                  ready ? PlaybackAction.seek : PlaybackAction.play,
                  position + 15000,
                ),
                icon: const Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.forward, size: 26),
                    Text('15', style: TextStyle(fontSize: 8)),
                  ],
                ),
              ),
              PopupMenuButton<double>(
                tooltip: 'Playback speed',
                onSelected: (v) =>
                    act(context, PlaybackAction.speed, position, v),
                itemBuilder: (_) => [
                  for (final v in [.75, 1.0, 1.25, 1.5, 2.0])
                    PopupMenuItem(value: v, child: Text('$v×')),
                ],
                child: Text('${ready ? p.speed : 1.0}×'),
              ),
            ],
          ),
          if (ready && p.error.isNotEmpty) ErrorNotice(p.error),
        ],
      );
    },
  );
}

class _Wave extends CustomPainter {
  _Wave(this.peaks, this.position, this.color);
  final List<double> peaks;
  final double position;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 1;
    for (var i = 0; i < peaks.length; i++) {
      final x = size.width * i / peaks.length,
          h = (peaks[i] * size.height).clamp(1.0, size.height);
      paint.color = color.withValues(
        alpha: i / peaks.length < position ? .85 : .22,
      );
      canvas.drawLine(
        Offset(x, (size.height - h) / 2),
        Offset(x, (size.height + h) / 2),
        paint,
      );
    }
    if (peaks.isEmpty) {
      paint.color = color.withValues(alpha: .2);
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Wave old) =>
      old.position != position || old.peaks != peaks || old.color != color;
}
