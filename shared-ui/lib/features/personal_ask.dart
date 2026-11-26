import '../l10n/ui_strings.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/model.dart';
import '../ui/widgets.dart';
import '../ui/personal_widgets.dart';
import 'personal_actions.dart';
import 'interface_language.dart';
import 'routes/personal_notes.dart';

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
          label: const UiText('New chat'),
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
      child: Text(context.strings.useSourceCount(selected.length)),
    ),
    child: CoreLoad(
      load: allContexts,
      builder: (context, data, reload) => ListView(
        padding: const EdgeInsets.all(21),
        children: [
          const UiText('Select recordings, notes, documents or folders.'),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hint: UiText('Find a file'),
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
              subtitle: UiText(switch (text(item['type'])) {
                'recording' => 'Recording file',
                'note' => 'Note',
                'folder' => 'Folder',
                'file' => 'File',
                'document' => 'Document',
                _ => 'File',
              }),
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
    this.embedded = false,
    this.initial = const [],
    this.initialQuestion,
  });
  final TenoModel model;
  final String? chatId;
  final bool embedded;
  final List<Json> initial;
  final String? initialQuestion;
  @override
  State<PersonalChatPage> createState() => _PersonalChatPageState();
}

class _PersonalChatPageState extends State<PersonalChatPage> {
  final input = TextEditingController(), scroll = ScrollController();
  late String chatId = widget.chatId ?? '';
  late List<Json> selected = [...widget.initial];
  late String scopeMode = widget.initial.isEmpty ? 'all' : 'current';
  String folderId = '', folderTitle = '';
  Json get searchScope => {
    'mode': scopeMode,
    if (scopeMode == 'folder') 'folder_id': folderId,
  };
  String get scopeLabel => const {
    'all': 'All my files',
    'current': 'Current record',
    'folder': 'Selected folder',
    'selected': 'Selected files',
  }[scopeMode]!;
  List<Json> messages = [];
  String error = '', pendingQuestion = '';
  Json job = {};
  Timer? timer;
  bool sending = false, dictating = false;
  String messageIdentity = '', messageIntent = '';
  @override
  void initState() {
    super.initState();
    input.addListener(inputChanged);
    if (chatId.isNotEmpty) unawaited(load());
    if (widget.initialQuestion?.trim().isNotEmpty == true) {
      final scope = widget.model.runtime?.session.scope;
      input.text = widget.initialQuestion!.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scope == widget.model.runtime?.session.scope) {
          unawaited(send());
        }
      });
    }
  }

  void inputChanged() {
    if (mounted) setState(() {});
  }

  Future<void> load() async {
    try {
      final values = await Future.wait([
        widget.model.api('GET', '/api/v1/chats/$chatId'),
        widget.model.api('GET', '/api/v1/personal/chats/$chatId/messages'),
      ]);
      if (!mounted) return;
      final data = object(values[0]['data']);
      setState(() {
        messages = rows(values[1]['items']);
        selected = rows(data['contexts']);
        final scope = object(data['scope']);
        scopeMode = text(scope['mode']).isEmpty
            ? 'selected'
            : text(scope['mode']);
        folderId = text(scope['folder_id']);
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
    if (value != null && mounted)
      setState(() {
        selected = value;
        scopeMode = 'selected';
      });
  }

  Future<void> chooseScope() async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in [
              ('current', 'Current record'),
              ('folder', 'Selected folder'),
              ('all', 'All my files'),
              ('selected', 'Selected files'),
            ])
              ListTile(
                title: UiText(entry.$2),
                onTap: () => Navigator.pop(sheet, entry.$1),
              ),
          ],
        ),
      ),
    );
    if (mode == null || !mounted) return;
    if (mode == 'selected') {
      await choose();
      return;
    }
    if (mode == 'folder') {
      final folder = await choosePersonalFolder(context, widget.model);
      if (folder == null || !mounted) return;
      if (folder.isEmpty) {
        setState(() {
          scopeMode = 'all';
          folderId = '';
        });
        return;
      }
      final options = await widget.model.api(
        'GET',
        '/api/v1/library/search/options',
      );
      if (!mounted) return;
      setState(() {
        scopeMode = 'folder';
        folderId = folder;
        folderTitle =
            rows(options['folders'])
                .where((f) => f['id'] == folder)
                .map((f) => text(f['title']))
                .firstOrNull ??
            '';
      });
    } else if (mode == 'current') {
      if (widget.initial.isNotEmpty) {
        setState(() {
          scopeMode = mode;
          selected = [...widget.initial];
        });
      } else {
        await choose();
        final records = selected.where((s) => s['type'] != 'folder').toList();
        if (records.isNotEmpty && mounted)
          setState(() {
            scopeMode = mode;
            selected = [records.first];
          });
      }
    } else {
      setState(() => scopeMode = 'all');
    }
  }

  Future<void> send() async {
    final question = input.text.trim();
    if (question.isEmpty || sending) return;
    if (selected.isEmpty &&
        (scopeMode == 'current' || scopeMode == 'selected')) {
      await choose();
      if (selected.isEmpty || !mounted) return;
    }
    setState(() {
      sending = true;
      error = '';
      pendingQuestion = question;
    });
    try {
      final intent = jsonEncode([
        question,
        searchScope,
        selected,
        widget.model.outputLanguage,
      ]);
      if (messageIntent != intent) {
        messageIntent = intent;
        messageIdentity = requestId();
      }
      if (chatId.isEmpty) {
        final chat = await widget.model.api('POST', '/api/v1/personal/chats', {
          'title': question.substring(0, question.length.clamp(0, 80)),
          'contexts': (scopeMode == 'current' || scopeMode == 'selected')
              ? selected
              : [],
          'scope': searchScope,
        });
        chatId = text(chat['id']);
      } else
        await widget.model
            .api('PATCH', '/api/v1/personal/chats/$chatId/context', {
              'contexts': (scopeMode == 'current' || scopeMode == 'selected')
                  ? selected
                  : [],
              'scope': searchScope,
            });
      job = await widget.model
          .api('POST', '/api/v1/personal/chats/$chatId/messages', {
            'question': question,
            'client_id': messageIdentity,
            'output_language': widget.model.outputLanguage,
          });
      messageIntent = '';
      messageIdentity = '';
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
          pendingQuestion = '';
          error = text(object(job['error'])['message']);
        });
      } else
        timer = Timer(const Duration(seconds: 3), poll);
    } catch (e) {
      if (mounted)
        setState(() {
          error = TenoModel.friendly(e);
          sending = false;
          pendingQuestion = '';
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
    title: widget.embedded ? 'Assistant' : 'Chat',
    showBack: !widget.embedded,
    actions: [
      InterfaceLanguageButton(widget.model),
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
          radius: 14,
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: ui(context, 'Add context'),
                onPressed: sending || widget.initialQuestion != null
                    ? null
                    : choose,
                icon: const Icon(Icons.add, size: 22),
              ),
              Expanded(
                child: TextField(
                  controller: input,
                  minLines: 1,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hint: UiText('Ask me anything about your recordings'),
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
                  tooltip: ui(context, 'Voice input'),
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
                  tooltip: ui(context, 'Send question'),
                  onPressed: sending ? null : send,
                  icon: const Icon(Icons.arrow_upward, size: 22),
                ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        UiText(
          'Check important answers against the linked sources.',
          style: TextStyle(fontSize: 10, color: subtle(context)),
        ),
      ],
    ),
    child: Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 6),
            child: ActionChip(
              avatar: const Icon(Icons.travel_explore, size: 16),
              label: Text(
                '${ui(context, scopeLabel)}${scopeMode == 'folder' && folderTitle.isNotEmpty ? ' · $folderTitle' : ''}',
              ),
              onPressed: sending || widget.initialQuestion != null
                  ? null
                  : () => perform(context, chooseScope),
            ),
          ),
        ),
        if (selected.isNotEmpty &&
            (scopeMode == 'current' || scopeMode == 'selected'))
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 6),
              child: ActionChip(
                avatar: const Icon(Icons.attach_file, size: 16),
                label: Text(context.strings.sourceCount(selected.length)),
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
                    reverse: false,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: Align(
                        alignment: Alignment.center,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Icon(Icons.auto_awesome_outlined, size: 40),
                              const SizedBox(height: 24),
                              const UiText(
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
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {
                                      input.text = ui(context, question);
                                    },
                                    child: UiText(question),
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
                      if (object(job['result'])['stage'] ==
                          'preparing_search_index')
                        const UiText(
                          'Preparing personal search. Existing files are not regenerated.',
                        ),
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
    if (object(data['scope']).isNotEmpty)
      UiText(switch (object(data['scope'])['mode']) {
        'current' => 'Current record',
        'folder' => 'Selected folder',
        'selected' => 'Selected files',
        _ => 'All my files',
      }, style: TextStyle(fontSize: 11, color: subtle(context))),
    if (rows(data['paragraphs']).isNotEmpty)
      for (final paragraph in rows(data['paragraphs'])) ...[
        SelectableText(
          text(paragraph['text']),
          style: const TextStyle(fontSize: 14, height: 1.75),
        ),
        citationLinks(rows(paragraph['citations'])),
        const SizedBox(height: 10),
      ]
    else ...[
      SelectableText(
        data['sources_unavailable'] == true
            ? ui(context, 'Sources unavailable')
            : text(data['answer']),
        style: const TextStyle(fontSize: 14, height: 1.75),
      ),
      citationLinks(rows(data['citations'])),
    ],
    Row(
      children: [
        IconButton(
          tooltip: ui(context, 'Share answer'),
          onPressed: data['sources_unavailable'] == true
              ? null
              : () => widget.model.host.shareText(text(data['answer'])),
          icon: const Icon(Icons.ios_share_outlined, size: 18),
        ),
        IconButton(
          tooltip: ui(context, 'Save as note'),
          onPressed: data['sources_unavailable'] == true
              ? null
              : () async {
                  final folder = await choosePersonalFolder(
                    context,
                    widget.model,
                  );
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
  Widget citationLinks(List<Json> citations) => Wrap(
    spacing: 6,
    children: [
      for (final cite in citations)
        ActionChip(
          label: Text(
            [
              if (text(cite['title']).isNotEmpty) text(cite['title']),
              if (text(cite['saved_at']).isNotEmpty)
                '${ui(context, 'Saved date')}: ${dateLabel(cite['saved_at'])}',
              if (text(cite['version_updated_at']).isNotEmpty &&
                  cite['version_updated_at'] != cite['saved_at'])
                '${ui(context, 'Version updated')}: ${dateLabel(cite['version_updated_at'])}',
              if (cite['page'] != null)
                context.strings.pageNumber(text(cite['page']))
              else if (cite['start_ms'] != null)
                context.strings.sourceTimestamp(duration(cite['start_ms'])),
            ].join(' · '),
            style: const TextStyle(fontSize: 11),
            maxLines: 3,
          ),
          onPressed: () => openPersonalItem(context, widget.model, {
            'type': cite['type'] ?? 'recording',
            'id': cite['type'] == 'note'
                ? cite['note_id']
                : cite['type'] == 'file'
                ? cite['file_id']
                : cite['recording_id'],
          }, cite),
        ),
    ],
  );
  @override
  void dispose() {
    timer?.cancel();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }
}
