import 'dart:async';
import 'package:flutter/material.dart';
import '../core/model.dart';
import '../l10n/ui_strings.dart';
import '../ui/widgets.dart';
import '../ui/personal_widgets.dart';
import 'routes/recorder.dart';
import 'personal_actions.dart';
import 'routes/personal_library.dart';
import 'routes/personal_import.dart';
import 'routes/personal_notes.dart';
import 'routes/personal_ask.dart';
import 'routes/personal_settings.dart';
import 'routes/personal_recording.dart';
import 'routes/personal_mcp.dart';

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
  List<Json> workspaceFolders = [];
  List<Json> spaces = [];
  bool get workspacesSupported =>
      spaces.any((entry) => entry['id'] == 'personal');
  String? get workspaceFilter =>
      workspacesSupported ? widget.model.workspaceId : null;
  bool loading = true;
  int? selectedCount;
  int commandSequence = 0, loadSequence = 0;
  final libraryCommands = ValueNotifier<String>('');
  final visited = <String>{'Home'};
  bool wasOnline = true;
  String? lastDraftsJson;
  Set<String> uploadedDrafts = {};
  Timer? timer;

  Set<String> uploadReceipts() => {
    for (final draft in widget.model.drafts)
      if (text(draft['recording_id']).isNotEmpty ||
          text(draft['file_id']).isNotEmpty)
        text(draft['id']),
  };

  @override
  void initState() {
    super.initState();
    section = widget.initialSection;
    visited.add(section);
    wasOnline = widget.model.runtime?.networkAvailable ?? true;
    lastDraftsJson = widget.model.runtime?.draftsJson;
    uploadedDrafts = uploadReceipts();
    widget.model.addListener(runtimeChanged);
    unawaited(load());
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (section == 'Home') unawaited(load(silent: true));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => route());
  }

  void runtimeChanged() {
    route();
    final state = widget.model.runtime;
    if (state == null) return;
    var refresh = state.networkAvailable && !wasOnline;
    wasOnline = state.networkAvailable;
    if (state.draftsJson != lastDraftsJson) {
      lastDraftsJson = state.draftsJson;
      final receipts = uploadReceipts();
      refresh = refresh || receipts.difference(uploadedDrafts).isNotEmpty;
      uploadedDrafts = receipts;
    }
    if (refresh && wasOnline && section == 'Home') {
      unawaited(load(silent: true));
    }
  }

  void route() {
    final value = widget.model.runtime?.openRoute ?? '';
    if (value.isEmpty || value == lastRoute || !mounted) return;
    lastRoute = value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (value.startsWith('mcp:')) {
        final query =
            Uri.tryParse(value.substring(4))?.queryParameters ??
            <String, String>{};
        final id = query['connection'];
        if (id != null && RegExp(r'^[0-9a-f-]{36}$').hasMatch(id)) {
          unawaited(
            push(
              context,
              McpConnectionPage(
                widget.model,
                id,
                sourceKey: query['source'],
                snapshotId: query['snapshot'],
                chunk: int.tryParse(query['chunk'] ?? '') ?? 0,
              ),
            ),
          );
        }
      } else if (value.startsWith('recording:')) {
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
    final model = widget.model;
    final stamp = ++loadSequence, scope = model.runtime?.session.scope;
    bool current() =>
        mounted &&
        stamp == loadSequence &&
        scope == model.runtime?.session.scope;
    if (!silent && mounted) setState(() => loading = true);
    try {
      await model.restoreWorkspace();
      if (!current()) return;
      if (model.runtime?.networkAvailable == false) {
        setState(() {
          error = '';
          loading = false;
        });
        return;
      }
      List<Json> available;
      try {
        available = await model.list('/api/v1/personal/workspaces');
      } on Exception catch (e) {
        if (!e.toString().contains('NOT_FOUND') &&
            !e.toString().contains('404'))
          rethrow;
        available = [];
      }
      if (!current()) return;
      final supported = available.any((entry) => entry['id'] == 'personal');
      if (supported &&
          !available.any((entry) => entry['id'] == model.workspaceId)) {
        await model.selectWorkspace('personal');
        if (!current()) return;
      }
      final id = model.workspaceId;
      final scoped = supported
          ? '&workspace_id=' + Uri.encodeQueryComponent(id)
          : '';
      final values = await Future.wait([
        model.list(
          '/api/v1/library/items?sort=' +
              sort +
              '&limit=100&include_stats=' +
              (model.capabilities['library_stats'] == 1).toString() +
              (supported ? '&type=recent_files' : '') +
              scoped,
        ),
        model.list(
          '/api/v1/library/items?type=folder&sort=name&ascending=true'
                  '&limit=100&include_stats=true&folder_id=' +
              Uri.encodeQueryComponent(model.workspaceFolder ?? '') +
              scoped,
        ),
      ]);
      if (!current() || id != model.workspaceId) return;
      setState(() {
        spaces = available;
        items = values[0];
        workspaceFolders = values[1];
        error = '';
        loading = false;
      });
    } catch (e) {
      if (current()) {
        setState(() {
          error = model.runtime?.networkAvailable == false
              ? ''
              : TenoModel.friendly(e);
          loading = false;
        });
      }
    }
  }

  Future<void> chooseWorkspace(String id) async {
    if (id == '__add__') {
      final name = await inputDialog(context, 'New workspace');
      if (!mounted || name == null || name.trim().isEmpty) return;
      final scope = widget.model.runtime?.session.scope;
      final item = await widget.model.api(
        'POST',
        '/api/v1/personal/workspaces',
        {'title': name.trim(), 'client_id': requestId()},
      );
      if (!mounted || scope != widget.model.runtime?.session.scope) return;
      id = text(item['id']);
      if (id.isEmpty) return;
      spaces = [...spaces, item];
    }
    if (!await widget.model.selectWorkspace(id) || !mounted) return;
    setState(() {
      items = [];
      workspaceFolders = [];
      selectedCount = null;
    });
    await load();
  }

  Widget workspacePicker() {
    final id = widget.model.workspaceId;
    final title = spaces
        .where((entry) => entry['id'] == id)
        .map((entry) => text(entry['title']))
        .firstOrNull;
    final label = id == 'personal' || title == null
        ? ui(context, 'Personal workspace')
        : title;
    return PopupMenuButton<String>(
      enabled: workspacesSupported,
      tooltip: ui(context, 'Switch workspace'),
      onSelected: (value) => perform(context, () => chooseWorkspace(value)),
      itemBuilder: (_) => [
        for (final space in spaces)
          CheckedPopupMenuItem(
            value: text(space['id']),
            checked: space['id'] == id,
            child: space['id'] == 'personal'
                ? const UiText('Personal workspace')
                : Text(text(space['title'])),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: '__add__', child: UiText('New workspace')),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
          ),
          if (workspacesSupported)
            const Icon(Icons.keyboard_arrow_down, size: 18),
        ],
      ),
    );
  }

  Future<void> newFolder() async {
    final title = await inputDialog(context, 'New folder');
    if (!mounted || title == null || title.trim().isEmpty) return;
    final folder = widget.model.workspaceFolder;
    await widget.model.api('POST', '/api/v1/folders', {
      'title': title.trim(),
      if (folder != null) 'parent_id': folder,
    });
    await load();
  }

  void navigate(String value) => setState(() {
    section = value;
    visited.add(value);
    selectedCount = null;
  });
  Future<void> search() => push(
    context,
    PersonalSearchPage(widget.model, workspaceId: workspaceFilter),
  );
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
              toolbarHeight: section == 'Home' ? 74 : 60,
              title: section == 'Home'
                  ? workspacePicker()
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
                  if (!widget.model.webExperience)
                    CoreAction(Icons.mic_none, 'Start recording', record),
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
                    key: ValueKey(workspaceFilter),
                    root: true,
                    workspaceId: workspaceFilter,
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

  Widget localDraftTile(Json draft) {
    final model = widget.model;
    final offlineRecorder =
        model.runtime?.networkAvailable == false &&
        draft['source'] == 'jwd_ble';
    return CoreTile(
      {
        ...draft,
        'type': draft['kind'] == 'file' ? 'file' : 'recording',
        if (offlineRecorder)
          'processing': {
            'stage': 'saved',
            'preserved': {'local_file': true},
            'waiting_reason':
                object(draft['processing'])['waiting_reason'] ==
                    'cloud_disabled'
                ? 'cloud_disabled'
                : 'network',
          },
      },
      offlineRecorder
          ? null
          : () => push(context, PersonalLocalPage(model, text(draft['id']))),
    );
  }

  Widget home() {
    final model = widget.model;
    final recent = items
        .where(
          (item) =>
              item['type'] != 'folder' && text(item['recording_id']).isEmpty,
        )
        .take(10)
        .toList();
    final local = model.drafts
        .where(
          (draft) =>
              text(draft['recording_id']).isEmpty &&
              text(draft['file_id']).isEmpty &&
              text(draft['folder_id']) == (model.workspaceFolder ?? ''),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(coreInset, 0, coreInset, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (loading) const LinearProgressIndicator(minHeight: 2),
          if (error.isNotEmpty) ErrorNotice(error, retry: load),
          Row(
            children: [
              Expanded(child: heading('Folders')),
              CoreAction(
                Icons.create_new_folder_outlined,
                'New folder',
                () => perform(context, newFolder),
              ),
              CoreAction(
                Icons.file_upload_outlined,
                'Import files',
                importFiles,
              ),
              if (!model.webExperience)
                CoreAction(
                  Icons.calendar_month_outlined,
                  'Calendar',
                  () => push(context, PersonalCalendarPage(model)),
                ),
            ],
          ),
          if (workspaceFolders.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final folder in workspaceFolders.take(6))
                  OutlinedButton.icon(
                    onPressed: () async {
                      await openPersonalItem(
                        context,
                        model,
                        folder,
                        null,
                        workspaceFilter,
                      );
                      if (mounted) await load();
                    },
                    icon: const Icon(Icons.folder_outlined, size: 18),
                    label: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          text(folder['title']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          context.strings.itemCount(
                            (folder['child_count'] as num? ?? 0).toInt(),
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            color: subtle(context),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: heading('Recent files')),
              TextButton(
                onPressed: () => navigate('Library'),
                child: const UiText('View all'),
              ),
            ],
          ),
          if (!model.webExperience && model.capturing)
            TextButton.icon(
              onPressed: record,
              icon: const Icon(Icons.graphic_eq),
              label: Text(
                ui(context, 'Recording') +
                    ' · ' +
                    duration(model.runtime!.capture.elapsedMs),
              ),
            ),
          for (final draft in local) localDraftTile(draft),
          for (final item in recent)
            CoreTile(item, () async {
              await openPersonalItem(context, model, item);
              if (mounted) await load();
            }, showFolder: text(item['folder_title']).isNotEmpty),
          if (!loading && recent.isEmpty && local.isEmpty && error.isEmpty)
            EmptyState(
              'No files in this workspace',
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
    widget.model.removeListener(runtimeChanged);
    super.dispose();
  }
}
