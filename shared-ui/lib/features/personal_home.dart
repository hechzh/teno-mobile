import 'dart:async';
import 'package:flutter/material.dart';
import '../core/model.dart';
import '../ui/widgets.dart';
import '../ui/personal_widgets.dart';
import 'recorder.dart';
import 'personal_actions.dart';
import 'personal_library.dart';
import 'personal_import.dart';
import 'personal_notes.dart';
import 'personal_ask.dart';
import 'personal_settings.dart';
import 'personal_recording.dart';

class PersonalHome extends StatefulWidget {
  const PersonalHome(this.model, {super.key, this.initialSection = 'Home'});
  final TenoModel model;
  final String initialSection;
  @override
  State<PersonalHome> createState() => _PersonalHomeState();
}

class _PersonalHomeState extends State<PersonalHome> {
  String section = 'Home', error = '', sort = 'created', lastRoute = '';
  List<Json> items = [], events = [];
  bool loading = true;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    section = widget.initialSection;
    widget.model.addListener(route);
    unawaited(load());
    timer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (section == 'Home') unawaited(load(silent: true));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => route());
  }

  void route() {
    final value = widget.model.runtime?.openRoute ?? '';
    if (value.isEmpty || value == lastRoute || !mounted) return;
    lastRoute = value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (value.startsWith('recording:'))
        unawaited(
          push(
            context,
            PersonalRecordingPage(widget.model, value.substring(10)),
          ),
        );
      else if (value.startsWith('imports:'))
        unawaited(
          push(context, PersonalImportPage(widget.model, pending: true)),
        );
      else if (value.startsWith('capture:'))
        unawaited(showRecorder(context, widget.model));
      else if (value.startsWith('device:'))
        unawaited(push(context, DevicePage(widget.model)));
    });
  }

  Future<void> load({bool silent = false}) async {
    if (!silent && mounted) setState(() => loading = true);
    try {
      final value = await Future.wait([
        widget.model.list('/api/v1/library/items?sort=$sort&limit=100'),
        widget.model.list('/api/v1/events?limit=200'),
      ]);
      if (mounted)
        setState(() {
          items = value[0];
          events = value[1];
          error = '';
        });
    } catch (e) {
      if (mounted) setState(() => error = TenoModel.friendly(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> create() async {
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.sizeOf(context).width - 270,
        82,
        16,
        0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      elevation: 3,
      items: [
        for (final row in [
          ('record', 'Start recording', Icons.mic_none),
          ('import', 'Import files', Icons.file_download_outlined),
          ('chat', 'New chat', Icons.add_comment_outlined),
        ])
          PopupMenuItem(
            value: row.$1,
            height: 48,
            child: Row(
              children: [
                Icon(row.$3, size: 22),
                const SizedBox(width: 12),
                Text(row.$2),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'phone',
          child: Text('Record with phone', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
    if (!mounted) return;
    switch (value) {
      case 'record':
        await push(context, DevicePage(widget.model));
      case 'phone':
        await startPhone(context, widget.model);
      case 'import':
        await push(context, PersonalImportPage(widget.model));
      case 'chat':
        await push(context, PersonalChatPage(widget.model));
    }
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leadingWidth: 60,
      leading: Builder(
        builder: (c) => Padding(
          padding: const EdgeInsets.all(7),
          child: CircleAction(
            Icons.menu_rounded,
            'Navigation',
            () => Scaffold.of(c).openDrawer(),
          ),
        ),
      ),
      title: section == 'Home' ? null : Text(section),
      actions: [
        if (section == 'Home')
          OutlinedButton(
            onPressed: () => widget.model.capturing
                ? showRecorder(context, widget.model)
                : push(context, DevicePage(widget.model)),
            child: Row(
              children: [
                Icon(
                  Icons.speaker_phone_outlined,
                  size: 20,
                  color: widget.model.runtime!.device.authorized
                      ? const Color(0xFF609770)
                      : null,
                ),
                const SizedBox(width: 7),
                const Icon(Icons.keyboard_arrow_down, size: 17),
              ],
            ),
          ),
        if (['Home', 'Library'].contains(section))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: CircleAction(Icons.add, 'Create', create),
          ),
        if (section == 'Ask Teno')
          CircleAction(
            Icons.add_comment_outlined,
            'New chat',
            () => push(context, PersonalChatPage(widget.model)),
          ),
        const SizedBox(width: 8),
      ],
    ),
    drawer: Drawer(
      width: 310,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: null,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.model.runtime!.session.username,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAction(Icons.search, 'Search', () {
                    Navigator.pop(context);
                    unawaited(push(context, PersonalSearchPage(widget.model)));
                  }),
                ],
              ),
              const SizedBox(height: 24),
              for (final row in [
                ('Home', Icons.home_outlined),
                ('Library', Icons.folder_outlined),
                ('Ask Teno', Icons.auto_awesome_outlined),
                ('Tools', Icons.extension_outlined),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    selected: section == row.$1,
                    selectedTileColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    selectedColor: Theme.of(context).colorScheme.onSurface,
                    leading: Icon(row.$2, size: 23),
                    title: Text(row.$1, style: const TextStyle(fontSize: 15)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => section = row.$1);
                    },
                  ),
                ),
              const Divider(height: 30),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => section = 'Settings');
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Help center'),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(push(context, const PersonalHelpPage()));
                },
              ),
              const Spacer(),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Teno',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    body: SafeArea(
      top: false,
      child: switch (section) {
        'Library' => PersonalListBody(widget.model, root: true),
        'Ask Teno' => PersonalChatHistory(widget.model),
        'Tools' => PersonalTemplates(widget.model),
        'Settings' => PersonalSettings(widget.model),
        _ => home(),
      },
    ),
    bottomNavigationBar: ['Home', 'Library'].contains(section)
        ? SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: AskBar(
                () => push(context, PersonalChatPage(widget.model)),
              ),
            ),
          )
        : null,
  );
  Widget home() {
    final upcoming =
        events
            .map((v) => {'id': v['id'], ...object(v['data'])})
            .where(
              (e) =>
                  DateTime.tryParse(
                    text(e['ends_at'] ?? e['starts_at']),
                  )?.isAfter(DateTime.now()) ??
                  false,
            )
            .toList()
          ..sort(
            (a, b) => text(a['starts_at']).compareTo(text(b['starts_at'])),
          );
    final visible = items
        .where(
          (i) =>
              i['type'] != 'folder' &&
              (i['type'] != 'note' || i['recording_id'] == null),
        )
        .toList();
    final local = widget.model.drafts
        .where(
          (d) => text(d['recording_id']).isEmpty && text(d['file_id']).isEmpty,
        )
        .toList();
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(21, 8, 21, 20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              Expanded(child: heading('Upcoming')),
              IconButton(
                tooltip: 'Calendar',
                onPressed: () =>
                    push(context, PersonalCalendarPage(widget.model)),
                icon: const Icon(Icons.calendar_month_outlined, size: 20),
              ),
            ],
          ),
          if (upcoming.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'All caught up for today',
                    style: TextStyle(fontSize: 13),
                  ),
                  Text(
                    'Review your latest notes or connect your calendar.',
                    style: TextStyle(fontSize: 11, color: subtle(context)),
                  ),
                ],
              ),
            )
          else
            for (final e in upcoming.take(2))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined, size: 21),
                title: Text(
                  text(e['title']),
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  text(e['starts_at']).replaceFirst('T', ' ').substring(0, 16),
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () => push(context, PersonalCalendarPage(widget.model)),
              ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Meeting notes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Sort meeting notes',
                onSelected: (v) {
                  setState(() => sort = v);
                  unawaited(load());
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'created', child: Text('Date created')),
                  PopupMenuItem(
                    value: 'modified',
                    child: Text('Date modified'),
                  ),
                ],
                icon: const Icon(Icons.sort, size: 20),
              ),
            ],
          ),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          if (error.isNotEmpty) ErrorNotice(error, retry: load),
          if (widget.model.capturing)
            TextButton.icon(
              onPressed: () => showRecorder(context, widget.model),
              icon: const Icon(Icons.graphic_eq, size: 18),
              label: Text(
                'Recording · ${duration(widget.model.runtime!.capture.elapsedMs)}',
              ),
            ),
          for (final d in local)
            CoreTile(
              {...d, 'type': d['kind'] == 'file' ? 'file' : 'recording'},
              () =>
                  push(context, PersonalLocalPage(widget.model, text(d['id']))),
            ),
          for (var i = 0; i < visible.length; i++) ...[
            if (i == 0 ||
                dateLabel(visible[i]['created_at']) !=
                    dateLabel(visible[i - 1]['created_at']))
              Padding(
                padding: const EdgeInsets.only(top: 18, bottom: 2),
                child: Text(
                  dateLabel(visible[i]['created_at']),
                  style: TextStyle(fontSize: 11, color: subtle(context)),
                ),
              ),
            CoreTile(visible[i], () async {
              await openPersonalItem(context, widget.model, visible[i]);
              await load();
            }),
          ],
          if (!loading && visible.isEmpty && local.isEmpty && error.isEmpty)
            const EmptyState(
              'Your recordings start here',
              'Connect your recorder or import a file using +.',
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    widget.model.removeListener(route);
    super.dispose();
  }
}
