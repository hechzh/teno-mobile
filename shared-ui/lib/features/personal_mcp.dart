import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/model.dart';
import '../l10n/ui_strings.dart';
import '../ui/widgets.dart';
import '../ui/personal_widgets.dart';

class McpConnectionsPage extends StatelessWidget {
  const McpConnectionsPage(this.model, {super.key});
  final TenoModel model;
  @override
  Widget build(BuildContext context) => CoreFrame(
    title: 'Codex connections',
    child: CoreLoad(
      load: () => model.api('GET', '/api/v1/mcp/connections'),
      builder: (context, data, reload) => ListView(
        padding: const EdgeInsets.all(coreInset),
        children: [
          const UiText(
            'Connect Codex to recordings and notes you select. Each connection keeps a fixed snapshot until you update it.',
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () async {
              await push(context, McpCreatePage(model));
              reload();
            },
            icon: const Icon(Icons.add),
            label: const UiText('Create connection'),
          ),
          for (final row in rows(data['items']))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(text(row['name'])),
              subtitle: Text(
                '${ui(context, mcpState(text(row['state'])))} · ${ui(context, 'Snapshot')} ${row['revision']}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await push(context, McpConnectionPage(model, text(row['id'])));
                reload();
              },
            ),
        ],
      ),
    ),
  );
}

String mcpState(String value) => switch (value) {
  'active' => 'Active connection',
  'paused' => 'Paused connection',
  'revoked' => 'Revoked connection',
  _ => value,
};

class McpCreatePage extends StatefulWidget {
  const McpCreatePage(this.model, {super.key, this.initial = const []});
  final TenoModel model;
  final List<Json> initial;
  @override
  State<McpCreatePage> createState() => _McpCreatePageState();
}

class _McpCreatePageState extends State<McpCreatePage> {
  final name = TextEditingController();
  List<Json> items = [];
  final selected = <String>{};
  final withSource = <String>{};
  Json? preview;
  bool loading = true, busy = false, more = false;
  String error = '', clientId = requestId();
  int offset = 0, expiryDays = 0;
  String keyOf(Json row) => '${row['type']}:${row['id']}';

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> load({bool append = false}) async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final loaded = <Json>[];
      if (widget.initial.isNotEmpty && !append) {
        for (final value in widget.initial) {
          final type = text(value['type']), id = text(value['id']);
          if (!['recording', 'note'].contains(type)) continue;
          final revision = value['revision'];
          final detail = await widget.model.api(
            'GET',
            '/api/v1/${type == 'note' ? 'notes' : 'recordings'}/$id${type == 'note' && revision != null ? '?revision=$revision' : ''}',
          );
          loaded.add({
            ...detail,
            'id': id,
            'type': type,
            if (revision != null) 'fixed_revision': revision,
          });
          selected.add('$type:$id');
          if (type == 'recording') {
            final notes = await widget.model.list(
              '/api/v1/recordings/$id/notes',
            );
            loaded.addAll(notes.map((n) => {...n, 'type': 'note'}));
          }
        }
        more = false;
      } else {
        final data = await widget.model.api(
          'GET',
          '/api/v1/library/items?limit=100&offset=${append ? offset : 0}&sort=modified',
        );
        final page = rows(data['items']);
        offset = (append ? offset : 0) + page.length;
        more = offset < (data['total'] as num? ?? 0);
        loaded.addAll(
          page.where((v) => ['recording', 'note'].contains(v['type'])),
        );
      }
      if (!mounted) return;
      final all = <String, Json>{
        for (final item in append ? items : <Json>[]) keyOf(item): item,
      };
      for (final item in loaded) {
        final key = keyOf(item);
        if (all[key]?['fixed_revision'] == null) all[key] = item;
      }
      setState(() {
        items = all.values.toList();
        loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          error = TenoModel.friendly(e);
          loading = false;
        });
    }
  }

  List<Json> get selection => [
    for (final item in items)
      if (selected.contains(keyOf(item)))
        {
          'type': item['type'],
          'id': item['id'],
          if (item['fixed_revision'] != null)
            'revision': item['fixed_revision'],
          'include_source': withSource.contains(keyOf(item)),
        },
  ];

  void changed(VoidCallback action) => setState(() {
    action();
    preview = null;
    clientId = requestId();
    error = '';
  });

  Future<void> review() async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final value = await widget.model.api('POST', '/api/v1/mcp/preview', {
        'selection': selection,
      });
      if (mounted) setState(() => preview = value);
    } catch (e) {
      if (mounted) setState(() => error = TenoModel.friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> create() async {
    if (preview == null) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final value = await widget.model.api('POST', '/api/v1/mcp/connections', {
        'client_id': clientId,
        'name': name.text.trim().isEmpty
            ? ui(context, 'Selected personal context')
            : name.text.trim(),
        'selection': selection,
        'preview_hash': preview!['preview_hash'],
        if (expiryDays > 0)
          'expires_at': DateTime.now()
              .toUtc()
              .add(Duration(days: expiryDays))
              .toIso8601String(),
      });
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => McpConnectionPage(widget.model, text(value['id'])),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = TenoModel.friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CoreFrame(
    title: 'Connect Codex',
    child: ListView(
      padding: const EdgeInsets.all(coreInset),
      children: [
        const UiText(
          'Select saved transcript text and notes. Audio and unselected attachments are not included.',
        ),
        const SizedBox(height: 14),
        TextField(
          controller: name,
          enabled: !busy,
          maxLength: 200,
          decoration: InputDecoration(
            labelText: ui(context, 'Connection name'),
          ),
        ),
        for (final item in items) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: selected.contains(keyOf(item)),
            title: Text(text(item['title'])),
            subtitle: Text(
              '${ui(context, item['type'] == 'note' ? 'Note' : 'Transcript')} · v${item['fixed_revision'] ?? item['selected_revision'] ?? item['revision'] ?? 0}',
            ),
            onChanged: busy
                ? null
                : (value) => changed(() {
                    if (value == true) {
                      selected.add(keyOf(item));
                    } else {
                      selected.remove(keyOf(item));
                    }
                  }),
          ),
          if (item['type'] == 'note' &&
              selected.contains(keyOf(item)) &&
              item['source_revision'] != null &&
              text(item['recording_id']).isNotEmpty)
            CheckboxListTile(
              value: withSource.contains(keyOf(item)),
              title: const UiText(
                'Include the transcript version used by this note',
              ),
              onChanged: busy
                  ? null
                  : (value) => changed(() {
                      if (value == true) {
                        withSource.add(keyOf(item));
                      } else {
                        withSource.remove(keyOf(item));
                      }
                    }),
            ),
        ],
        if (loading) const Center(child: CircularProgressIndicator()),
        if (more && !loading)
          TextButton(
            onPressed: () => load(append: true),
            child: const UiText('Load more'),
          ),
        DropdownButtonFormField<int>(
          initialValue: expiryDays,
          decoration: InputDecoration(
            labelText: ui(context, 'Connection expiry'),
          ),
          items: [
            for (final item in [
              (0, 'Until revoked'),
              (7, '7 days'),
              (30, '30 days'),
            ])
              DropdownMenuItem(value: item.$1, child: UiText(item.$2)),
          ],
          onChanged: busy
              ? null
              : (value) => changed(() => expiryDays = value ?? 0),
        ),
        const SizedBox(height: 18),
        if (error.isNotEmpty) ErrorNotice(error, retry: busy ? null : review),
        if (preview == null)
          FilledButton(
            onPressed: busy || selection.isEmpty ? null : review,
            child: const UiText('Review selected content'),
          )
        else ...[
          const Divider(height: 28),
          const UiText(
            'This exact content will be shared with Codex after you authorize it.',
          ),
          for (final source in rows(preview!['sources'])) McpSourceTile(source),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy ? null : create,
            child: const UiText('Create MCP link'),
          ),
        ],
        const SizedBox(height: 12),
        const UiText(
          'Revoking stops future reads. It cannot remove content already read by Codex.',
        ),
      ],
    ),
  );
}

class McpSourceTile extends StatelessWidget {
  const McpSourceTile(this.source, {super.key});
  final Json source;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      source['type'] == 'note' ? Icons.notes : Icons.description_outlined,
    ),
    title: Text(text(source['title'])),
    subtitle: Text(
      '${ui(context, source['type'] == 'note' ? 'Note' : 'Transcript')} v${source['revision']}'
      '${source['source_revision'] == null ? '' : ' · ${ui(context, 'Source version')} ${source['source_revision']}'}'
      '\n${ui(context, 'Saved on')} ${dateLabel(source['saved_at'])}'
      '${source['revoked'] == true ? '\n${ui(context, 'Source access revoked')}' : ''}',
    ),
  );
}

class McpConnectionPage extends StatefulWidget {
  const McpConnectionPage(
    this.model,
    this.id, {
    super.key,
    this.sourceKey,
    this.snapshotId,
    this.chunk = 0,
  });
  final TenoModel model;
  final String id;
  final String? sourceKey, snapshotId;
  final int chunk;
  @override
  State<McpConnectionPage> createState() => _McpConnectionPageState();
}

class _McpConnectionPageState extends State<McpConnectionPage> {
  bool busy = false;
  String updateId = requestId();
  String get path => '/api/v1/mcp/connections/${widget.id}';

  Future<void> update(
    Json data,
    VoidCallback reload,
  ) => perform(context, () async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final preview = await widget.model.api('POST', '$path/preview-update');
      if (!mounted) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const UiText('Update connection snapshot?'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const UiText(
                    'Codex will read these versions on its next request. Existing external conversations keep what they already read.',
                  ),
                  for (final source in rows(preview['sources']))
                    McpSourceTile(source),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const UiText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const UiText('Update content'),
            ),
          ],
        ),
      );
      if (approved != true) return;
      await widget.model.api('POST', '$path/update', {
        'client_id': updateId,
        'base_revision': preview['base_revision'],
        'preview_hash': preview['preview_hash'],
      });
      updateId = requestId();
      reload();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  });

  Future<void> changeState(
    String state,
    VoidCallback reload,
  ) => perform(context, () async {
    if (busy) return;
    if (state == 'revoked' &&
        !await confirm(
          context,
          'Revoke this connection?',
          'Revoking stops future reads. It cannot remove content already read by Codex.',
        ))
      return;
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await widget.model.api('PATCH', path, {'state': state});
      reload();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  });

  @override
  Widget build(BuildContext context) => CoreFrame(
    title: 'Codex connection',
    child: CoreLoad(
      load: () => widget.model.api('GET', path),
      builder: (context, data, reload) => ListView(
        padding: const EdgeInsets.all(coreInset),
        children: [
          Text(
            text(data['name']),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          UiText(mcpState(text(data['state']))),
          Text(
            '${ui(context, 'Snapshot')} ${data['revision']} · ${dateLabel(data['updated_at'])}',
          ),
          if (data['expires_at'] != null)
            Text(
              '${ui(context, 'Connection expiry')}: ${dateLabel(data['expires_at'])}',
            ),
          if (data['last_read_at'] != null)
            Text(
              '${ui(context, 'Last read')}: ${dateLabel(data['last_read_at'])}',
            ),
          const SizedBox(height: 18),
          SelectableText(text(data['url'])),
          OutlinedButton.icon(
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: text(data['url']))),
            icon: const Icon(Icons.copy),
            label: const UiText('Copy MCP link'),
          ),
          const SizedBox(height: 14),
          const UiText(
            'In Codex, open Settings → MCP servers, add this URL, then authenticate with the same Teno account.',
          ),
          const SizedBox(height: 12),
          const UiText(
            'Fixed snapshot. Your later edits appear only after you choose Update content.',
          ),
          for (final source in rows(data['sources']))
            InkWell(
              onTap: source['revoked'] == true
                  ? null
                  : () => push(
                      context,
                      McpReadPage(
                        widget.model,
                        widget.id,
                        text(data['snapshot_id']),
                        text(source['key']),
                      ),
                    ),
              child: McpSourceTile(source),
            ),
          if (widget.sourceKey != null && widget.snapshotId != null) ...[
            const Divider(),
            OutlinedButton(
              onPressed: () => push(
                context,
                McpReadPage(
                  widget.model,
                  widget.id,
                  widget.snapshotId!,
                  widget.sourceKey!,
                  offset: widget.chunk,
                ),
              ),
              child: const UiText('Open cited passage'),
            ),
          ],
          if (data['state'] != 'revoked') ...[
            FilledButton(
              onPressed: busy ? null : () => update(data, reload),
              child: const UiText('Update content'),
            ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => changeState(
                      data['state'] == 'active' ? 'paused' : 'active',
                      reload,
                    ),
              child: UiText(
                data['state'] == 'active'
                    ? 'Pause connection'
                    : 'Resume connection',
              ),
            ),
            TextButton(
              onPressed: busy ? null : () => changeState('revoked', reload),
              child: const UiText('Revoke connection'),
            ),
          ],
          const SizedBox(height: 14),
          const UiText(
            'Revoking stops future reads. It cannot remove content already read by Codex.',
          ),
        ],
      ),
    ),
  );
}

class McpReadPage extends StatefulWidget {
  const McpReadPage(
    this.model,
    this.connectionId,
    this.snapshotId,
    this.sourceKey, {
    super.key,
    this.offset = 0,
  });
  final TenoModel model;
  final String connectionId, snapshotId, sourceKey;
  final int offset;
  @override
  State<McpReadPage> createState() => _McpReadPageState();
}

class _McpReadPageState extends State<McpReadPage> {
  late int offset = widget.offset;
  @override
  Widget build(BuildContext context) => CoreFrame(
    title: 'Snapshot text',
    child: CoreLoad(
      key: ValueKey(offset),
      load: () => widget.model.api(
        'GET',
        '/api/v1/mcp/connections/${widget.connectionId}/read?'
            'source_key=${Uri.encodeQueryComponent(widget.sourceKey)}&snapshot_id=${widget.snapshotId}&offset=$offset',
      ),
      builder: (context, data, reload) => ListView(
        padding: const EdgeInsets.all(coreInset),
        children: [
          for (final part in rows(data['items'])) ...[
            if (part['start_ms'] != null)
              Text(
                duration(part['start_ms']),
                style: TextStyle(color: subtle(context)),
              ),
            SelectableText(text(part['text'])),
            const SizedBox(height: 16),
          ],
          if (offset > 0)
            OutlinedButton(
              onPressed: () =>
                  setState(() => offset = (offset - 12).clamp(0, offset)),
              child: const UiText('Previous'),
            ),
          if (data['next_offset'] != null)
            FilledButton(
              onPressed: () =>
                  setState(() => offset = data['next_offset'] as int),
              child: const UiText('Next'),
            ),
        ],
      ),
    ),
  );
}
