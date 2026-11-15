import '../l10n/ui_strings.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/model.dart';
import '../ui/widgets.dart';
import '../ui/personal_widgets.dart';
import 'personal_actions.dart';
import 'routes/personal_notes.dart';
import 'routes/personal_import.dart';
import 'routes/personal_search.dart';
export 'personal_search.dart';

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
    localizeTitle: folderId == null,
    actions: [
      CoreAction(
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
    this.commands,
    this.onSelectionChanged,
  });
  final TenoModel model;
  final String? folderId, type;
  final bool trash, root;
  final ValueNotifier<String>? commands;
  final ValueChanged<int?>? onSelectionChanged;
  @override
  State<PersonalListBody> createState() => _PersonalListBodyState();
}

class _PersonalListBodyState extends State<PersonalListBody> {
  List<Json> items = [];
  Set<String> selected = {};
  bool loading = true, selecting = false, more = false, dragging = false;
  String error = '', sort = 'created';
  bool ascending = false;
  String view = 'all';
  List<Json> collections = [];
  final Map<String, List<Json>> branches = {};
  final Map<String, int> branchTotals = {};
  final Map<String, String> branchErrors = {};
  final Set<String> expanded = {}, branchLoading = {};
  bool get stats => widget.model.capabilities['library_stats'] == 1;
  @override
  void initState() {
    super.initState();
    widget.commands?.addListener(command);
    unawaited(load());
  }

  void command() {
    final value = widget.commands?.value.split(':').first;
    if (value == 'select' || value == 'done') {
      setState(() {
        selecting = value == 'select';
        selected.clear();
      });
      widget.onSelectionChanged?.call(selecting ? 0 : null);
    } else if (['created', 'modified', 'name'].contains(value)) {
      setState(() {
        sort = value!;
        ascending =
            widget.commands!.value.split(':').elementAtOrNull(1) == 'asc';
      });
      unawaited(load());
    }
  }

  @override
  void dispose() {
    widget.commands?.removeListener(command);
    super.dispose();
  }

  Future<void> expand(
    String key, {
    bool append = false,
    bool retry = false,
  }) async {
    if (!append && !retry && expanded.contains(key)) {
      setState(() => expanded.remove(key));
      return;
    }
    setState(() {
      expanded.add(key);
      branchLoading.add(key);
      branchErrors.remove(key);
    });
    try {
      final system = key.startsWith('system:');
      final old = append ? branches[key] ?? <Json>[] : <Json>[];
      final data = await widget.model.api(
        'GET',
        '/api/v1/library/items?limit=100&offset=${old.length}&sort=$sort&ascending=$ascending'
            '&include_stats=$stats&${system ? 'type' : 'folder_id'}=${Uri.encodeQueryComponent(system ? key.substring(7) : key)}',
      );
      if (mounted)
        setState(() {
          branches[key] = [...old, ...rows(data['items'])];
          branchTotals[key] = (data['total'] as num? ?? 0).toInt();
        });
    } catch (e) {
      if (mounted) setState(() => branchErrors[key] = TenoModel.friendly(e));
    } finally {
      if (mounted) setState(() => branchLoading.remove(key));
    }
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
            '&include_stats=$stats' +
            (widget.root && view == 'all' ? '&root=true' : '') +
            (widget.folderId == null
                ? (widget.root && view == 'all' ? '&folder_id=' : '')
                : '&folder_id=${Uri.encodeQueryComponent(widget.folderId!)}') +
            (widget.root && view != 'all'
                ? '&type=$view'
                : widget.type == null
                ? ''
                : '&type=${widget.type}'),
      );
      if (mounted)
        setState(() {
          items = append
              ? [...items, ...rows(result['items'])]
              : rows(result['items']);
          more = items.length < (result['total'] as num? ?? 0);
          collections = rows(result['collections']);
          if (!append) {
            branches.clear();
            expanded.clear();
            branchTotals.clear();
          }
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
    } catch (_) {
      /* Drop requests still use server-side ownership validation. */
    }
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
    widget.onSelectionChanged?.call(null);
    await load();
  }

  Future<void> actions(
    String action,
    List<Json> values,
  ) => perform(context, () async {
    if (values.isEmpty) return;
    if (values.singleOrNull?['type'] == 'folder') {
      final folder = values.single;
      if (action == 'edit_folder') {
        final title = await inputDialog(
          context,
          'Rename',
          initial: text(folder['title']),
        );
        if (title == null || title.trim().isEmpty) return;
        await widget.model.api(
          'PATCH',
          '/api/v1/library/items/folder/${folder['id']}',
          {'title': title},
        );
      } else if (action == 'delete_folder') {
        if (!await confirm(
          context,
          'Delete folder?',
          'Files remain in your library.',
        ))
          return;
        await widget.model.api('DELETE', '/api/v1/folders/${folder['id']}');
      } else {
        return;
      }
      if (mounted)
        setState(() {
          selected.clear();
          selecting = false;
        });
      widget.onSelectionChanged?.call(null);
      await load();
    } else if (action == 'move') {
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
                title: UiText(entry.$2),
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
              title: const UiText('New folder'),
              onTap: () => Navigator.pop(sheet, 'folder'),
            ),
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: const UiText('New note'),
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
      () => folder
          ? expand(text(item['id']))
          : openPersonalItem(context, widget.model, item),
      selected: selecting ? selected.contains(identity(item)) : null,
      select: selecting
          ? () {
              setState(() {
                final key = identity(item);
                if (selected.contains(key)) {
                  selected.remove(key);
                } else {
                  // Folder editing is a single-folder operation. File batch
                  // actions never send unsupported folders to the batch API.
                  if (folder)
                    selected.clear();
                  else
                    selected.removeWhere((id) => id.startsWith('folder:'));
                  selected.add(key);
                }
              });
              widget.onSelectionChanged?.call(selected.length);
            }
          : null,
      trailing: !selecting && !widget.trash
          ? IconButton(
              tooltip: ui(context, 'File options'),
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
      onDragStarted: () {
        setState(() => dragging = true);
        unawaited(loadDropFolders());
      },
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

  Widget branch(String key, int depth) => Padding(
    padding: EdgeInsets.only(left: depth < 5 ? 16 : 0),
    child: Column(
      children: [
        for (final child in branches[key] ?? <Json>[]) tree(child, depth + 1),
        if (branchLoading.contains(key))
          const LinearProgressIndicator(minHeight: 2),
        if (branchErrors.containsKey(key))
          ErrorNotice(
            branchErrors[key]!,
            retry: () => expand(key, retry: true),
          ),
        if (!branchLoading.contains(key) &&
            (branches[key]?.length ?? 0) < (branchTotals[key] ?? 0))
          TextButton(
            onPressed: () => expand(key, append: true),
            child: const UiText('Load more'),
          ),
        if (!branchLoading.contains(key) &&
            !branchErrors.containsKey(key) &&
            branches[key]?.isEmpty == true)
          const Padding(
            padding: EdgeInsets.all(16),
            child: UiText('No files here'),
          ),
      ],
    ),
  );

  Widget tree(Json item, int depth) {
    final key = text(item['id']);
    return Column(
      children: [
        Row(
          children: [
            if (item['type'] == 'folder')
              Icon(
                expanded.contains(key)
                    ? Icons.keyboard_arrow_down
                    : Icons.chevron_right,
                size: 16,
                color: subtle(context),
              ),
            Expanded(child: tile(item)),
          ],
        ),
        if (item['type'] == 'folder')
          const Divider(height: 1, thickness: .5, indent: 52),
        if (item['type'] == 'folder' && expanded.contains(key))
          branch(key, depth),
      ],
    );
  }

  Widget collection(String type, String title) {
    final key = 'system:$type';
    final meta =
        collections.where((v) => v['id'] == type).firstOrNull ??
        <String, dynamic>{};
    return Column(
      children: [
        Row(
          children: [
            Icon(
              expanded.contains(key)
                  ? Icons.keyboard_arrow_down
                  : Icons.chevron_right,
              size: 16,
              color: subtle(context),
            ),
            Expanded(
              child: CoreTile({
                'id': key,
                'type': 'folder',
                'title': title,
                if (stats) ...{
                  'child_count': meta['count'],
                  'content_updated_at': meta['updated_at'],
                },
              }, () => expand(key)),
            ),
          ],
        ),
        const Divider(height: 1, thickness: .5, indent: 52),
        if (expanded.contains(key)) branch(key, 0),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.root && view == 'all'
        ? items
              .where((i) => i['type'] == 'folder' && i['folder_id'] == null)
              .toList()
        : items;
    final all = <String, Json>{
      for (final i in [...items, ...branches.values.expand((v) => v)])
        identity(i): i,
    };
    final chosen = all.values
        .where((i) => selected.contains(identity(i)))
        .toList();
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: coreInset),
              children: [
                Row(
                  children: [
                    if (widget.root)
                      PopupMenuButton<String>(
                        tooltip: ui(context, 'My files views'),
                        onSelected: (value) {
                          if (value == 'phone') {
                            unawaited(
                              push(context, PersonalLocalList(widget.model)),
                            );
                            return;
                          }
                          setState(() {
                            view = value;
                            selected.clear();
                            selecting = false;
                          });
                          widget.onSelectionChanged?.call(null);
                          unawaited(load());
                        },
                        itemBuilder: (_) => [
                          for (final v in [
                            ('all', 'My files'),
                            ('images', 'Photos'),
                            ('note', 'Notes'),
                            (
                              'phone',
                              widget.model.webExperience
                                  ? 'Browser imports'
                                  : 'On this phone',
                            ),
                          ])
                            PopupMenuItem(value: v.$1, child: UiText(v.$2)),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Text(
                                switch (view) {
                                  'images' => 'Photos',
                                  'note' => 'Notes',
                                  _ => 'My files',
                                },
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.keyboard_arrow_down, size: 18),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: Text(
                          selecting ? '${selected.length} selected' : 'Files',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (widget.root) const Spacer(),
                    if (!selecting && !widget.trash)
                      IconButton(
                        tooltip: ui(context, 'New folder or note'),
                        onPressed: create,
                        icon: const Icon(Icons.add, size: 21),
                      ),
                    if (!widget.root)
                      PopupMenuButton<String>(
                        tooltip: ui(context, 'Sort and select'),
                        onSelected: (value) {
                          if (value == 'select') {
                            setState(() => selecting = true);
                            return;
                          }
                          setState(() => sort = value);
                          unawaited(load());
                        },
                        itemBuilder: (_) => [
                          for (final v in [
                            ('select', 'Select'),
                            ('created', 'Date created'),
                            ('modified', 'Date modified'),
                            ('name', 'Name'),
                          ])
                            PopupMenuItem(value: v.$1, child: UiText(v.$2)),
                        ],
                        icon: const Icon(Icons.more_horiz, size: 21),
                      ),
                    if (selecting && !widget.root)
                      TextButton(
                        onPressed: () => setState(() {
                          selecting = false;
                          selected.clear();
                        }),
                        child: const UiText('Done'),
                      ),
                  ],
                ),
                if (loading) const LinearProgressIndicator(minHeight: 2),
                if (error.isNotEmpty) ErrorNotice(error, retry: load),
                if (widget.root && view == 'all') ...[
                  collection('recording', 'Recordings'),
                  collection('imports', 'Imports'),
                ],
                for (final item in visible) tree(item, 0),
                if (!loading &&
                    visible.isEmpty &&
                    !(widget.root && view == 'all') &&
                    error.isEmpty)
                  const EmptyState(
                    'No files here',
                    'Add a recording, import a file or create a note.',
                  ),
                if (more)
                  TextButton(
                    onPressed: loading ? null : () => load(append: true),
                    child: const UiText('Load more'),
                  ),
              ],
            ),
          ),
        ),
        if (dragging)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const UiText('Drop into a folder'),
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
                                    color: candidates.isEmpty
                                        ? null
                                        : Theme.of(
                                            context,
                                          ).colorScheme.secondaryContainer,
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
        if (selecting)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: CoreSurface(
                radius: 28,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      for (final action in [
                        if (chosen.singleOrNull?['type'] == 'folder') ...[
                          ('edit_folder', 'Edit', Icons.edit_outlined),
                          ('delete_folder', 'Delete', Icons.delete_outline),
                        ] else ...[
                          if (widget.trash)
                            ('restore', 'Restore', Icons.restore)
                          else
                            ('move', 'Move', Icons.drive_file_move_outline),
                          if (!widget.trash) ('merge', 'Merge', Icons.merge),
                          (
                            widget.trash ? 'delete' : 'trash',
                            widget.trash ? 'Delete' : 'Trash',
                            Icons.delete_outline,
                          ),
                        ],
                      ])
                        Expanded(
                          child: TextButton(
                            onPressed:
                                chosen.isEmpty ||
                                    action.$1 == 'merge' &&
                                        (chosen.length < 2 ||
                                            chosen.any(
                                              (v) => v['type'] != 'recording',
                                            ))
                                ? null
                                : () => actions(action.$1, chosen),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(action.$3, size: 21),
                                const SizedBox(height: 4),
                                Text(
                                  action.$2,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
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
              personalShare(context, widget.model, {
                'type': 'file',
                'id': widget.id,
                ...file,
              }),
            );
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'export', child: UiText('Export as')),
          PopupMenuItem(value: 'share', child: UiText('Share link')),
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
          label: const UiText('Open original'),
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
            child: const UiText('Retry'),
          ),
        ] else if (file['status'] != 'ready') ...[
          const LinearProgressIndicator(minHeight: 2),
          const UiText('Extracting text. The original file is saved.'),
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
            label: const UiText('New note'),
          ),
        if (rows(file['pages']).isNotEmpty)
          DropdownButtonFormField<int>(
            initialValue:
                rows(file['pages']).any((p) => p['page'] == selectedPage)
                ? selectedPage
                : 1,
            decoration: const InputDecoration(label: UiText('Page')),
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
