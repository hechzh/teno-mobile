import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/model.dart';
import '../ui/widgets.dart';
import '../ui/personal_widgets.dart';
import 'personal_actions.dart';
import 'personal_notes.dart';
import 'personal_import.dart';

class PersonalListPage extends StatelessWidget {
  const PersonalListPage(
    this.model, {
    super.key,
    required this.title,
    this.folderId,
    this.type,
    this.trash = false,
  });
  final TenoModel model;
  final String title;
  final String? folderId, type;
  final bool trash;
  @override
  Widget build(BuildContext context) => CoreFrame(
    title: title,
    actions: [
      CircleAction(
        Icons.search,
        'Search',
        () => push(context, PersonalSearchPage(model)),
      ),
    ],
    child: PersonalListBody(
      model,
      folderId: folderId,
      type: type,
      trash: trash,
    ),
  );
}

class PersonalListBody extends StatefulWidget {
  const PersonalListBody(
    this.model, {
    super.key,
    this.folderId,
    this.type,
    this.trash = false,
    this.root = false,
  });
  final TenoModel model;
  final String? folderId, type;
  final bool trash, root;
  @override
  State<PersonalListBody> createState() => _PersonalListBodyState();
}

class _PersonalListBodyState extends State<PersonalListBody> {
  List<Json> items = [];
  Set<String> selected = {};
  bool loading = true, selecting = false, more = false, dragging = false;
  String error = '', sort = 'created';
  bool ascending = false;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load({bool append = false}) async {
    if (mounted)
      setState(() {
        loading = true;
        error = '';
      });
    try {
      final result = await widget.model.api(
        'GET',
        '/api/v1/library/items?limit=100&offset=${append ? items.length : 0}&sort=$sort&ascending=$ascending&trash=${widget.trash}' +
            (widget.root ? '&root=true' : '') +
            (widget.folderId == null
                ? (widget.root ? '&folder_id=' : '')
                : '&folder_id=${Uri.encodeQueryComponent(widget.folderId!)}') +
            (widget.type == null ? '' : '&type=${widget.type}'),
      );
      if (mounted)
        setState(() {
          items = append
              ? [...items, ...rows(result['items'])]
              : rows(result['items']);
          more = items.length < (result['total'] as num? ?? 0);
        });
    } catch (e) {
      if (mounted) setState(() => error = TenoModel.friendly(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String identity(Json item) => '${item['type']}:${item['id']}';
  Future<void> loadDropFolders() async {
    try {
      final folders = await widget.model.list('/api/v1/folders?limit=200');
      if (mounted) setState(() => widget.model.folders = folders);
    } catch (_) { /* Drop requests still use server-side ownership validation. */ }
  }
  Future<void> apply(String action, List<Json> values, {String? folder}) async {
    await widget.model.api('POST', '/api/v1/library/batch', {
      'action': action,
      'items': [
        for (final i in values) {'type': i['type'], 'id': i['id']},
      ],
      if (folder != null) 'folder_id': folder.isEmpty ? null : folder,
    });
    if (mounted)
      setState(() {
        selected.clear();
        selecting = false;
      });
    await load();
  }

  Future<void> actions(
    String action,
    List<Json> values,
  ) => perform(context, () async {
    if (values.isEmpty) return;
    if (action == 'move') {
      final folder = await choosePersonalFolder(context, widget.model);
      if (folder == null) return;
      await apply('move', values, folder: folder);
    } else if (action == 'delete') {
      if (await confirm(
        context,
        'Delete permanently?',
        'This removes the selected cloud content and its shared links. Local copies stay on this phone.',
      ))
        await apply(action, values);
    } else if (action == 'merge') {
      if (values.any((v) => v['type'] != 'recording'))
        throw StateError('Select recordings to merge.');
      final title = await inputDialog(
        context,
        'Merged recording title',
        initial: 'Merged recording',
      );
      if (title == null || !context.mounted) return;
      final job = await widget.model
          .api('POST', '/api/v1/recordings/audio-edit', {
            'action': 'merge',
            'recording_ids': values.map((v) => v['id']).toList(),
            'title': title,
            'client_id': requestId(),
          });
      if (mounted) await push(context, PersonalJobPage(widget.model, job));
      await load();
    } else
      await apply(action, values);
  });
  Future<void> itemMenu(Json item) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in [
              ('rename', 'Rename', Icons.edit_outlined),
              if (item['type'] == 'folder') ...[
                (
                  'subfolder',
                  'New subfolder',
                  Icons.create_new_folder_outlined,
                ),
                ('delete_folder', 'Delete folder', Icons.delete_outline),
              ] else ...[
                ('move', 'Move to folder', Icons.drive_file_move_outline),
                ('trash', 'Move to trash', Icons.delete_outline),
              ],
            ])
              ListTile(
                leading: Icon(entry.$3),
                title: Text(entry.$2),
                onTap: () => Navigator.pop(sheet, entry.$1),
              ),
          ],
        ),
      ),
    );
    if (!mounted || value == null) return;
    if (value == 'subfolder' || value == 'delete_folder') {
      await perform(context, () async {
        if (value == 'subfolder') {
          final title = await inputDialog(context, 'New subfolder');
          if (title == null || title.isEmpty) return;
          await widget.model.api('POST', '/api/v1/folders', {
            'title': title,
            'parent_id': item['id'],
          });
        } else if (await confirm(
          context,
          'Delete folder?',
          'Files remain in your library.',
        )) {
          await widget.model.api('DELETE', '/api/v1/folders/${item['id']}');
        }
        await load();
      });
      return;
    }
    if (value == 'rename')
      await perform(context, () async {
        final title = await inputDialog(
          context,
          'Rename',
          initial: text(item['title']),
        );
        if (title == null) return;
        await widget.model.api(
          'PATCH',
          '/api/v1/library/items/${item['type']}/${item['id']}',
          {'title': title},
        );
        await load();
      });
    else
      await actions(value, [item]);
  }

  Future<void> create() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('New folder'),
              onTap: () => Navigator.pop(sheet, 'folder'),
            ),
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: const Text('New note'),
              onTap: () => Navigator.pop(sheet, 'note'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'note')
      await push(
        context,
        PersonalNoteEditor(widget.model, folderId: widget.folderId),
      );
    if (!mounted) return;
    if (action == 'folder')
      await perform(context, () async {
        final title = await inputDialog(context, 'New folder');
        if (title == null || title.isEmpty) return;
        await widget.model.api('POST', '/api/v1/folders', {
          'title': title,
          if (widget.folderId?.isNotEmpty == true) 'parent_id': widget.folderId,
        });
      });
    await load();
  }

  Widget tile(Json item) {
    final folder = item['type'] == 'folder';
    final child = CoreTile(
      item,
      () => openPersonalItem(context, widget.model, item),
      selected: selecting && !folder ? selected.contains(identity(item)) : null,
      select: selecting && !folder
          ? () => setState(
              () => selected.contains(identity(item))
                  ? selected.remove(identity(item))
                  : selected.add(identity(item)),
            )
          : null,
      trailing: !selecting && !widget.trash
          ? IconButton(
              tooltip: 'File options',
              onPressed: () => itemMenu(item),
              icon: const Icon(Icons.more_horiz, size: 20),
            )
          : null,
    );
    if (selecting || widget.trash) return child;
    if (folder)
      return DragTarget<Json>(
        onWillAcceptWithDetails: (d) => d.data['type'] != 'folder',
        onAcceptWithDetails: (d) => perform(
          context,
          () => apply('move', [d.data], folder: text(item['id'])),
        ),
        builder: (context, candidates, rejected) => Container(
          color: candidates.isEmpty
              ? null
              : Theme.of(context).colorScheme.secondaryContainer,
          child: child,
        ),
      );
    return LongPressDraggable<Json>(
      data: item,
      onDragStarted: () {setState(() => dragging = true); unawaited(loadDropFolders());},
      onDragEnd: (_) {
        if (mounted) setState(() => dragging = false);
      },
      feedback: Material(
        elevation: 5,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(text(item['title'])),
        ),
      ),
      childWhenDragging: Opacity(opacity: .35, child: child),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.root
        ? items
              .where(
                (i) =>
                    i['type'] == 'folder' && i['folder_id'] == null ||
                    i['type'] == 'note' &&
                        i['recording_id'] == null &&
                        i['folder_id'] == null,
              )
              .toList()
        : items;
    final chosen = items.where((i) => selected.contains(identity(i))).toList();
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 21),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        selecting
                            ? '${selected.length} selected'
                            : widget.root
                            ? 'My files'
                            : 'Files',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!selecting && !widget.trash)
                      IconButton(
                        tooltip: 'New folder or note',
                        onPressed: create,
                        icon: const Icon(Icons.add, size: 21),
                      ),
                    PopupMenuButton<String>(
                      tooltip: 'Sort and select',
                      onSelected: (value) {
                        if (value == 'select') {
                          setState(() => selecting = true);
                          return;
                        }
                        setState(() {
                          sort = value;
                        });
                        unawaited(load());
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'select',
                          child: Text('Select'),
                        ),
                        const PopupMenuItem(
                          value: 'created',
                          child: Text('Date created'),
                        ),
                        const PopupMenuItem(
                          value: 'modified',
                          child: Text('Date modified'),
                        ),
                        const PopupMenuItem(value: 'name', child: Text('Name')),
                      ],
                      icon: const Icon(Icons.sort, size: 21),
                    ),
                    if (selecting)
                      TextButton(
                        onPressed: () => setState(() {
                          selecting = false;
                          selected.clear();
                        }),
                        child: const Text('Done'),
                      ),
                  ],
                ),
                if (loading) const LinearProgressIndicator(minHeight: 2),
                if (error.isNotEmpty) ErrorNotice(error, retry: load),
                if (widget.root) ...[
                  for (final entry in [
                    ('Recordings', 'recording', Icons.mic_none),
                    ('Imports', 'imports', Icons.file_download_outlined),
                    ('Photos', 'images', Icons.image_outlined),
                    ('Notes', 'note', Icons.article_outlined),
                  ])
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(entry.$3, size: 22),
                      title: Text(
                        entry.$1,
                        style: const TextStyle(fontSize: 14),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => push(
                        context,
                        PersonalListPage(
                          widget.model,
                          title: entry.$1,
                          type: entry.$2,
                        ),
                      ),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.phone_android_outlined, size: 22),
                    title: const Text('On this phone'),
                    onTap: () => push(context, PersonalLocalList(widget.model)),
                  ),
                  const Divider(height: 28),
                ],
                for (final item in visible) ...[
                  tile(item),
                  Divider(
                    height: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: .45),
                  ),
                ],
                if (!loading &&
                    visible.isEmpty &&
                    !widget.root &&
                    error.isEmpty)
                  const EmptyState(
                    'No files here',
                    'Add a recording, import a file or create a note.',
                  ),
                if (more)
                  TextButton(
                    onPressed: loading ? null : () => load(append: true),
                    child: const Text('Load more'),
                  ),
                if (widget.root)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Trash'),
                    onTap: () => push(
                      context,
                      PersonalListPage(
                        widget.model,
                        title: 'Trash',
                        trash: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (dragging)
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Drop into a folder'),
                  SizedBox(
                    height: 72,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final folder in widget.model.folders)
                          DragTarget<Json>(
                            onWillAcceptWithDetails: (v) =>
                                v.data['type'] != 'folder',
                            onAcceptWithDetails: (v) => perform(
                              context,
                              () => apply('move', [
                                v.data,
                              ], folder: text(folder['id'])),
                            ),
                            builder: (context, candidates, rejected) =>
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                    ),
                                    color: candidates.isNotEmpty
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.secondaryContainer
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.folder_outlined,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        text(object(folder['data'])['title']),
                                      ),
                                    ],
                                  ),
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (selecting && chosen.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                children: [
                  if (widget.trash)
                    OutlinedButton.icon(
                      onPressed: () => actions('restore', chosen),
                      icon: const Icon(Icons.restore, size: 18),
                      label: const Text('Restore'),
                    )
                  else ...[
                    OutlinedButton.icon(
                      onPressed: () => actions('move', chosen),
                      icon: const Icon(Icons.drive_file_move_outline, size: 18),
                      label: const Text('Move'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          chosen.length >= 2 &&
                              chosen.every((v) => v['type'] == 'recording')
                          ? () => actions('merge', chosen)
                          : null,
                      icon: const Icon(Icons.merge, size: 18),
                      label: const Text('Merge'),
                    ),
                  ],
                  OutlinedButton.icon(
                    onPressed: () =>
                        actions(widget.trash ? 'delete' : 'trash', chosen),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(widget.trash ? 'Delete' : 'Trash'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class PersonalSearchPage extends StatefulWidget {
  const PersonalSearchPage(this.model, {super.key});
  final TenoModel model;
  @override
  State<PersonalSearchPage> createState() => _PersonalSearchPageState();
}

class _PersonalSearchPageState extends State<PersonalSearchPage> {
  final query = TextEditingController();
  Timer? timer;
  List<Json> found = [];
  List<String> history = [];
  bool loading = false;
  String error = '', sort = 'match';
  int generation = 0;
  @override
  void initState() {
    super.initState();
    unawaited(loadHistory());
  }

  Future<void> loadHistory() async {
    try {
      final value = await widget.model.command('history');
      if (mounted)
        setState(
          () => history = (value['items'] as List? ?? []).map(text).toList(),
        );
    } catch (_) {}
  }

  void search(String value) {
    timer?.cancel();
    final current = ++generation;
    timer = Timer(const Duration(milliseconds: 350), () async {
      if (value.trim().isEmpty) {
        if (mounted)
          setState(() {
            found = [];
            loading = false;
          });
        return;
      }
      setState(() {
        loading = true;
        error = '';
      });
      try {
        final values = await widget.model.list(
          '/api/v1/library/search?q=${Uri.encodeQueryComponent(value.trim())}&sort=$sort',
        );
        if (mounted && current == generation) setState(() => found = values);
        await widget.model.command('history', {'query': value.trim()});
      } catch (e) {
        if (mounted && current == generation)
          setState(() => error = TenoModel.friendly(e));
      } finally {
        if (mounted && current == generation) setState(() => loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) => CoreFrame(
    title: 'Search',
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: TextField(
            controller: query,
            autofocus: true,
            onChanged: search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search your files',
            ),
          ),
        ),
        if (loading) const LinearProgressIndicator(minHeight: 2),
        if (error.isNotEmpty) ErrorNotice(error),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 21),
            children: [
              if (query.text.isEmpty) ...[
                Row(
                  children: [
                    const Expanded(child: Text('Recent searches')),
                    IconButton(
                      tooltip: 'Clear search history',
                      onPressed: () async {
                        await widget.model.command('history', {'clear': true});
                        await loadHistory();
                      },
                      icon: const Icon(Icons.delete_outline, size: 20),
                    ),
                  ],
                ),
                for (final value in history)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history, size: 19),
                    title: Text(value),
                    onTap: () {
                      query.text = value;
                      search(value);
                    },
                  ),
              ] else ...[
                DropdownButton<String>(
                  value: sort,
                  items: const [
                    DropdownMenuItem(value: 'match', child: Text('Best match')),
                    DropdownMenuItem(
                      value: 'created',
                      child: Text('Date created'),
                    ),
                    DropdownMenuItem(
                      value: 'modified',
                      child: Text('Date modified'),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => sort = v!);
                    search(query.text);
                  },
                ),
                for (final result in found)
                  Builder(
                    builder: (context) {
                      final item = object(result['item']),
                          matches = rows(result['matches']);
                      return CoreTile(
                        item,
                        () => openPersonalItem(
                          context,
                          widget.model,
                          item,
                          matches.isEmpty ? null : matches.first,
                        ),
                        highlight: query.text,
                        snippet: matches.isEmpty
                            ? null
                            : text(matches.first['text']),
                      );
                    },
                  ),
                if (!loading && found.isEmpty && error.isEmpty)
                  const EmptyState('No results', 'Try another word or phrase.'),
              ],
            ],
          ),
        ),
      ],
    ),
  );
  @override
  void dispose() {
    timer?.cancel();
    query.dispose();
    super.dispose();
  }
}

class PersonalFilePage extends StatefulWidget {
  const PersonalFilePage(this.model, this.id, {super.key, this.page});
  final TenoModel model;
  final String id;
  final int? page;
  @override
  State<PersonalFilePage> createState() => _PersonalFilePageState();
}

class _PersonalFilePageState extends State<PersonalFilePage> {
  Json file = {};
  String error = '';
  late int selectedPage = widget.page ?? 1;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final data = await widget.model.api('GET', '/api/v1/files/${widget.id}');
      if (!mounted) return;
      setState(() => file = data);
      if (!['ready', 'failed'].contains(file['status']))
        timer = Timer(const Duration(seconds: 4), load);
    } catch (e) {
      if (mounted) setState(() => error = TenoModel.friendly(e));
    }
  }

  @override
  Widget build(BuildContext context) => CoreFrame(
    title: 'File',
    actions: [
      PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'export')
            unawaited(
              personalExport(context, widget.model, {
                'type': 'file',
                'id': widget.id,
                ...file,
              }),
            );
          else
            unawaited(
              push(
                context,
                PersonalSharePage(widget.model, {
                  'type': 'file',
                  'id': widget.id,
                  ...file,
                }),
              ),
            );
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'export', child: Text('Export as')),
          PopupMenuItem(value: 'share', child: Text('Share link')),
        ],
      ),
    ],
    child: ListView(
      padding: const EdgeInsets.all(21),
      children: [
        if (error.isNotEmpty) ErrorNotice(error, retry: load),
        Text(
          text(file['title']),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (file['kind'] == 'image')
          FutureBuilder<Json>(
            future: widget.model.api(
              'GET',
              '/api/v1/files/${widget.id}/thumbnail',
            ),
            builder: (context, snapshot) {
              final encoded = text(snapshot.data?['image']);
              return encoded.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Image.memory(base64Decode(encoded)),
                    );
            },
          ),
        TextButton.icon(
          onPressed: () => perform(
            context,
            () => widget.model
                .command('preview', {
                  'path': '/api/v1/files/${widget.id}/download',
                  'format': text(file['filename']).split('.').last,
                })
                .then((_) {}),
          ),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Open original'),
        ),
        if (file['status'] == 'failed') ...[
          ErrorNotice(text(object(file['error'])['message'])),
          TextButton(
            onPressed: () => perform(context, () async {
              await widget.model.api(
                'POST',
                '/api/v1/files/${widget.id}/retry',
              );
              await load();
            }),
            child: const Text('Retry'),
          ),
        ] else if (file['status'] != 'ready') ...[
          const LinearProgressIndicator(minHeight: 2),
          const Text('Extracting text. The original file is saved.'),
        ],
        if (file['status'] == 'ready')
          OutlinedButton.icon(
            onPressed: () async {
              final selected = await push<String>(
                context,
                PersonalTemplatePicker(widget.model),
              );
              if (selected == null || !context.mounted) return;
              await perform(context, () async {
                final job = await widget.model.api(
                  'POST',
                  '/api/v1/notes/generate',
                  {
                    'client_id': requestId(),
                    'contexts': [
                      {'type': 'file', 'id': widget.id},
                    ],
                    if (selected.isNotEmpty) 'template_id': selected,
                  },
                );
                if (context.mounted)
                  await push(context, PersonalJobPage(widget.model, job));
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('New note'),
          ),
        if (rows(file['pages']).isNotEmpty)
          DropdownButtonFormField<int>(
            initialValue:
                rows(file['pages']).any((p) => p['page'] == selectedPage)
                ? selectedPage
                : 1,
            decoration: const InputDecoration(labelText: 'Page'),
            items: [
              for (final p in rows(file['pages']))
                DropdownMenuItem(
                  value: (p['page'] as num).toInt(),
                  child: Text(
                    'Page ${p['page']}${widget.page == p['page'] ? ' · Match' : ''}',
                  ),
                ),
            ],
            onChanged: (page) {
              if (page != null) setState(() => selectedPage = page);
            },
          ),
        for (final p in rows(file['pages']).where(
          (p) => p['page'] == selectedPage,
        )) ...[heading('Page ${p['page']}'), SelectableText(text(p['text']))],
      ],
    ),
  );
  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
}
