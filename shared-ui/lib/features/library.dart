import 'dart:async';
import 'package:flutter/material.dart';
import '../core/model.dart';
import '../ui/widgets.dart';
import 'detail.dart';

class LibraryBody extends StatelessWidget {
  const LibraryBody(this.model, {super.key});
  final TenoModel model;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(23),
    children: [
      Row(
        children: [
          const Expanded(
            child: Text('My files', style: TextStyle(fontSize: 14)),
          ),
          IconButton(
            tooltip: 'Search',
            onPressed: () => push(context, SearchPage(model)),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'New folder',
            onPressed: () => perform(context, () async {
              final title = await inputDialog(context, 'New folder');
              if (title == null || title.isEmpty) return;
              await model.api('POST', '/api/v1/folders', {'title': title});
              await model.refresh();
            }),
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
        ],
      ),
      const SizedBox(height: 15),
      MenuRow(
        Icons.folder_outlined,
        'Recordings',
        () => push(context, RecordListPage(model, title: 'Recordings')),
        subtitle: 'All cloud recordings',
      ),
      const Divider(height: 1),
      MenuRow(
        Icons.phone_android,
        'On this phone',
        () => push(context, LocalListPage(model)),
        subtitle: model.drafts.length.toString() + ' local files',
      ),
      const Divider(height: 1),
      for (final folder in model.folders.where(
        (f) => object(f['data'])['parent_id'] == null,
      ))
        Column(
          children: [
            MenuRow(
              Icons.folder_outlined,
              text(object(folder['data'])['title']),
              () => push(
                context,
                RecordListPage(
                  model,
                  title: text(object(folder['data'])['title']),
                  folder: folder,
                ),
              ),
            ),
            const Divider(height: 1),
          ],
        ),
      const SizedBox(height: 28),
      MenuRow(
        Icons.delete_outline,
        'Trash',
        () => push(context, TrashPage(model)),
      ),
    ],
  );
}

class RecordListPage extends StatefulWidget {
  const RecordListPage(
    this.model, {
    super.key,
    required this.title,
    this.folder,
  });
  final TenoModel model;
  final String title;
  final Json? folder;
  @override
  State<RecordListPage> createState() => _RecordListPageState();
}

class _RecordListPageState extends State<RecordListPage> {
  List<Json> items = [];
  bool loading = false, more = true;
  String error = '';
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load({bool append = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final path =
          '/api/v1/recordings?limit=50&offset=' +
          (append ? items.length : 0).toString() +
          (widget.folder == null
              ? ''
              : '&folder_id=' +
                    Uri.encodeQueryComponent(text(widget.folder!['id'])));
      final next = await widget.model.list(path);
      if (mounted)
        setState(() {
          items = append ? [...items, ...next] : next;
          more = next.length == 50;
        });
    } catch (e) {
      if (mounted) setState(() => error = TenoModel.friendly(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> folderMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MenuRow(Icons.drive_file_rename_outline, 'Rename folder', () {
                Navigator.pop(sheet);
                unawaited(
                  perform(context, () async {
                    final value = await inputDialog(
                      context,
                      'Rename folder',
                      initial: widget.title,
                    );
                    if (value == null || value.isEmpty) return;
                    await widget.model.api(
                      'PATCH',
                      '/api/v1/folders/' + text(widget.folder!['id']),
                      {'title': value},
                    );
                    await widget.model.refresh();
                    if (mounted) Navigator.pop(context);
                  }),
                );
              }),
              MenuRow(Icons.create_new_folder_outlined, 'Add subfolder', () {
                Navigator.pop(sheet);
                unawaited(
                  perform(context, () async {
                    final value = await inputDialog(context, 'New subfolder');
                    if (value == null || value.isEmpty) return;
                    await widget.model.api('POST', '/api/v1/folders', {
                      'title': value,
                      'parent_id': widget.folder!['id'],
                    });
                    await widget.model.refresh();
                  }),
                );
              }),
              MenuRow(Icons.delete_outline, 'Delete folder', () {
                Navigator.pop(sheet);
                unawaited(
                  perform(context, () async {
                    if (!await confirm(
                      context,
                      'Delete folder?',
                      'Recordings will stay in your library.',
                    ))
                      return;
                    await widget.model.api(
                      'DELETE',
                      '/api/v1/folders/' + text(widget.folder!['id']),
                    );
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
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.model,
    builder: (context, _) => PageFrame(
      title: widget.title,
      actions: [
        if (widget.folder != null)
          IconButton(
            onPressed: folderMenu,
            tooltip: 'Folder options',
            icon: const Icon(Icons.more_horiz),
          ),
      ],
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(23),
          children: [
            if (loading) const LinearProgressIndicator(minHeight: 2),
            if (error.isNotEmpty) ErrorNotice(error, retry: load),
            if (widget.folder != null)
              for (final child in widget.model.folders.where(
                (f) => object(f['data'])['parent_id'] == widget.folder!['id'],
              ))
                MenuRow(
                  Icons.folder_outlined,
                  text(object(child['data'])['title']),
                  () => push(
                    context,
                    RecordListPage(
                      widget.model,
                      title: text(object(child['data'])['title']),
                      folder: child,
                    ),
                  ),
                ),
            for (final record in items)
              RecordTile(
                record,
                () =>
                    push(context, DetailPage(widget.model, text(record['id']))),
              ),
            if (!loading && error.isEmpty && items.isEmpty)
              const EmptyState(
                'No recordings here',
                'Move a recording into this folder from its options menu.',
              ),
            if (more && items.isNotEmpty)
              TextButton(
                onPressed: loading ? null : () => load(append: true),
                child: const Text('Load more'),
              ),
          ],
        ),
      ),
    ),
  );
}

class LocalListPage extends StatelessWidget {
  const LocalListPage(this.model, {super.key});
  final TenoModel model;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) => PageFrame(
      title: 'On this phone',
      child: model.drafts.isEmpty
          ? const EmptyState(
              'No local recordings',
              'Your recordings and imports are automatically kept here.',
            )
          : ListView(
              padding: const EdgeInsets.all(23),
              children: [
                for (final d in model.drafts)
                  RecordTile(
                    d,
                    () => push(context, LocalPage(model, text(d['id']))),
                    local: true,
                  ),
              ],
            ),
    ),
  );
}

class SearchPage extends StatefulWidget {
  const SearchPage(this.model, {super.key});
  final TenoModel model;
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final query = TextEditingController();
  List<Json> results = [];
  String error = '';
  bool loading = false;
  int generation = 0;
  Timer? debounce;
  void search(String value) {
    debounce?.cancel();
    final version = ++generation;
    if (value.trim().isEmpty) {
      setState(() {
        results = [];
        loading = false;
        error = '';
      });
      return;
    }
    debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() {
        loading = true;
        error = '';
      });
      try {
        final next = await widget.model.list(
          '/api/v1/search?q=' + Uri.encodeQueryComponent(value.trim()),
        );
        if (mounted && version == generation) setState(() => results = next);
      } catch (e) {
        if (mounted && version == generation)
          setState(() => error = TenoModel.friendly(e));
      } finally {
        if (mounted && version == generation) setState(() => loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Search',
    child: Padding(
      padding: const EdgeInsets.all(23),
      child: Column(
        children: [
          TextField(
            controller: query,
            autofocus: true,
            onChanged: search,
            decoration: const InputDecoration(
              hintText: 'Search your recordings',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 16),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          if (error.isNotEmpty)
            ErrorNotice(error, retry: () => search(query.text)),
          Expanded(
            child: results.isEmpty
                ? EmptyState(
                    query.text.isEmpty ? 'Find a conversation' : 'No results',
                    query.text.isEmpty
                        ? 'Search titles and transcripts.'
                        : 'Try a different word or phrase.',
                  )
                : ListView(
                    children: [
                      for (final r in results)
                        RecordTile(
                          r,
                          () => push(
                            context,
                            DetailPage(widget.model, text(r['id'])),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
  @override
  void dispose() {
    generation++;
    debounce?.cancel();
    query.dispose();
    super.dispose();
  }
}

class TrashPage extends StatefulWidget {
  const TrashPage(this.model, {super.key});
  final TenoModel model;
  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  late Future<List<Json>> pending;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    setState(() => pending = widget.model.list('/api/v1/trash'));
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Trash',
    child: FutureBuilder<List<Json>>(
      future: pending,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return ErrorNotice(
            TenoModel.friendly(snapshot.error!),
            retry: reload,
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty)
          return const EmptyState(
            'Trash is empty',
            'Deleted cloud recordings will appear here.',
          );
        return ListView(
          padding: const EdgeInsets.all(23),
          children: [
            for (final r in snapshot.data!)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text(r['title']), style: const TextStyle(fontSize: 16)),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => perform(context, () async {
                          await widget.model.api(
                            'POST',
                            '/api/v1/trash/' + text(r['id']) + '/restore',
                            {},
                          );
                          reload();
                          await widget.model.refresh();
                        }),
                        child: const Text('Restore'),
                      ),
                      TextButton(
                        onPressed: () => perform(context, () async {
                          if (!await confirm(
                            context,
                            'Delete permanently?',
                            'This permanently deletes the cloud recording and its results.',
                          ))
                            return;
                          await widget.model.api(
                            'DELETE',
                            '/api/v1/trash/' + text(r['id']),
                          );
                          reload();
                        }),
                        child: const Text(
                          'Delete permanently',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                ],
              ),
          ],
        );
      },
    ),
  );
}
