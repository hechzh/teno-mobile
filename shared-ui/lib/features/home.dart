import 'dart:async';
import 'package:flutter/material.dart';
import '../core/model.dart';
import '../ui/widgets.dart';
import 'recorder.dart';
import 'library.dart';
import 'detail.dart';
import 'ask.dart';
import 'settings.dart';

class HomePage extends StatefulWidget {
  const HomePage(this.model, {super.key});
  final TenoModel model;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String section = 'Home';
  String lastRoute = '';
  TenoModel get model => widget.model;
  @override
  void initState() {
    super.initState();
    model.addListener(routeEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) => routeEvent());
  }

  void routeEvent() {
    final route = model.runtime?.openRoute ?? '';
    if (route.isEmpty || route == lastRoute || !mounted) return;
    lastRoute = route;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (route.startsWith('recording:')) {
        unawaited(push(context, DetailPage(model, route.substring(10))));
      } else if (route.startsWith('capture:')) {
        unawaited(showRecorder(context, model));
      } else if (route.startsWith('device:')) {
        unawaited(push(context, DevicePage(model)));
      }
    });
  }

  @override
  void dispose() {
    model.removeListener(routeEvent);
    super.dispose();
  }

  Future<void> createMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MenuRow(Icons.mic_none_outlined, 'Start recording', () {
                Navigator.pop(sheet);
                unawaited(push(context, DevicePage(model)));
              }, subtitle: 'Record with your JWD device'),
              MenuRow(Icons.file_upload_outlined, 'Import files', () {
                Navigator.pop(sheet);
                unawaited(
                  perform(context, () async {
                    final id = await model.host.importAudio();
                    if (id != null && mounted)
                      await push(context, LocalPage(model, id));
                  }),
                );
              }),
              MenuRow(Icons.chat_bubble_outline, 'New chat', () {
                Navigator.pop(sheet);
                unawaited(push(context, ChatPage(model)));
              }),
              TextButton(
                onPressed: () {
                  Navigator.pop(sheet);
                  unawaited(startPhone(context, model));
                },
                child: const Text('Record with phone'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) {
      final state = model.runtime!;
      final top = section == 'Home';
      return Scaffold(
        appBar: AppBar(
          leadingWidth: 70,
          leading: Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
              child: CircleAction(
                Icons.menu_rounded,
                'Navigation',
                () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ),
          title: top
              ? null
              : Text(
                  section,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          actions: [
            if (top)
              OutlinedButton.icon(
                onPressed: () => model.capturing
                    ? showRecorder(context, model)
                    : push(context, DevicePage(model)),
                icon: Icon(
                  Icons.speaker_phone_outlined,
                  size: 20,
                  color: state.device.authorized
                      ? const Color(0xFF669B75)
                      : ink,
                ),
                label: const Icon(Icons.keyboard_arrow_down, size: 18),
              ),
            const SizedBox(width: 8),
            if (['Home', 'Library'].contains(section))
              CircleAction(Icons.add, 'Create', createMenu),
            if (section == 'Ask Teno')
              CircleAction(
                Icons.add_comment_outlined,
                'New chat',
                () => push(context, ChatPage(model)),
              ),
            const SizedBox(width: 16),
          ],
        ),
        drawer: Drawer(
          backgroundColor: canvas,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'Teno',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.session.username,
                    style: const TextStyle(color: muted),
                  ),
                  const SizedBox(height: 35),
                  for (final item in <(String, IconData)>[
                    ('Home', Icons.home_outlined),
                    ('Library', Icons.folder_outlined),
                    ('Ask Teno', Icons.chat_bubble_outline),
                    ('Tools', Icons.auto_awesome_outlined),
                    ('Settings', Icons.settings_outlined),
                  ])
                    MenuRow(
                      item.$2,
                      item.$1,
                      () {
                        Navigator.pop(context);
                        setState(() => section = item.$1);
                      },
                      trailing: section == item.$1
                          ? const Icon(Icons.check, size: 18)
                          : const SizedBox.shrink(),
                    ),
                  const Spacer(),
                  MenuRow(Icons.help_outline, 'Help & support', () {
                    Navigator.pop(context);
                    unawaited(push(context, const HelpPage()));
                  }),
                ],
              ),
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: switch (section) {
            'Library' => LibraryBody(model),
            'Ask Teno' => AskHistoryBody(model),
            'Tools' => TemplatesBody(model),
            'Settings' => SettingsBody(model),
            _ => homeBody(),
          },
        ),
        bottomNavigationBar: ['Home', 'Library'].contains(section)
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () => push(context, ChatPage(model)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 17,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: line),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome_outlined, size: 18),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Ask me anything about your recordings',
                              style: TextStyle(fontSize: 13, color: muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : null,
      );
    },
  );

  Widget homeBody() {
    final local = model.drafts
        .where((d) => text(d['recording_id']).isEmpty)
        .toList();
    return RefreshIndicator(
      onRefresh: model.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(23),
        children: [
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Meeting notes',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                onPressed: () => push(context, SearchPage(model)),
                tooltip: 'Search',
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          if (model.capturing)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: OutlinedButton.icon(
                onPressed: () => showRecorder(context, model),
                icon: const Icon(Icons.graphic_eq),
                label: Text(
                  'Return to recording · ' +
                      duration(model.runtime!.capture.elapsedMs),
                ),
              ),
            ),
          if (model.loading) const LinearProgressIndicator(minHeight: 2),
          if (model.error.isNotEmpty)
            ErrorNotice(model.error, retry: () => unawaited(model.refresh())),
          if (local.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'On this phone',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            for (final record in local)
              RecordTile(
                record,
                () => push(context, LocalPage(model, text(record['id']))),
                local: true,
              ),
          ],
          if (model.recordings.isEmpty &&
              local.isEmpty &&
              !model.loading &&
              model.error.isEmpty)
            EmptyState(
              'Your recordings start here',
              'Connect your recorder to capture your next conversation.',
              action: FilledButton(
                onPressed: () => push(context, DevicePage(model)),
                child: const Text('Connect recorder'),
              ),
            ),
          for (var i = 0; i < model.recordings.length; i++) ...[
            if (i == 0 ||
                dateLabel(model.recordings[i]['created_at']) !=
                    dateLabel(model.recordings[i - 1]['created_at']))
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 3),
                child: Text(
                  dateLabel(model.recordings[i]['created_at']),
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ),
            RecordTile(
              model.recordings[i],
              () => push(
                context,
                DetailPage(model, text(model.recordings[i]['id'])),
              ),
            ),
          ],
          if (model.moreAvailable && model.recordings.isNotEmpty)
            TextButton(
              onPressed: model.loading
                  ? null
                  : () => model.refresh(append: true),
              child: const Text('Load more'),
            ),
        ],
      ),
    );
  }
}
