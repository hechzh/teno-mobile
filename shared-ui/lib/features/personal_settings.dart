import 'package:flutter/material.dart';
import '../core/model.dart';
import '../ui/widgets.dart';
import '../ui/personal_widgets.dart';
import 'personal_library.dart';
import 'personal_import.dart';
import 'recorder.dart';

class PersonalSettings extends StatelessWidget {
  const PersonalSettings(this.model, {super.key});
  final TenoModel model;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(21),
    children: [
      heading('Personalization'),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.person_outline),
        title: Text(model.runtime!.session.username),
        subtitle: const Text('Teno account'),
      ),
      heading('Workspace'),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.tune),
        title: const Text('Preferences'),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => push(context, PersonalPreferences(model)),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.speaker_phone_outlined),
        title: const Text('Recorder'),
        onTap: () => push(context, DevicePage(model)),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.calendar_month_outlined),
        title: const Text('Calendar'),
        onTap: () => push(context, PersonalCalendarPage(model)),
      ),
      heading('Account & security'),
      CoreLoad(
        load: () => model.command('preferences'),
        builder: (context, data, reload) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('App lock'),
          subtitle: const Text('Use your phone’s screen lock to open Teno.'),
          value: data['app_lock'] == true,
          onChanged: (v) => perform(context, () async {
            await model.command('app_lock', {'enabled': v});
            reload();
          }),
        ),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.link),
        title: const Text('Shared links'),
        onTap: () => push(context, PersonalLinksPage(model)),
      ),
      heading('General'),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.storage_outlined),
        title: const Text('Storage'),
        onTap: () => push(context, PersonalStoragePage(model)),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.delete_outline),
        title: const Text('Trash'),
        onTap: () =>
            push(context, PersonalListPage(model, title: 'Trash', trash: true)),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.help_outline),
        title: const Text('Help center'),
        onTap: () => push(context, const PersonalHelpPage()),
      ),
      const ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('About Teno'),
        subtitle: Text('0.6.0 · Internal testing'),
      ),
      const SizedBox(height: 16),
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
  );
}

class PersonalPreferences extends StatefulWidget {
  const PersonalPreferences(this.model, {super.key});
  final TenoModel model;
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
      final s = widget.model.runtime!.session,
          p = widget.model.personalSettings;
      return CoreFrame(
        title: 'Preferences',
        child: ListView(
          padding: const EdgeInsets.all(21),
          children: [
            heading('Generation'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cloud processing'),
              subtitle: const Text(
                'Automatically upload new recordings and imports for transcription and summaries.',
              ),
              value: s.cloudUpload,
              onChanged: (v) => perform(context, () => configure(cloud: v)),
            ),
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
            heading('Appearance'),
            DropdownButtonFormField<String>(
              initialValue: text(p['theme']).isEmpty
                  ? 'system'
                  : text(p['theme']),
              decoration: const InputDecoration(labelText: 'Theme'),
              items: const [
                DropdownMenuItem(value: 'system', child: Text('System')),
                DropdownMenuItem(value: 'light', child: Text('Light')),
                DropdownMenuItem(value: 'dark', child: Text('Dark')),
              ],
              onChanged: (v) => perform(
                context,
                () => widget.model.updatePersonal({'theme': v}),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Notifications'),
              subtitle: const Text('Notify me when processing finishes. Requires Android notification permission.'),
              value: p['notifications'] != false,
              onChanged: (v) => perform(context, () async {
                await widget.model.command('notifications', {'enabled': v});
                await widget.model.updatePersonal({'notifications': v});
              }),
            ),
            heading('Upload & recording'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Upload on Wi-Fi only'),
              value: s.wifiOnly,
              onChanged: (v) => perform(context, () => configure(wifi: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Live transcript preview'),
              subtitle: const Text(
                'Preview only. The complete audio is processed after recording.',
              ),
              value: s.livePreview,
              onChanged: (v) => perform(context, () => configure(live: v)),
            ),
            heading('Local storage'),
            const Text(
              'Complete recordings and imports stay on this phone after upload. Existing saved files are uploaded only when you request it.',
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
  int version = 0;
  Future<void> add() async {
    final title = await inputDialog(context, 'Event title');
    if (title == null || !mounted) return;
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
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
    if (mounted) setState(() => version++);
  }

  @override
  Widget build(BuildContext context) => CoreFrame(
    title: widget.select ? 'Link calendar event' : 'Calendar',
    actions: [
      CircleAction(Icons.add, 'Add event', () => perform(context, add)),
    ],
    child: CoreLoad(
      key: ValueKey(version),
      load: () async => {
        'items': await widget.model.list('/api/v1/events?limit=200'),
      },
      builder: (context, data, reload) {
        final events = rows(data['items'])
          ..sort(
            (a, b) => text(
              object(a['data'])['starts_at'],
            ).compareTo(text(object(b['data'])['starts_at'])),
          );
        return ListView(
          padding: const EdgeInsets.all(21),
          children: [
            OutlinedButton.icon(
              onPressed: () => perform(context, () async {
                final values = await widget.model.command('calendar');
                await widget.model.api(
                  'POST',
                  '/api/v1/personal/calendar/sync',
                  values,
                );
                reload();
              }),
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Connect phone calendar'),
            ),
            TextButton.icon(
              onPressed: () => push(context, PersonalImportPage(widget.model)),
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Import calendar file'),
            ),
            if (events.isEmpty)
              const EmptyState(
                'No upcoming events',
                'Connect your phone calendar or add an event.',
              ),
            for (final event in events)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(text(object(event['data'])['title'])),
                subtitle: Text(
                  text(
                    object(event['data'])['starts_at'],
                  ).replaceFirst('T', ' '),
                ),
                onTap: widget.select
                    ? () => Navigator.pop(context, text(event['id']))
                    : () => showDialog<void>(
                        context: context,
                        builder: (dialog) => AlertDialog(
                          title: Text(text(object(event['data'])['title'])),
                          content: Text(
                            text(
                              object(event['data'])['starts_at'],
                            ).replaceFirst('T', ' '),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialog),
                              child: const Text('Done'),
                            ),
                          ],
                        ),
                      ),
                trailing: widget.select
                    ? const Icon(Icons.chevron_right, size: 18)
                    : PopupMenuButton<String>(
                        onSelected: (v) => perform(context, () async {
                          if (v == 'delete') {
                            if (await confirm(
                              context,
                              'Delete event?',
                              'This removes the event from Teno. Your phone calendar is unchanged.',
                            ))
                              await widget.model.api(
                                'DELETE',
                                '/api/v1/events/${event['id']}',
                              );
                          } else {
                            final title = await inputDialog(
                              context,
                              'Event title',
                              initial: text(object(event['data'])['title']),
                            );
                            if (title != null)
                              await widget.model.api(
                                'PATCH',
                                '/api/v1/events/${event['id']}',
                                {'title': title},
                              );
                          }
                          reload();
                        }),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit title'),
                          ),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
              ),
          ],
        );
      },
    ),
  );
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
          'Cloud processing starts on for accounts without a saved preference. An existing choice to turn it off is kept. Enable it in Settings → Preferences.',
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
