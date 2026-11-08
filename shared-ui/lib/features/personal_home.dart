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
  bool loading = true, navigationOpen = false;
  int? selectedCount;
  int commandSequence = 0;
  final libraryCommands = ValueNotifier<String>('');
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
        unawaited(showPersonalImport(context, widget.model, pending: true));
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
        widget.model.list(
          '/api/v1/library/items?sort=$sort&limit=100&include_stats=${widget.model.capabilities['library_stats'] == 1}',
        ),
        widget.model.webExperience
            ? Future.value(<Json>[])
            : widget.model.list('/api/v1/events?limit=200'),
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
          if (!widget.model.webExperience)
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
        if (!widget.model.webExperience) const PopupMenuDivider(),
        if (!widget.model.webExperience)
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
        await showPersonalImport(context, widget.model);
      case 'chat':
        await push(context, PersonalChatPage(widget.model));
    }
    await load();
  }

  void navigate(String value) => setState(() {
    section = value;
    navigationOpen = false;
    selectedCount = null;
  });
  void search() => unawaited(
    push(
      context,
      PersonalSearchPage(
        widget.model,
        onNavigation: () {
          if (mounted) setState(() => navigationOpen = true);
        },
      ),
    ),
  );

  Widget sidebar(double width) => SizedBox(
    width: width,
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () => navigate('Settings'),
                    borderRadius: BorderRadius.circular(28),
                    child: CoreSurface(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline, size: 20),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              widget.model.runtime!.session.username,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CoreAction(Icons.search, 'Search', () {
                setState(() => navigationOpen = false);
                search();
              }),
            ],
          ),
          const SizedBox(height: 16),
          for (final row in [
            ('Home', Icons.home_outlined),
            ('Library', Icons.folder_outlined),
            ('Ask Teno', Icons.auto_awesome_outlined),
            ('Tools', Icons.extension_outlined),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                minVerticalPadding: 16,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                selected: section == row.$1,
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                selectedColor: Theme.of(context).colorScheme.onSurface,
                leading: Icon(row.$2, size: 26),
                title: Text(
                  row.$1,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () => navigate(row.$1),
              ),
            ),
          const Divider(height: 30),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            minVerticalPadding: 16,
            leading: const Icon(Icons.settings_outlined, size: 26),
            title: const Text(
              'Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            onTap: () => navigate('Settings'),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            minVerticalPadding: 16,
            leading: const Icon(Icons.help_outline, size: 26),
            title: const Text(
              'Help center',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            onTap: () {
              setState(() => navigationOpen = false);
              unawaited(
                push(
                  context,
                  PersonalHelpPage(webExperience: widget.model.webExperience),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final drawerWidth = MediaQuery.sizeOf(context).width * .82;
    return PopScope(
      canPop: !navigationOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && navigationOpen) setState(() => navigationOpen = false);
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Offstage(
                  offstage: !navigationOpen,
                  child: sidebar(drawerWidth),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 230),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(
              navigationOpen ? drawerWidth : 0,
              0,
              0,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(navigationOpen ? 42 : 0),
              boxShadow: navigationOpen
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .08),
                        blurRadius: 26,
                        offset: const Offset(-8, 0),
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(navigationOpen ? 42 : 0),
              child: Stack(
                children: [
                  ExcludeSemantics(
                    excluding: navigationOpen,
                    child: Scaffold(
                      appBar: AppBar(
                        leadingWidth: 68,
                        leading: Padding(
                          padding: const EdgeInsets.all(12),
                          child: CoreAction(
                            Icons.menu_rounded,
                            'Navigation',
                            () => setState(() => navigationOpen = true),
                          ),
                        ),
                        title: section == 'Home'
                            ? (widget.model.webExperience
                                  ? const Text('Teno')
                                  : null)
                            : Text(
                                selectedCount == null
                                    ? section
                                    : '$selectedCount selected',
                              ),
                        actions: [
                          if (section == 'Home') ...[
                            if (!widget.model.webExperience)
                              InkWell(
                                borderRadius: BorderRadius.circular(28),
                                onTap: () => widget.model.capturing
                                    ? showRecorder(context, widget.model)
                                    : push(context, DevicePage(widget.model)),
                                child: CoreSurface(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 3,
                                        height: 25,
                                        decoration: BoxDecoration(
                                          color:
                                              widget
                                                  .model
                                                  .runtime!
                                                  .device
                                                  .authorized
                                              ? const Color(0xFF65B477)
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.outlineVariant,
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.speaker_phone_outlined,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 20),
                                      const Icon(
                                        Icons.keyboard_arrow_down,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(width: 10),
                            CoreAction(Icons.add, 'Create', create),
                          ],
                          if (section == 'Library' &&
                              selectedCount == null) ...[
                            CoreAction(Icons.search, 'Search', search),
                            const SizedBox(width: 10),
                            CoreSurface(
                              radius: 24,
                              child: PopupMenuButton<String>(
                                tooltip: 'Library options',
                                onSelected: (value) {
                                  if (value == 'trash') {
                                    unawaited(
                                      push(
                                        context,
                                        PersonalListPage(
                                          widget.model,
                                          title: 'Trash',
                                          trash: true,
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  libraryCommands.value =
                                      '$value:${++commandSequence}';
                                },
                                itemBuilder: (_) => [
                                  for (final v in [
                                    ('select', 'Select'),
                                    ('created:desc', 'Date created · newest'),
                                    ('modified:desc', 'Date modified · newest'),
                                    ('name:asc', 'Name'),
                                    ('trash', 'Trash'),
                                  ])
                                    PopupMenuItem(
                                      value: v.$1,
                                      child: Text(v.$2),
                                    ),
                                ],
                                icon: const Icon(Icons.more_horiz, size: 23),
                                constraints: const BoxConstraints(
                                  minWidth: 230,
                                ),
                              ),
                            ),
                          ],
                          if (section == 'Library' && selectedCount != null)
                            TextButton(
                              onPressed: () => libraryCommands.value =
                                  'done:${++commandSequence}',
                              child: const Text('Done'),
                            ),
                          if (section == 'Ask Teno')
                            CoreAction(
                              Icons.add,
                              'New chat',
                              () =>
                                  push(context, PersonalChatPage(widget.model)),
                            ),
                          const SizedBox(width: 16),
                        ],
                      ),
                      body: SafeArea(
                        top: false,
                        child: switch (section) {
                          'Library' => PersonalListBody(
                            widget.model,
                            root: true,
                            commands: libraryCommands,
                            onSelectionChanged: (count) {
                              if (mounted)
                                setState(() => selectedCount = count);
                            },
                          ),
                          'Ask Teno' => PersonalChatHistory(widget.model),
                          'Tools' => PersonalTemplates(widget.model),
                          'Settings' => PersonalSettings(widget.model),
                          _ => home(),
                        },
                      ),
                      bottomNavigationBar:
                          ['Home', 'Library'].contains(section) &&
                              selectedCount == null
                          ? SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  8,
                                  20,
                                  20,
                                ),
                                child: AskBar(
                                  () => push(
                                    context,
                                    PersonalChatPage(widget.model),
                                  ),
                                  label: section == 'Home'
                                      ? 'Ask Teno'
                                      : 'Ask me anything about your recordings',
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                  if (navigationOpen)
                    Positioned.fill(
                      child: Semantics(
                        button: true,
                        label: 'Close navigation',
                        child: GestureDetector(
                          onTap: () => setState(() => navigationOpen = false),
                          child: ColoredBox(
                            color: Theme.of(
                              context,
                            ).colorScheme.surface.withValues(alpha: .55),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
        padding: const EdgeInsets.fromLTRB(coreInset, 4, coreInset, 20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (!widget.model.webExperience) ...[
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
                    text(
                      e['starts_at'],
                    ).replaceFirst('T', ' ').substring(0, 16),
                    style: const TextStyle(fontSize: 11),
                  ),
                  onTap: () =>
                      push(context, PersonalCalendarPage(widget.model)),
                ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Meeting notes',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
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
                  coreDate(visible[i]['created_at'], weekday: true),
                  style: TextStyle(fontSize: 13, color: subtle(context)),
                ),
              ),
            CoreTile(visible[i], () async {
              await openPersonalItem(context, widget.model, visible[i]);
              await load();
            }, showFolder: true),
          ],
          if (!loading && visible.isEmpty && local.isEmpty && error.isEmpty)
            EmptyState(
              'Your recordings start here',
              widget.model.webExperience
                  ? 'Import a file using + to get started.'
                  : 'Connect your recorder or import a file using +.',
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    libraryCommands.dispose();
    widget.model.removeListener(route);
    super.dispose();
  }
}
