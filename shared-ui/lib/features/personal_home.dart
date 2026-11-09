import 'dart:async';
import 'package:flutter/material.dart';
import '../core/model.dart';
import '../l10n/ui_strings.dart';
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
  List<Json> items = [];
  Json brief = {}, briefItem = {};
  String briefStamp = '';
  bool loading = true;
  int? selectedCount;
  int commandSequence = 0, loadSequence = 0;
  final libraryCommands = ValueNotifier<String>('');
  final visited = <String>{'Home'};
  Timer? timer;
  @override
  void initState() {
    super.initState();
    section = widget.initialSection;
    visited.add(section);
    widget.model.addListener(route);
    unawaited(load());
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
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
      if (value.startsWith('recording:')) {
        unawaited(
          push(
            context,
            PersonalRecordingPage(widget.model, value.substring(10)),
          ),
        );
      } else if (value.startsWith('imports:')) {
        unawaited(showPersonalImport(context, widget.model, pending: true));
      } else if (!widget.model.webExperience && value.startsWith('capture:')) {
        unawaited(showRecorder(context, widget.model));
      } else if (!widget.model.webExperience && value.startsWith('device:')) {
        unawaited(push(context, DevicePage(widget.model)));
      }
    });
  }

  Future<void> load({bool silent = false}) async {
    final stamp = ++loadSequence, scope = widget.model.runtime?.session.scope;
    if (!silent && mounted) setState(() => loading = true);
    try {
      final values = await Future.wait([
        widget.model.list(
          '/api/v1/library/items?sort=$sort&limit=100&include_stats=${widget.model.capabilities['library_stats'] == 1}',
        ),
        widget.model.list(
          '/api/v1/library/items?type=note&sort=modified&limit=20',
        ),
      ]);
      if (!mounted ||
          stamp != loadSequence ||
          scope != widget.model.runtime?.session.scope)
        return;
      setState(() {
        items = values[0];
        error = '';
        loading = false;
      });
      final candidates = values[1]
          .where((v) => text(v['recording_id']).isNotEmpty)
          .toList();
      if (candidates.isEmpty) {
        setState(() {
          brief = {};
          briefItem = {};
          briefStamp = '';
        });
      } else {
        final item = candidates.first,
            key = '${candidates.first['id']}:${candidates.first['updated_at']}';
        if (key != briefStamp) {
          final note = await widget.model.api(
            'GET',
            '/api/v1/notes/${item['id']}',
          );
          if (!mounted ||
              stamp != loadSequence ||
              scope != widget.model.runtime?.session.scope)
            return;
          setState(() {
            brief = note;
            briefItem = item;
            briefStamp = key;
          });
        }
      }
    } catch (e) {
      if (mounted && stamp == loadSequence)
        setState(() {
          error = TenoModel.friendly(e);
          loading = false;
        });
    }
  }

  void navigate(String value) => setState(() {
    section = value;
    visited.add(value);
    selectedCount = null;
  });
  Future<void> search() => push(context, PersonalSearchPage(widget.model));
  Future<void> importFiles() async {
    await showPersonalImport(context, widget.model);
    if (mounted) await load();
  }

  Future<void> record() => widget.model.capturing
      ? showRecorder(context, widget.model)
      : push(context, DevicePage(widget.model));

  Widget libraryMenu() => PopupMenuButton<String>(
    tooltip: ui(context, 'Library options'),
    icon: const Icon(Icons.more_horiz),
    onSelected: (value) {
      if (value == 'trash') {
        unawaited(
          push(
            context,
            PersonalListPage(widget.model, title: 'Trash', trash: true),
          ),
        );
      } else {
        libraryCommands.value = '$value:${++commandSequence}';
      }
    },
    itemBuilder: (_) => [
      for (final v in [
        ('select', 'Select'),
        ('created:desc', 'Date created · newest'),
        ('modified:desc', 'Date modified · newest'),
        ('name:asc', 'Name'),
        ('trash', 'Trash'),
      ])
        PopupMenuItem(value: v.$1, child: UiText(v.$2)),
    ],
  );

  Widget sidebar() => Container(
    width: 232,
    decoration: BoxDecoration(
      border: Border(
        right: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 28, 24, 32),
            child: UiText(
              'Teno',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w600,
                letterSpacing: -1,
              ),
            ),
          ),
          for (final row in [
            ('Home', Icons.home_outlined),
            ('Library', Icons.folder_outlined),
            ('Ask Teno', Icons.auto_awesome_outlined),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                selected: section == row.$1,
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                leading: Icon(row.$2, size: 22),
                title: UiText(row.$1 == 'Ask Teno' ? 'Assistant' : row.$1),
                onTap: () => navigate(row.$1),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const UiText('Settings'),
              selected: section == 'Settings',
              selectedTileColor: Theme.of(
                context,
              ).colorScheme.secondaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              onTap: () => navigate('Settings'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Text(
              widget.model.runtime?.session.username ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: subtle(context)),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final wide =
        widget.model.webExperience && MediaQuery.sizeOf(context).width >= 1000;
    final sections = ['Home', 'Library', 'Ask Teno', 'Tools', 'Settings'];
    final content = Scaffold(
      appBar: section == 'Ask Teno'
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              centerTitle: false,
              toolbarHeight: section == 'Home' ? 88 : 60,
              title: section == 'Home'
                  ? const UiText(
                      'Home',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : selectedCount == null
                  ? UiText(section)
                  : Text(context.strings.selectedCount(selectedCount!)),
              actions: [
                if (section == 'Home') ...[
                  if (!widget.model.webExperience)
                    Tooltip(
                      message: ui(context, 'My recorder'),
                      child: ActionChip(
                        avatar: Icon(
                          widget.model.capturing
                              ? Icons.graphic_eq
                              : Icons.speaker_phone_outlined,
                          size: 18,
                        ),
                        label: Text(
                          widget.model.runtime!.device.authorized &&
                                  RegExp(r'^\d+%$').hasMatch(
                                    widget.model.runtime!.device.battery,
                                  )
                              ? widget.model.runtime!.device.battery
                              : '',
                        ),
                        onPressed: record,
                      ),
                    ),
                  CoreAction(Icons.search, 'Search', search),
                  CoreAction(
                    widget.model.webExperience
                        ? Icons.file_upload_outlined
                        : Icons.mic_none,
                    widget.model.webExperience
                        ? 'Import files'
                        : 'Start recording',
                    widget.model.webExperience ? importFiles : record,
                  ),
                ],
                if (section == 'Library' && selectedCount == null) ...[
                  CoreAction(Icons.search, 'Search', search),
                  libraryMenu(),
                ],
                if (section == 'Library' && selectedCount != null)
                  TextButton(
                    onPressed: () =>
                        libraryCommands.value = 'done:${++commandSequence}',
                    child: const UiText('Done'),
                  ),
                const SizedBox(width: 12),
              ],
            ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: section == 'Ask Teno' ? 860 : 1040,
            ),
            child: IndexedStack(
              index: sections.indexOf(section),
              children: [
                home(),
                if (visited.contains('Library'))
                  PersonalListBody(
                    widget.model,
                    root: true,
                    commands: libraryCommands,
                    onSelectionChanged: (count) {
                      if (mounted) setState(() => selectedCount = count);
                    },
                  )
                else
                  const SizedBox.shrink(),
                if (visited.contains('Ask Teno'))
                  PersonalChatPage(widget.model, embedded: true)
                else
                  const SizedBox.shrink(),
                if (visited.contains('Tools'))
                  PersonalTemplates(widget.model)
                else
                  const SizedBox.shrink(),
                if (visited.contains('Settings'))
                  PersonalSettings(widget.model)
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: section == 'Ask Teno'
                  ? 1
                  : section == 'Settings'
                  ? 2
                  : 0,
              onDestinationSelected: (i) =>
                  navigate(['Home', 'Ask Teno', 'Settings'][i]),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home_rounded),
                  label: ui(context, 'Home'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: ui(context, 'Assistant'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  label: ui(context, 'Settings'),
                ),
              ],
            ),
    );
    return PopScope(
      canPop: section == 'Home',
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) navigate('Home');
      },
      child: wide
          ? Scaffold(
              body: Row(
                children: [
                  sidebar(),
                  Expanded(child: content),
                ],
              ),
            )
          : content,
    );
  }

  Widget home() {
    final visible = items
        .where((i) => i['type'] == 'recording')
        .take(10)
        .toList();
    final local = widget.model.drafts
        .where(
          (d) => text(d['recording_id']).isEmpty && text(d['file_id']).isEmpty,
        )
        .toList();
    final data = object(brief['data']);
    final summary = text(data['summary']).trim().isNotEmpty
        ? text(data['summary'])
        : text(data['body']);
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(coreInset, 0, coreInset, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      color: colors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const UiText(
                      'Your brief',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (summary.isEmpty)
                  const UiText(
                    'Your brief will appear here when a note is ready.',
                  )
                else
                  Text(
                    summary,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, height: 1.8),
                  ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    context.strings.briefVersion(
                      text(brief['title']).isEmpty
                          ? text(briefItem['title'])
                          : text(brief['title']),
                      text(brief['revision']),
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => push(
                        context,
                        PersonalRecordingPage(
                          widget.model,
                          text(briefItem['recording_id']),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const UiText('View source'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final actions = <Widget>[
                OutlinedButton.icon(
                  onPressed: () => navigate('Library'),
                  icon: const Icon(Icons.folder_outlined, size: 19),
                  label: const UiText('Library'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontFamilyFallback: ['NotoSansSC'],
                      fontSize: 13,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: importFiles,
                  icon: const Icon(Icons.file_upload_outlined, size: 19),
                  label: const UiText('Import files'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontFamilyFallback: ['NotoSansSC'],
                      fontSize: 13,
                    ),
                  ),
                ),
                if (!widget.model.webExperience)
                  OutlinedButton.icon(
                    onPressed: () =>
                        push(context, PersonalCalendarPage(widget.model)),
                    icon: const Icon(Icons.calendar_month_outlined, size: 19),
                    label: const UiText('Calendar'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontFamilyFallback: ['NotoSansSC'],
                        fontSize: 13,
                      ),
                    ),
                  ),
              ];
              return Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  for (final action in actions)
                    SizedBox(
                      width:
                          (constraints.maxWidth - 8 * (actions.length - 1)) /
                          actions.length,
                      child: action,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: UiText(
                  'Recent recordings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => navigate('Library'),
                child: const UiText('View all'),
              ),
            ],
          ),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          if (error.isNotEmpty) ErrorNotice(error, retry: load),
          if (!widget.model.webExperience && widget.model.capturing)
            TextButton.icon(
              onPressed: record,
              icon: const Icon(Icons.graphic_eq),
              label: Text(
                '${ui(context, 'Recording')} · ${duration(widget.model.runtime!.capture.elapsedMs)}',
              ),
            ),
          for (final d in local)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CoreSurface(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                child: CoreTile(
                  {...d, 'type': d['kind'] == 'file' ? 'file' : 'recording'},
                  () => push(
                    context,
                    PersonalLocalPage(widget.model, text(d['id'])),
                  ),
                ),
              ),
            ),
          for (final item in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CoreSurface(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                child: CoreTile(item, () async {
                  await openPersonalItem(context, widget.model, item);
                  if (mounted) await load();
                }, showFolder: true),
              ),
            ),
          if (!loading && visible.isEmpty && local.isEmpty && error.isEmpty)
            EmptyState(
              'Your recordings start here',
              'Import a file to create your first note.',
              action: FilledButton.icon(
                onPressed: importFiles,
                icon: const Icon(Icons.add),
                label: const UiText('Import files'),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    ++loadSequence;
    timer?.cancel();
    libraryCommands.dispose();
    widget.model.removeListener(route);
    super.dispose();
  }
}
