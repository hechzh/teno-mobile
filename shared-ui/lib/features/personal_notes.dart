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
      CoreAction(
        Icons.ios_share_outlined,
        'Share',
        () => personalShare(context, widget.model, {
          'id': widget.id,
          'type': 'note',
        }),
      ),
      PopupMenuButton<String>(
        tooltip: 'Note options',
        icon: const Icon(Icons.more_horiz),
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
  final narrative = data['schema_version'] == 'personal-notes-v2';
  if (!narrative && data['body'] != null) return text(data['body']);
  final summary = text(data['summary']), body = text(data['body']);
  final parts = [
    if (summary.isNotEmpty && (!narrative || summary != body)) summary,
    if (narrative && body.isNotEmpty) body,
  ];
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
  const PersonalTemplates(
    this.model, {
    super.key,
    this.picker = false,
    this.collection,
    this.initialCategory,
    this.searching = false,
  });
  final TenoModel model;
  final bool picker, searching;
  final String? collection, initialCategory;
  @override
  State<PersonalTemplates> createState() => _PersonalTemplatesState();
}

class _PersonalTemplatesState extends State<PersonalTemplates> {
  List<Json> templates = [];
  String error = '', query = '';
  late String category = widget.initialCategory ?? 'All';
  String tab = 'Favorites';
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

  Future<void> createTemplate() => perform(context, () async {
    final name = await inputDialog(context, 'Template name');
    if (name == null || !mounted) return;
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
  });

  Future<void> openCollection(
    String name, {
    String? category,
    bool search = false,
  }) async {
    final result = await push<String>(
      context,
      CoreFrame(
        title: name,
        child: PersonalTemplates(
          widget.model,
          picker: widget.picker,
          collection: name,
          initialCategory: category,
          searching: search,
        ),
      ),
    );
    if (!mounted) return;
    if (widget.picker && result != null) {
      Navigator.pop(context, result);
      return;
    }
    await load();
  }

  Widget card(Json item, {bool compact = false}) => Container(
    width: compact ? 196 : null,
    margin: EdgeInsets.only(right: compact ? 16 : 0, bottom: compact ? 0 : 14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      border: Border.all(
        color: Theme.of(context).colorScheme.outlineVariant,
        width: .7,
      ),
      borderRadius: BorderRadius.circular(5),
    ),
    child: InkWell(
      onTap: () => perform(context, () => use(item)),
      borderRadius: BorderRadius.circular(5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 25,
                  color: item['category'] == 'Meeting'
                      ? const Color(0xFF81AA77)
                      : const Color(0xFFA858C4),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Favorite template',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
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
                    item['favorite'] == true ? Icons.star : Icons.star_outline,
                    size: 19,
                  ),
                ),
                if (item['recommended'] != true && !compact)
                  PopupMenuButton<String>(
                    tooltip: 'Template options',
                    onSelected: (v) => editTemplate(item, v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              text(item['title']),
              maxLines: compact ? 2 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              text(item['description']),
              maxLines: compact ? 3 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                color: subtle(context),
              ),
            ),
            if (compact) const Spacer() else const SizedBox(height: 25),
            Text(
              text(item['author']).isEmpty ? 'Teno' : text(item['author']),
              style: TextStyle(fontSize: 11, color: subtle(context)),
            ),
          ],
        ),
      ),
    ),
  );

  Widget shelf(List<Json> values) => SizedBox(
    height: 216 * MediaQuery.textScalerOf(context).scale(1),
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [for (final item in values) card(item, compact: true)],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final recentIds =
        (widget.model.personalSettings['recent_templates'] as List? ?? [])
            .map(text)
            .toSet();
    final categories = templates
        .map((t) => text(t['category']))
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList();
    final mine = templates
        .where(
          (t) =>
              t['favorite'] == true ||
              t['recommended'] != true ||
              recentIds.contains(t['id']),
        )
        .toList();
    final values = templates
        .where(
          (t) =>
              (widget.collection != 'My templates' ||
                  (tab == 'Favorites'
                      ? t['favorite'] == true
                      : tab == 'Recently used'
                      ? recentIds.contains(t['id'])
                      : t['recommended'] != true)) &&
              (category == 'All' || t['category'] == category) &&
              (text(t['title']) + ' ' + text(t['description']))
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    final root = widget.collection == null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(coreInset, 8, coreInset, 24),
      children: [
        if (loading) const LinearProgressIndicator(minHeight: 2),
        if (error.isNotEmpty) ErrorNotice(error, retry: load),
        if (root) ...[
          if (!widget.picker)
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Text(
                'Templates',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => openCollection('My templates'),
            child: Row(
              children: [
                heading('My templates'),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 20, color: subtle(context)),
              ],
            ),
          ),
          if (mine.isNotEmpty)
            shelf(mine)
          else
            SizedBox(
              height: 160 * MediaQuery.textScalerOf(context).scale(1),
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Your templates',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Save favorites or create your own.',
                      style: TextStyle(color: subtle(context)),
                    ),
                    TextButton.icon(
                      onPressed: createTemplate,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Create template'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: heading('Category')),
              TextButton.icon(
                onPressed: () =>
                    openCollection('Search templates', search: true),
                icon: const Icon(Icons.search, size: 21),
                label: const Text('Search'),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, c) => Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final value in categories)
                  SizedBox(
                    width: (c.maxWidth - 16) / 2,
                    child: InkWell(
                      onTap: () => openCollection(value, category: value),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(switch (value) {
                              'Meeting' => Icons.people_outline,
                              'Interview' => Icons.question_answer_outlined,
                              'Learning' => Icons.school_outlined,
                              _ => Icons.category_outlined,
                            }, size: 22),
                            const SizedBox(height: 10),
                            Text(value, style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.picker)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Default summary'),
              subtitle: const Text('Overview, key points and next steps'),
              onTap: () => Navigator.pop(context, ''),
            ),
          for (final value in categories) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: () => openCollection(value, category: value),
              child: Row(
                children: [
                  heading(value),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, size: 20, color: subtle(context)),
                ],
              ),
            ),
            shelf(templates.where((t) => t['category'] == value).toList()),
          ],
        ] else ...[
          if (widget.collection == 'My templates') ...[
            Row(
              children: [
                const Spacer(),
                TextButton.icon(
                  onPressed: createTemplate,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create template'),
                ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final value in [
                    'Favorites',
                    'Recently used',
                    'Created by me',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 16),
                      child: ChoiceChip(
                        label: Text(value),
                        selected: tab == value,
                        onSelected: (_) => setState(() => tab = value),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (widget.searching)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => query = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 20),
                  hintText: 'Search templates',
                ),
              ),
            ),
          for (final item in values) card(item),
          if (!loading && values.isEmpty)
            const EmptyState(
              'No templates here',
              'Save a favorite, create a template or choose another category.',
            ),
        ],
      ],
    );
  }
}
