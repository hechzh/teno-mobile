import 'dart:async';
import '../core/calendar_view.dart';
import 'personal_ask.dart';
import 'package:flutter/material.dart';
import '../core/model.dart';
import '../ui/widgets.dart';
import '../ui/personal_widgets.dart';
import 'personal_library.dart';
import 'personal_import.dart';
import 'recorder.dart';

Widget settingsGroup(BuildContext context, String title) => Padding(
  padding: const EdgeInsets.only(top: 24, bottom: 14),
  child: Text(title, style: TextStyle(fontSize: 13, color: subtle(context))),
);
Widget settingsEntry(
  BuildContext context,
  String title,
  IconData icon,
  VoidCallback open,
) => ListTile(
  contentPadding: EdgeInsets.zero,
  minVerticalPadding: 15,
  leading: Icon(icon, size: 23),
  title: Text(title, style: const TextStyle(fontSize: 16)),
  trailing: Icon(Icons.chevron_right, size: 20, color: subtle(context)),
  onTap: open,
);

class PersonalSettings extends StatelessWidget {
  const PersonalSettings(this.model, {super.key});
  final TenoModel model;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(horizontal: coreInset),
    children: [
      settingsGroup(context, 'Workspace'),
      settingsEntry(
        context,
        'Personalization',
        Icons.badge_outlined,
        () => push(context, PersonalAccountPage(model, profile: true)),
      ),
      settingsEntry(
        context,
        'Preferences',
        Icons.tune,
        () => push(context, PersonalPreferences(model)),
      ),
      settingsEntry(
        context,
        'Cloud processing',
        Icons.cloud_outlined,
        () => push(context, PersonalRecorderPreferences(model, cloud: true)),
      ),
      const Divider(height: 30),
      settingsGroup(context, 'Account'),
      settingsEntry(
        context,
        'Account & security',
        Icons.person_outline,
        () => push(context, PersonalAccountPage(model)),
      ),
      settingsEntry(
        context,
        'Shared links',
        Icons.link,
        () => push(context, PersonalLinksPage(model)),
      ),
      const Divider(height: 30),
      settingsGroup(context, 'General'),
      settingsEntry(
        context,
        'Notifications',
        Icons.notifications_none,
        () => push(context, PersonalAppearance(model, notifications: true)),
      ),
      settingsEntry(
        context,
        'Theme',
        Icons.light_mode_outlined,
        () => push(context, PersonalAppearance(model)),
      ),
      const Divider(height: 30),
      settingsGroup(context, 'Recorder & files'),
      settingsEntry(
        context,
        'Recorder',
        Icons.speaker_phone_outlined,
        () => push(context, PersonalRecorderPreferences(model)),
      ),
      settingsEntry(
        context,
        'Calendar',
        Icons.calendar_month_outlined,
        () => push(context, PersonalCalendarPage(model)),
      ),
      settingsEntry(
        context,
        'Storage',
        Icons.storage_outlined,
        () => push(context, PersonalStoragePage(model)),
      ),
      settingsEntry(
        context,
        'Trash',
        Icons.delete_outline,
        () =>
            push(context, PersonalListPage(model, title: 'Trash', trash: true)),
      ),
      const Divider(height: 30),
      settingsGroup(context, 'Help & support'),
      settingsEntry(
        context,
        'Help center',
        Icons.help_outline,
        () => push(context, const PersonalHelpPage()),
      ),
      const SizedBox(height: 24),
    ],
  );
}

class PersonalAccountPage extends StatelessWidget {
  const PersonalAccountPage(this.model, {super.key, this.profile = false});
  final TenoModel model;
  final bool profile;
  @override
  Widget build(BuildContext context) => CoreFrame(
    title: profile ? 'Personalization' : 'Account & security',
    child: ListView(
      padding: const EdgeInsets.all(coreInset),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline),
          title: Text(model.runtime!.session.username),
          subtitle: const Text('Teno account'),
        ),
        if (!profile) ...[
          CoreLoad(
            load: () => model.command('preferences'),
            builder: (context, data, reload) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('App lock'),
              subtitle: const Text(
                'Use your phone’s screen lock to open Teno.',
              ),
              value: data['app_lock'] == true,
              onChanged: (v) => perform(context, () async {
                await model.command('app_lock', {'enabled': v});
                reload();
              }),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => perform(context, () async {
              if (await confirm(
                context,
                'Sign out?',
                'Local files and recorder keys remain on this phone under their original account.',
              ))
                await model.signOut();
            }),
            child: const Text('Sign out'),
          ),
        ],
      ],
    ),
  );
}

class PersonalAppearance extends StatelessWidget {
  const PersonalAppearance(this.model, {super.key, this.notifications = false});
  final TenoModel model;
  final bool notifications;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) => CoreFrame(
      title: notifications ? 'Notifications' : 'Theme',
      child: ListView(
        padding: const EdgeInsets.all(coreInset),
        children: [
          if (notifications)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Processing notifications'),
              subtitle: const Text(
                'Notify me when processing finishes. Requires Android notification permission.',
              ),
              value: model.personalSettings['notifications'] != false,
              onChanged: (v) => perform(context, () async {
                await model.command('notifications', {'enabled': v});
                await model.updatePersonal({'notifications': v});
              }),
            )
          else
            RadioGroup<String>(
              groupValue: text(model.personalSettings['theme']).isEmpty
                  ? 'system'
                  : text(model.personalSettings['theme']),
              onChanged: (v) =>
                  perform(context, () => model.updatePersonal({'theme': v})),
              child: Column(
                children: [
                  for (final v in [
                    ('system', 'Follow system'),
                    ('light', 'Light'),
                    ('dark', 'Dark'),
                  ])
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.trailing,
                      value: v.$1,
                      title: Text(v.$2),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class PersonalRecorderPreferences extends StatelessWidget {
  const PersonalRecorderPreferences(
    this.model, {
    super.key,
    this.cloud = false,
  });
  final TenoModel model;
  final bool cloud;
  Future<void> configure({bool? upload, bool? wifi, bool? live}) async {
    final s = model.runtime!.session;
    await model.host.configure(
      upload ?? s.cloudUpload,
      wifi ?? s.wifiOnly,
      live ?? s.livePreview,
    );
    model.changed(await model.host.snapshot());
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) => CoreFrame(
      title: cloud ? 'Cloud processing' : 'Recorder',
      child: ListView(
        padding: const EdgeInsets.all(coreInset),
        children: [
          if (!cloud)
            settingsEntry(
              context,
              'Connect recorder',
              Icons.speaker_phone_outlined,
              () => push(context, DevicePage(model)),
            ),
          if (cloud)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cloud processing'),
              subtitle: const Text(
                'Automatically upload new recordings and imports for transcription and summaries.',
              ),
              value: model.runtime!.session.cloudUpload,
              onChanged: (v) => perform(context, () => configure(upload: v)),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Upload on Wi-Fi only'),
            value: model.runtime!.session.wifiOnly,
            onChanged: (v) => perform(context, () => configure(wifi: v)),
          ),
          if (!cloud)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Live transcript preview'),
              subtitle: const Text(
                'Preview only. The complete audio is processed after recording.',
              ),
              value: model.runtime!.session.livePreview,
              onChanged: (v) => perform(context, () => configure(live: v)),
            ),
          const SizedBox(height: 24),
          Text(
            'Complete recordings and imports stay on this phone after upload. Existing saved files are uploaded only when you request it.',
            style: TextStyle(fontSize: 13, color: subtle(context)),
          ),
        ],
      ),
    ),
  );
}

class PersonalPreferences extends StatefulWidget {
  const PersonalPreferences(this.model, {super.key, this.detail = false});
  final TenoModel model;
  final bool detail;
  @override
  State<PersonalPreferences> createState() => _PersonalPreferencesState();
}

class _PersonalPreferencesState extends State<PersonalPreferences> {
  Json settings = {};
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await widget.model.api('GET', '/api/v1/me');
      if (mounted) setState(() => settings = object(data['settings']));
    } catch (_) {}
  }

  Future<void> configure({bool? cloud, bool? wifi, bool? live}) async {
    final s = widget.model.runtime!.session;
    await widget.model.host.configure(
      cloud ?? s.cloudUpload,
      wifi ?? s.wifiOnly,
      live ?? s.livePreview,
    );
    widget.model.changed(await widget.model.host.snapshot());
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.model,
    builder: (context, _) {
      if (!widget.detail)
        return CoreFrame(
          title: 'Preferences',
          child: ListView(
            padding: const EdgeInsets.all(coreInset),
            children: [
              heading('Generation'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Transcription & summary',
                  style: TextStyle(fontSize: 16),
                ),
                subtitle: const Text(
                  'Default configurations for language, speaker labels and transcript cleanup.',
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => push(
                  context,
                  PersonalPreferences(widget.model, detail: true),
                ),
              ),
            ],
          ),
        );
      final p = widget.model.personalSettings;
      return CoreFrame(
        title: 'Transcription & summary',
        child: ListView(
          padding: const EdgeInsets.all(21),
          children: [
            heading('Generation'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Clean up transcript automatically'),
              value: p['clean_transcript'] != false,
              onChanged: (v) => perform(
                context,
                () => widget.model.updatePersonal({'clean_transcript': v}),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Separate speakers'),
              subtitle: const Text('Name speakers within each recording.'),
              value: p['speaker_labels'] != false,
              onChanged: (v) => perform(
                context,
                () => widget.model.updatePersonal({'speaker_labels': v}),
              ),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Audio language'),
              trailing: Text('Automatic', style: TextStyle(fontSize: 12)),
            ),
            DropdownButtonFormField<String>(
              initialValue: text(settings['summary_language']).startsWith('zh')
                  ? 'zh-CN'
                  : 'en-US',
              decoration: const InputDecoration(labelText: 'Summary language'),
              items: const [
                DropdownMenuItem(value: 'en-US', child: Text('English')),
                DropdownMenuItem(value: 'zh-CN', child: Text('Chinese')),
              ],
              onChanged: (v) => perform(context, () async {
                if (v == null) return;
                await widget.model.api('PATCH', '/api/v1/me', {
                  'language': 'auto',
                  'summary_language': v,
                  'timezone': settings['timezone'] ?? 'Asia/Shanghai',
                });
                await load();
              }),
            ),
          ],
        ),
      );
    },
  );
}

class PersonalLinksPage extends StatelessWidget {
  const PersonalLinksPage(this.model, {super.key});
  final TenoModel model;
  @override
  Widget build(BuildContext context) => CoreFrame(
    title: 'Shared links',
    child: CoreLoad(
      load: () async => {'items': await model.list('/api/v1/shares')},
      builder: (context, data, reload) => ListView(
        padding: const EdgeInsets.all(21),
        children: [
          if (rows(data['items']).isEmpty)
            const EmptyState(
              'No shared links',
              'Create a link from a recording or note.',
            ),
          for (final item in rows(data['items']))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(text(item['title'])),
              subtitle: Text(
                item['revoked'] == true
                    ? 'Revoked'
                    : 'Expires ${dateLabel(item['expires_at'])}',
              ),
              trailing: item['revoked'] == true
                  ? null
                  : TextButton(
                      onPressed: () => perform(context, () async {
                        if (await confirm(
                          context,
                          'Revoke this link?',
                          'Anyone using this link will lose access.',
                        )) {
                          await model.api(
                            'DELETE',
                            '/api/v1/shares/${item['id']}',
                          );
                          reload();
                        }
                      }),
                      child: const Text('Revoke'),
                    ),
            ),
        ],
      ),
    ),
  );
}

class PersonalStoragePage extends StatelessWidget {
  const PersonalStoragePage(this.model, {super.key});
  final TenoModel model;
  @override
  Widget build(BuildContext context) => CoreFrame(
    title: 'Storage',
    child: CoreLoad(
      load: () => model.command('storage'),
      builder: (context, data, reload) => ListView(
        padding: const EdgeInsets.all(21),
        children: [
          heading('On this phone'),
          Text(
            '${((data['local_bytes'] as num? ?? 0) / 1048576).toStringAsFixed(1)} MiB · ${model.drafts.length} files',
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Manage local files'),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => push(context, PersonalLocalList(model)),
          ),
          heading('Cached previews and exports'),
          Text(
            '${((data['cache_bytes'] as num? ?? 0) / 1048576).toStringAsFixed(1)} MiB',
          ),
          OutlinedButton(
            onPressed: () => perform(context, () async {
              if (await confirm(
                context,
                'Clear cached files?',
                'Original local recordings, device keys and cloud files stay available.',
              )) {
                await model.command('clear_cache');
                reload();
              }
            }),
            child: const Text('Clear cache'),
          ),
        ],
      ),
    ),
  );
}

class PersonalCalendarPage extends StatefulWidget {
  const PersonalCalendarPage(this.model, {super.key, this.select = false});
  final TenoModel model;
  final bool select;
  @override
  State<PersonalCalendarPage> createState() => _PersonalCalendarPageState();
}

class _PersonalCalendarPageState extends State<PersonalCalendarPage> {
  DateTime selected = calendarDay(DateTime.now());
  List<Json> events = [];
  bool loading = true;
  String error = '';
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    if (mounted)
      setState(() {
        loading = true;
        error = '';
      });
    try {
      final values = <Json>[], seen = <String>{};
      while (true) {
        final page = await widget.model.list(
          '/api/v1/events?limit=200&offset=${values.length}',
        );
        final fresh = page.where((v) => seen.add(text(v['id']))).toList();
        values.addAll(fresh);
        if (page.length < 200 || fresh.isEmpty) break;
      }
      if (mounted) setState(() => events = values);
    } catch (e) {
      if (mounted) setState(() => error = TenoModel.friendly(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> add() async {
    final title = await inputDialog(context, 'Event title');
    if (title == null || !mounted) return;
    final date = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    final start = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    await widget.model.api('POST', '/api/v1/events', {
      'title': title,
      'starts_at': start.toUtc().toIso8601String(),
      'ends_at': start.add(const Duration(hours: 1)).toUtc().toIso8601String(),
      'timezone': 'UTC',
    });
    if (mounted) setState(() => selected = calendarDay(start));
    await load();
  }

  Future<void> action(String value) => perform(context, () async {
    if (value == 'add') {
      await add();
      return;
    }
    if (value == 'import') {
      await showPersonalImport(context, widget.model);
      await load();
      return;
    }
    final data = await widget.model.command('calendar');
    await widget.model.api('POST', '/api/v1/personal/calendar/sync', data);
    await load();
  });
  Future<void> chooseMonth() async {
    final value = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Choose date',
    );
    if (value != null && mounted) setState(() => selected = calendarDay(value));
  }

  Future<void> openEvent(Json event) async {
    if (widget.select) {
      Navigator.pop(context, text(event['id']));
      return;
    }
    final data = object(event['data']);
    final choice = await showCoreSheet<String>(
      context,
      Builder(
        builder: (sheet) => CoreFrame(
          title: 'Event',
          sheet: true,
          child: ListView(
            padding: const EdgeInsets.all(coreInset),
            children: [
              Text(
                text(data['title']),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${coreDate(data['starts_at'], time: true)} – ${coreDate(data['ends_at'], time: true)}',
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit title'),
                onTap: () => Navigator.pop(sheet, 'edit'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete event'),
                onTap: () => Navigator.pop(sheet, 'delete'),
              ),
            ],
          ),
        ),
      ),
      height: 390,
    );
    if (choice == null || !mounted) return;
    await perform(context, () async {
      if (choice == 'delete') {
        if (await confirm(
          context,
          'Delete event?',
          'This removes the event from Teno. Your phone calendar is unchanged.',
        ))
          await widget.model.api('DELETE', '/api/v1/events/${event['id']}');
      } else {
        final title = await inputDialog(
          context,
          'Event title',
          initial: text(data['title']),
        );
        if (title != null)
          await widget.model.api('PATCH', '/api/v1/events/${event['id']}', {
            'title': title,
          });
      }
      await load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final week = calendarWeek(selected);
    final agenda = calendarAgenda(
      events,
      week,
      DateTime(selected.year, selected.month + 4, 1),
    );
    final colors = Theme.of(context).colorScheme;
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        leading: Padding(
          padding: const EdgeInsets.all(12),
          child: CoreAction(
            Icons.arrow_back_ios_new_rounded,
            'Back',
            () => Navigator.pop(context),
          ),
        ),
        titleSpacing: 0,
        centerTitle: false,
        title: InkWell(
          onTap: chooseMonth,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '${months[selected.month - 1]} ${selected.year}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, size: 20),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                setState(() => selected = calendarDay(DateTime.now())),
            child: const Text('Today'),
          ),
          PopupMenuButton<String>(
            tooltip: 'Calendar actions',
            onSelected: action,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'connect',
                child: Text('Connect phone calendar'),
              ),
              PopupMenuItem(
                value: 'import',
                child: Text('Import calendar file'),
              ),
              PopupMenuItem(value: 'add', child: Text('Add event')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            GestureDetector(
              onHorizontalDragEnd: (d) {
                if (d.primaryVelocity == null || d.primaryVelocity!.abs() < 50)
                  return;
                setState(
                  () => selected = DateTime(
                    selected.year,
                    selected.month,
                    selected.day + (d.primaryVelocity! < 0 ? 7 : -7),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(
                            () => selected = DateTime(
                              week.year,
                              week.month,
                              week.day + i,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                weekdays[i][0],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: subtle(context),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                constraints: const BoxConstraints(
                                  minWidth: 30,
                                  minHeight: 30,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      DateTime(
                                            week.year,
                                            week.month,
                                            week.day + i,
                                          ) ==
                                          selected
                                      ? colors.onSurface
                                      : null,
                                ),
                                child: Text(
                                  '${DateTime(week.year, week.month, week.day + i).day}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color:
                                        DateTime(
                                              week.year,
                                              week.month,
                                              week.day + i,
                                            ) ==
                                            selected
                                        ? colors.surface
                                        : colors.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            if (loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: RefreshIndicator(
                onRefresh: load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 20),
                  children: [
                    if (error.isNotEmpty) ErrorNotice(error, retry: load),
                    if (agenda.isEmpty && !loading && error.isEmpty)
                      const EmptyState(
                        'No upcoming events',
                        'Use the menu to connect your calendar or add an event.',
                      ),
                    for (final group in agenda.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 44,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Column(
                                  children: [
                                    Text(
                                      weekdays[group.key.weekday % 7],
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: subtle(context),
                                      ),
                                    ),
                                    Text(
                                      '${group.key.day}',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (group.key.month != selected.month)
                                      Text(
                                        months[group.key.month - 1],
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: subtle(context),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                children: [
                                  for (final event in group.value)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: InkWell(
                                        onTap: () => openEvent(event),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: coreBlue.withValues(
                                              alpha: .09,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: IntrinsicHeight(
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Container(
                                                  width: 2,
                                                  color: coreBlue,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        text(
                                                          object(
                                                            event['data'],
                                                          )['title'],
                                                        ),
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: coreBlue,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        '${event['continues_before'] == true ? 'Continued' : calendarClock(event['local_start'] as DateTime)} – ${event['continues_after'] == true ? 'continues' : calendarClock(event['local_end'] as DateTime)}',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: coreBlue,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.select
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: AskBar(
                  () => push(context, PersonalChatPage(widget.model)),
                ),
              ),
            ),
    );
  }
}

class PersonalHelpPage extends StatelessWidget {
  const PersonalHelpPage({super.key});
  @override
  Widget build(BuildContext context) => CoreFrame(
    title: 'Help center',
    child: ListView(
      padding: const EdgeInsets.all(21),
      children: [
        heading('Import files'),
        const Text(
          'Home → + → Import files. Choose From Files or From Photos. In another app, tap Share → Teno.',
        ),
        heading('Automatic processing'),
        const Text(
          'Cloud processing starts on for accounts without a saved preference. An existing choice to turn it off is kept. Enable it in Settings → Cloud processing.',
        ),
        heading('Your recorder'),
        const Text(
          'Connect your recorder and keep its original device key. Reconnecting does not start a recording. A Bluetooth disconnect does not mean the recorder has stopped.',
        ),
        heading('Local copies'),
        const Text(
          'Complete recordings and imports remain on this phone after upload. Keep the app installed to retain these local copies.',
        ),
        heading('Import limits'),
        const Text(
          'Audio and video: 120 minutes / 250 MiB. Images: 20 MB. Documents: 15 MB. Text: 2 MB. Calendar files: 1 MiB. Use unencrypted documents.',
        ),
        heading('Processing and notifications'),
        const Text(
          'Android may delay background uploads and completion notifications. Reopen Teno to resume app work. Live text is a preview; final results use the complete recording.',
        ),
      ],
    ),
  );
}
