import 'package:flutter/material.dart';
import '../core/model.dart';
import '../ui/widgets.dart';
import '../ui/personal_widgets.dart';
import 'personal_actions.dart';
import 'personal_ask.dart';

class PersonalNotePage extends StatefulWidget {
  const PersonalNotePage(this.model, this.id, {super.key});
  final TenoModel model;
  final String id;
  @override
  State<PersonalNotePage> createState() => _PersonalNotePageState();
}

class _PersonalNotePageState extends State<PersonalNotePage> {
  int? revision;
  @override
  Widget build(BuildContext context) => CoreFrame(
    title: 'Note',
    actions: [
      CircleAction(
        Icons.ios_share_outlined,
        'Share',
        () => push(
          context,
          PersonalSharePage(widget.model, {'id': widget.id, 'type': 'note'}),
        ),
      ),
      PopupMenuButton<String>(
        onSelected: (value) => perform(context, () async {
          final note = await widget.model.api(
            'GET',
            '/api/v1/notes/${widget.id}',
          );
          if (!context.mounted) return;
          if (value == 'edit') {
            await push(context, PersonalNoteEditor(widget.model, note: note));
            if (mounted) setState(() => revision = null);
          } else if (value == 'export')
            await personalExport(context, widget.model, {
              'id': widget.id,
              'type': 'note',
              ...note,
            });
          else if (value == 'versions') {
            final values = await widget.model.list(
              '/api/v1/notes/${widget.id}/versions',
            );
            if (!context.mounted) return;
            final chosen = await showModalBottomSheet<int>(
              context: context,
              builder: (sheet) => SafeArea(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final v in values)
                      ListTile(
                        title: Text(
                          'Version ${v['selected_revision'] ?? v['revision']}',
                        ),
                        subtitle: Text(dateLabel(v['updated_at'])),
                        onTap: () => Navigator.pop(
                          sheet,
                          (v['selected_revision'] ?? v['revision']) as int,
                        ),
                      ),
                  ],
                ),
              ),
            );
            if (chosen != null && mounted) setState(() => revision = chosen);
          } else if (value == 'regenerate') {
            final template = await push<String>(
              context,
              PersonalTemplatePicker(widget.model),
            );
            if (template == null || !context.mounted) return;
            final rec = text(note['recording_id']);
            List<Json> sources = [];
            if (rec.isEmpty) {
              for (final source in rows(object(note['data'])['sources'])) {
                final type = text(source['type']);
                final id = text(
                  source['file_id'] ??
                      source['note_id'] ??
                      source['recording_id'],
                );
                if (id.isNotEmpty &&
                    !sources.any((s) => s['id'] == id && s['type'] == type))
                  sources.add({'type': type, 'id': id});
              }
              if (sources.isEmpty) {
                sources =
                    await push<List<Json>>(
                      context,
                      PersonalContextPicker(widget.model, const []),
                    ) ??
                    [];
                if (sources.isEmpty || !context.mounted) return;
              }
            }
            final job = await widget.model.api(
              'POST',
              rec.isEmpty
                  ? '/api/v1/notes/generate'
                  : '/api/v1/recordings/$rec/notes',
              {
                'client_id': requestId(),
                'note_id': widget.id,
                'base_revision': note['revision'],
                if (rec.isEmpty) 'contexts': sources,
                if (template.isNotEmpty) 'template_id': template,
              },
            );
            if (context.mounted)
              await push(context, PersonalJobPage(widget.model, job));
            if (mounted) setState(() => revision = null);
          }
        }),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'versions', child: Text('Version history')),
          PopupMenuItem(value: 'regenerate', child: Text('Regenerate')),
          PopupMenuItem(value: 'export', child: Text('Export as')),
        ],
      ),
    ],
    child: CoreLoad(
      key: ValueKey('${widget.id}:$revision'),
      load: () => widget.model.api(
        'GET',
        '/api/v1/notes/${widget.id}${revision == null ? '' : '?revision=$revision'}',
      ),
      builder: (context, note, reload) => ListView(
        padding: const EdgeInsets.all(21),
        children: [
          Text(
            text(note['title']),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(
            dateLabel(note['created_at']),
            style: TextStyle(fontSize: 12, color: subtle(context)),
          ),
          if (note['stale'] == true)
            const ErrorNotice(
              'The source transcript has changed. This note retains its earlier version.',
            ),
          NoteContent(note, widget.model),
        ],
      ),
    ),
  );
}

class NoteContent extends StatelessWidget {
  const NoteContent(this.note, this.model, {super.key});
  final Json note;
  final TenoModel model;
  @override
  Widget build(BuildContext context) {
    final data = object(note['data']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text(data['template_title']).isEmpty
                    ? 'NOTES'
                    : text(data['template_title']).toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  color: subtle(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                text(note['title']),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in (data['key_points'] as List? ?? []).take(
                    3,
                  ))
                    Container(
                      width: 130,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        text(value),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        SelectableText(
          text(data['body']).isNotEmpty
              ? text(data['body'])
              : text(data['summary']),
          style: const TextStyle(fontSize: 15, height: 1.75),
        ),
        if ((data['key_points'] as List? ?? []).isNotEmpty) ...[
          heading('Key points'),
          for (final point in data['key_points'])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('•  ${text(point)}'),
            ),
        ],
        if ((data['action_items'] as List? ?? []).isNotEmpty) ...[
          heading('Next steps'),
          for (final value in data['action_items'])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '•  ${value is Map ? text(value['title'] ?? value['text']) : text(value)}',
              ),
            ),
        ],
        if (rows(data['sources']).isNotEmpty) ...[
          heading('Sources'),
          for (final source in rows(data['sources']))
            TextButton.icon(
              onPressed: () => openPersonalItem(context, model, {
                'id':
                    source['recording_id'] ??
                    source['file_id'] ??
                    source['note_id'],
                'type': source['type'],
                'title': source['title'],
              }, source),
              icon: const Icon(Icons.link, size: 17),
              label: Text(
                source['page'] != null
                    ? 'Page ${source['page']}'
                    : '${text(source['title'])} · ${duration(source['start_ms'])}',
              ),
            ),
        ],
      ],
    );
  }
}

class PersonalNoteEditor extends StatefulWidget {
  const PersonalNoteEditor(
    this.model, {
    super.key,
    this.note,
    this.folderId,
    this.initialBody,
  });
  final TenoModel model;
  final Json? note;
  final String? folderId, initialBody;
  @override
  State<PersonalNoteEditor> createState() => _PersonalNoteEditorState();
}

class _PersonalNoteEditorState extends State<PersonalNoteEditor> {
  late final title = TextEditingController(text: text(widget.note?['title']));
  late final body = TextEditingController(
    text: widget.initialBody ?? editableNoteText(object(widget.note?['data'])),
  );
  bool busy = false;
  @override
  Widget build(BuildContext context) => CoreFrame(
    title: widget.note == null ? 'New note' : 'Edit note',
    bottom: FilledButton(
      onPressed: busy
          ? null
          : () => perform(context, () async {
              setState(() => busy = true);
              try {
                final note = await widget.model.api(
                  widget.note == null ? 'POST' : 'PATCH',
                  '/api/v1/notes${widget.note == null ? '' : '/${widget.note!['id']}'}',
                  {
                    'title': title.text.trim().isEmpty
                        ? 'Untitled note'
                        : title.text.trim(),
                    'body': body.text,
                    if (widget.folderId != null) 'folder_id': widget.folderId,
                    if (widget.note != null)
                      'revision': widget.note!['revision'],
                  },
                );
                if (context.mounted) Navigator.pop(context, note);
              } finally {
                if (mounted) setState(() => busy = false);
              }
            }),
      child: Text(busy ? 'Saving…' : 'Save'),
    ),
    child: ListView(
      padding: const EdgeInsets.all(21),
      children: [
        TextField(
          controller: title,
          decoration: const InputDecoration(hintText: 'Title'),
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: body,
          minLines: 15,
          maxLines: null,
          decoration: const InputDecoration(hintText: 'Write your note…'),
        ),
      ],
    ),
  );
  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }
}

String editableNoteText(Json data) {
  if (data['body'] != null) return text(data['body']);
  final parts = [text(data['summary'])];
  for (final section in [
    ('key_points', 'Key points'),
    ('action_items', 'Next steps'),
  ]) {
    final values = data[section.$1] as List? ?? [];
    if (values.isNotEmpty)
      parts.add(
        '${section.$2}\n${values.map((v) => '- ${v is Map ? text(v['title'] ?? v['text']) : text(v)}').join('\n')}',
      );
  }
  return parts.join('\n\n');
}

class PersonalTemplatePicker extends StatelessWidget {
  const PersonalTemplatePicker(this.model, {super.key});
  final TenoModel model;
  @override
  Widget build(BuildContext context) => CoreFrame(
    title: 'Select a template',
    child: PersonalTemplates(model, picker: true),
  );
}

class PersonalTemplates extends StatefulWidget {
  const PersonalTemplates(this.model, {super.key, this.picker = false});
  final TenoModel model;
  final bool picker;
  @override
  State<PersonalTemplates> createState() => _PersonalTemplatesState();
}

class _PersonalTemplatesState extends State<PersonalTemplates> {
  List<Json> templates = [];
  String error = '', query = '', category = 'All', tab = 'Recommended';
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await widget.model.list('/api/v1/personal/templates');
      if (mounted) setState(() => templates = data);
    } catch (e) {
      if (mounted) setState(() => error = TenoModel.friendly(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> use(Json item) async {
    final id = text(item['id']);
    final recent =
        (widget.model.personalSettings['recent_templates'] as List? ?? [])
            .map(text)
            .where((v) => v != id)
            .toList();
    await widget.model.updatePersonal({
      'recent_templates': [id, ...recent].take(20).toList(),
    });
    if (!mounted) return;
    if (widget.picker) {
      Navigator.pop(context, id);
      return;
    }
    final apply = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading(text(item['title'])),
              Text(text(item['prompt'])),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(sheet, true),
                child: const Text('Use this template'),
              ),
            ],
          ),
        ),
      ),
    );
    if (apply != true || !mounted) return;
    final sources = await push<List<Json>>(
      context,
      PersonalContextPicker(widget.model, const []),
    );
    if (sources == null || sources.isEmpty || !mounted) return;
    final job = await widget.model.api('POST', '/api/v1/notes/generate', {
      'client_id': requestId(),
      'contexts': sources,
      'template_id': id,
    });
    if (mounted) await push(context, PersonalJobPage(widget.model, job));
  }

  Future<void> editTemplate(Json item, String action) =>
      perform(context, () async {
        if (action == 'delete') {
          if (await confirm(
            context,
            'Delete template?',
            'Existing notes keep their generated content.',
          )) {
            await widget.model.api('DELETE', '/api/v1/templates/${item['id']}');
            await load();
          }
          return;
        }
        final title = await inputDialog(
          context,
          'Template name',
          initial: text(item['title']),
        );
        if (title == null || !mounted) return;
        final prompt = await inputDialog(
          context,
          'Summary instructions',
          initial: text(item['prompt']),
          multiline: true,
        );
        if (prompt == null) return;
        await widget.model.api('PATCH', '/api/v1/templates/${item['id']}', {
          'title': title,
          'prompt': prompt,
        });
        await load();
      });

  @override
  Widget build(BuildContext context) {
    final values = templates
        .where(
          (t) =>
              (tab == 'Recommended'
                  ? t['recommended'] == true
                  : tab == 'Favorites'
                  ? t['favorite'] == true
                  : tab == 'Recently used'
                  ? t['recent'] == true
                  : t['recommended'] != true) &&
              (category == 'All' || t['category'] == category) &&
              (text(t['title']) + ' ' + text(t['description']))
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(21),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Templates',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            CircleAction(
              Icons.add,
              'Create template',
              () => perform(context, () async {
                final name = await inputDialog(context, 'Template name');
                if (name == null || !context.mounted) return;
                final prompt = await inputDialog(
                  context,
                  'Summary instructions',
                  multiline: true,
                );
                if (prompt == null) return;
                await widget.model.api('POST', '/api/v1/templates', {
                  'title': name,
                  'prompt': prompt,
                  'category': 'General',
                });
                await load();
              }),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final value in [
                'Recommended',
                'My space',
                'Favorites',
                'Recently used',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(value),
                    selected: tab == value,
                    onSelected: (_) => setState(() => tab = value),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search templates',
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final value in [
                'All',
                'General',
                'Meeting',
                'Interview',
                'Learning',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 12),
                  child: FilterChip(
                    label: Text(value),
                    selected: category == value,
                    onSelected: (_) => setState(() => category = value),
                  ),
                ),
            ],
          ),
        ),
        if (loading) const LinearProgressIndicator(minHeight: 2),
        if (error.isNotEmpty) ErrorNotice(error, retry: load),
        if (widget.picker)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Default summary'),
            subtitle: const Text('Overview, key points and next steps'),
            onTap: () => Navigator.pop(context, ''),
          ),
        for (final item in values)
          Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: InkWell(
              onTap: () => use(item),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.article_outlined, size: 23),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Favorite template',
                          onPressed: () => perform(context, () async {
                            final favorite =
                                (widget.model.personalSettings['favorite_templates']
                                            as List? ??
                                        [])
                                    .map(text)
                                    .toSet();
                            favorite.contains(item['id'])
                                ? favorite.remove(item['id'])
                                : favorite.add(text(item['id']));
                            await widget.model.updatePersonal({
                              'favorite_templates': favorite.toList(),
                            });
                            await load();
                          }),
                          icon: Icon(
                            item['favorite'] == true
                                ? Icons.star
                                : Icons.star_outline,
                            size: 20,
                          ),
                        ),
                        if (item['recommended'] != true)
                          PopupMenuButton<String>(
                            tooltip: 'Template options',
                            onSelected: (v) => editTemplate(item, v),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                      ],
                    ),
                    Text(
                      text(item['title']),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      text(item['description']),
                      style: TextStyle(fontSize: 12, color: subtle(context)),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      text(item['author']),
                      style: TextStyle(fontSize: 11, color: subtle(context)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (!loading && values.isEmpty)
          const EmptyState(
            'No templates here',
            'Create a template or choose another category.',
          ),
      ],
    );
  }
}
