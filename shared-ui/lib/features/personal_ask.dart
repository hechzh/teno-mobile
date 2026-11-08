import 'dart:async';
import 'package:flutter/material.dart';
import '../core/model.dart';
import '../ui/widgets.dart';
import '../ui/personal_widgets.dart';
import 'personal_actions.dart';
import 'personal_notes.dart';

class PersonalChatHistory extends StatelessWidget {
  const PersonalChatHistory(this.model, {super.key});
  final TenoModel model;
  @override
  Widget build(BuildContext context) => CoreLoad(
    load: () async => {'items': await model.list('/api/v1/chats?limit=200')},
    builder: (context, data, reload) => ListView(
      padding: const EdgeInsets.all(21),
      children: [
        FilledButton.icon(
          onPressed: () async {
            await push(context, PersonalChatPage(model));
            reload();
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New chat'),
        ),
        heading('Recent chats'),
        if (rows(data['items']).isEmpty)
          const EmptyState(
            'Ask Teno',
            'Start a conversation about your files.',
          ),
        for (final chat in rows(data['items']))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.chat_bubble_outline, size: 21),
            title: Text(text(object(chat['data'])['title'])),
            subtitle: Text(dateLabel(chat['created_at'])),
            onTap: () async {
              await push(
                context,
                PersonalChatPage(model, chatId: text(chat['id'])),
              );
              reload();
            },
          ),
      ],
    ),
  );
}

class PersonalContextPicker extends StatefulWidget {
  const PersonalContextPicker(this.model, this.initial, {super.key});
  final TenoModel model;
  final List<Json> initial;
  @override
  State<PersonalContextPicker> createState() => _PersonalContextPickerState();
}

class _PersonalContextPickerState extends State<PersonalContextPicker> {
  late List<Json> selected = [...widget.initial];
  String query = '';
  bool contains(Json item) =>
      selected.any((s) => s['type'] == item['type'] && s['id'] == item['id']);
  Future<Json> allContexts() async {
    final values = <Json>[];
    while (true) {
      final data = await widget.model.api(
        'GET',
        '/api/v1/library/items?limit=100&offset=${values.length}',
      );
      final page = rows(data['items']);
      values.addAll(page);
      if (page.isEmpty ||
          values.length >= (data['total'] as num? ?? values.length))
        break;
    }
    return {'items': values};
  }

  @override
  Widget build(BuildContext context) => CoreFrame(
    title: 'Add context',
    bottom: FilledButton(
      onPressed: selected.isEmpty
          ? null
          : () => Navigator.pop(context, selected),
      child: Text('Use ${selected.length} sources'),
    ),
    child: CoreLoad(
      load: allContexts,
      builder: (context, data, reload) => ListView(
        padding: const EdgeInsets.all(21),
        children: [
          const Text('Select recordings, notes, documents or folders.'),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Find a file',
            ),
          ),
          for (final item in rows(data['items']).where(
            (i) => text(i['title']).toLowerCase().contains(query.toLowerCase()),
          ))
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                text(item['title']),
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: Text(text(item['type'])),
              value: contains(item),
              onChanged: (v) => setState(() {
                if (v == true) {
                  if (selected.length >= 30) return;
                  selected.add({'type': item['type'], 'id': item['id']});
                } else {
                  selected.removeWhere(
                    (s) => s['type'] == item['type'] && s['id'] == item['id'],
                  );
                }
              }),
            ),
        ],
      ),
    ),
  );
}

class PersonalChatPage extends StatefulWidget {
  const PersonalChatPage(
    this.model, {
    super.key,
    this.chatId,
    this.initial = const [],
  });
  final TenoModel model;
  final String? chatId;
  final List<Json> initial;
  @override
  State<PersonalChatPage> createState() => _PersonalChatPageState();
}

class _PersonalChatPageState extends State<PersonalChatPage> {
  final input = TextEditingController(), scroll = ScrollController();
  late String chatId = widget.chatId ?? '';
  late List<Json> selected = [...widget.initial];
  List<Json> messages = [];
  String error = '', pendingQuestion = '';
  Json job = {};
  Timer? timer;
  bool sending = false, dictating = false;
  @override
  void initState() {
    super.initState();
    input.addListener(inputChanged);
    if (chatId.isNotEmpty) unawaited(load());
  }

  void inputChanged() {
    if (mounted) setState(() {});
  }

  Future<void> load() async {
    try {
      final values = await Future.wait([
        widget.model.api('GET', '/api/v1/chats/$chatId'),
        widget.model.api('GET', '/api/v1/chats/$chatId/messages'),
      ]);
      if (!mounted) return;
      final data = object(values[0]['data']);
      setState(() {
        messages = rows(values[1]['items']);
        selected = rows(data['contexts']);
        if (selected.isEmpty)
          selected = [
            for (final id in data['recording_ids'] as List? ?? [])
              {'type': 'recording', 'id': text(id)},
          ];
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients)
          scroll.jumpTo(scroll.position.maxScrollExtent);
      });
    } catch (e) {
      if (mounted) setState(() => error = TenoModel.friendly(e));
    }
  }

  Future<void> choose() async {
    final value = await push<List<Json>>(
      context,
      PersonalContextPicker(widget.model, selected),
    );
    if (value != null && mounted) setState(() => selected = value);
  }

  Future<void> send() async {
    final question = input.text.trim();
    if (question.isEmpty || sending) return;
    if (selected.isEmpty) {
      await choose();
      if (selected.isEmpty || !mounted) return;
    }
    setState(() {
      sending = true;
      error = '';
      pendingQuestion = question;
    });
    try {
      if (chatId.isEmpty) {
        final chat = await widget.model.api('POST', '/api/v1/personal/chats', {
          'title': question.substring(0, question.length.clamp(0, 80)),
          'contexts': selected,
        });
        chatId = text(chat['id']);
      } else
        await widget.model.api(
          'PATCH',
          '/api/v1/personal/chats/$chatId/context',
          {'contexts': selected},
        );
      job = await widget.model.api(
        'POST',
        '/api/v1/personal/chats/$chatId/messages',
        {'question': question, 'client_id': requestId()},
      );
      input.clear();
      await poll();
    } catch (e) {
      if (mounted)
        setState(() {
          error = TenoModel.friendly(e);
          sending = false;
          pendingQuestion = '';
        });
    }
  }

  Future<void> poll() async {
    try {
      final value = await widget.model.api('GET', '/api/v1/jobs/${job['id']}');
      if (!mounted) return;
      job = value;
      if (job['status'] == 'completed') {
        setState(() {
          sending = false;
          pendingQuestion = '';
        });
        await load();
      } else if (job['status'] == 'failed') {
        setState(() {
          sending = false;
          error = text(object(job['error'])['message']);
        });
      } else
        timer = Timer(const Duration(seconds: 3), poll);
    } catch (e) {
      if (mounted)
        setState(() {
          error = TenoModel.friendly(e);
          sending = false;
        });
    }
  }

  Future<void> dictate() async {
    if (dictating) return;
    setState(() => dictating = true);
    try {
      final result = await widget.model.command('dictate');
      if (!mounted) return;
      final value = text(result['text']);
      if (value.isNotEmpty) input.text = value;
    } catch (e) {
      if (mounted) setState(() => error = TenoModel.friendly(e));
    } finally {
      if (mounted) setState(() => dictating = false);
    }
  }

  @override
  Widget build(BuildContext context) => CoreFrame(
    title: 'Chat',
    actions: [
      CoreAction(
        Icons.history,
        'Chat history',
        () => push(
          context,
          CoreFrame(
            title: 'Chat history',
            child: PersonalChatHistory(widget.model),
          ),
        ),
      ),
    ],
    bottom: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CoreSurface(
          radius: 32,
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Add context',
                onPressed: sending ? null : choose,
                icon: const Icon(Icons.add, size: 22),
              ),
              Expanded(
                child: TextField(
                  controller: input,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Ask me anything about your recordings',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onSubmitted: (_) => send(),
                ),
              ),
              if (input.text.trim().isEmpty && !widget.model.webExperience)
                IconButton(
                  tooltip: 'Voice input',
                  onPressed: dictating || sending ? null : dictate,
                  icon: dictating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.graphic_eq, size: 21),
                ),
              if (input.text.trim().isNotEmpty)
                IconButton(
                  tooltip: 'Send question',
                  onPressed: sending ? null : send,
                  icon: const Icon(Icons.arrow_upward, size: 22),
                ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Check important answers against the linked sources.',
          style: TextStyle(fontSize: 10, color: subtle(context)),
        ),
      ],
    ),
    child: Column(
      children: [
        if (selected.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 6),
              child: ActionChip(
                avatar: const Icon(Icons.attach_file, size: 16),
                label: Text('${selected.length} sources'),
                onPressed: sending ? null : choose,
              ),
            ),
          ),
        if (error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 21),
            child: ErrorNotice(error),
          ),
        Expanded(
          child: messages.isEmpty && !sending
              ? LayoutBuilder(
                  builder: (context, c) => SingleChildScrollView(
                    reverse: true,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'How can I help you today?',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 24),
                              for (final question in [
                                'Recap the key decisions',
                                'What are the next steps?',
                                'Find the important details',
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant,
                                      ),
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerLowest,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(24),
                                          topRight: Radius.circular(24),
                                          bottomRight: Radius.circular(24),
                                          bottomLeft: Radius.circular(5),
                                        ),
                                      ),
                                    ),
                                    onPressed: () {
                                      input.text = question;
                                    },
                                    child: Text(question),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : ListView(
                  controller: scroll,
                  padding: const EdgeInsets.all(21),
                  children: [
                    for (final message in messages)
                      ...messageWidgets(
                        object(message['data']),
                        text(message['id']),
                      ),
                    if (pendingQuestion.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(pendingQuestion),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    ),
  );
  List<Widget> messageWidgets(Json data, String messageId) => [
    Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: 16, bottom: 20),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Text(text(data['question'])),
      ),
    ),
    SelectableText(
      text(data['answer']),
      style: const TextStyle(fontSize: 14, height: 1.75),
    ),
    Wrap(
      spacing: 6,
      children: [
        for (final cite in rows(data['citations']))
          ActionChip(
            label: Text(
              cite['page'] != null
                  ? 'Page ${cite['page']}'
                  : 'Source · ${duration(cite['start_ms'])}',
              style: const TextStyle(fontSize: 11),
            ),
            onPressed: () => openPersonalItem(context, widget.model, {
              'type': cite['type'] ?? 'recording',
              'id': cite['recording_id'] ?? cite['file_id'] ?? cite['note_id'],
            }, cite),
          ),
      ],
    ),
    Row(
      children: [
        IconButton(
          tooltip: 'Share answer',
          onPressed: () => widget.model.host.shareText(text(data['answer'])),
          icon: const Icon(Icons.ios_share_outlined, size: 18),
        ),
        IconButton(
          tooltip: 'Save as note',
          onPressed: () async {
            final folder = await choosePersonalFolder(context, widget.model);
            if (folder == null || !mounted) return;
            final note = await widget.model.api(
              'POST',
              '/api/v1/personal/messages/$messageId/save',
              {'folder_id': folder.isEmpty ? null : folder},
            );
            if (!mounted) return;
            await push(
              context,
              PersonalNotePage(widget.model, text(note['id'])),
            );
          },
          icon: const Icon(Icons.bookmark_add_outlined, size: 18),
        ),
      ],
    ),
  ];
  @override
  void dispose() {
    timer?.cancel();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }
}
