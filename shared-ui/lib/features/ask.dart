import 'dart:async';
import 'package:flutter/material.dart';
import '../core/model.dart';
import '../ui/widgets.dart';
import 'detail.dart';

class AskHistoryBody extends StatefulWidget {
  const AskHistoryBody(this.model, {super.key});
  final TenoModel model;
  @override
  State<AskHistoryBody> createState() => _AskHistoryBodyState();
}

class _AskHistoryBodyState extends State<AskHistoryBody> {
  late Future<List<Json>> pending;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    setState(() => pending = widget.model.list('/api/v1/chats?limit=200'));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Json>>(
    future: pending,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return Padding(
          padding: const EdgeInsets.all(23),
          child: ErrorNotice(
            TenoModel.friendly(snapshot.error!),
            retry: reload,
          ),
        );
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      if (snapshot.data!.isEmpty)
        return EmptyState(
          'No chat history',
          'Ask a question about your recordings.',
          icon: Icons.chat_bubble_outline,
          action: FilledButton(
            onPressed: () async {
              await push(context, ChatPage(widget.model));
              if (mounted) reload();
            },
            child: const Text('New chat'),
          ),
        );
      return RefreshIndicator(
        onRefresh: () async {
          reload();
          await pending;
        },
        child: ListView(
          padding: const EdgeInsets.all(23),
          children: [
            for (final item in snapshot.data!)
              MenuRow(
                Icons.chat_bubble_outline,
                text(object(item['data'])['title']),
                () async {
                  await push(
                    context,
                    ChatPage(widget.model, chatId: text(item['id'])),
                  );
                  if (mounted) reload();
                },
                subtitle: dateLabel(item['created_at']),
              ),
          ],
        ),
      );
    },
  );
}

class ChatPage extends StatefulWidget {
  const ChatPage(
    this.model, {
    super.key,
    this.chatId,
    this.recordingIds = const [],
  });
  final TenoModel model;
  final String? chatId;
  final List<String> recordingIds;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final question = TextEditingController(), scroll = ScrollController();
  late String id = widget.chatId ?? '';
  late List<String> selected = [...widget.recordingIds];
  List<Json> messages = [];
  String error = '',
      jobId = '',
      pendingQuestion = '',
      pendingClient = '',
      lastQuestion = '';
  bool loading = false, sending = false;
  Timer? timer;
  int attempts = 0;
  @override
  void initState() {
    super.initState();
    if (id.isNotEmpty) unawaited(load());
  }

  Future<void> load() async {
    if (id.isEmpty) return;
    setState(() => loading = true);
    try {
      final values = await Future.wait([
        widget.model.api('GET', '/api/v1/chats/' + id),
        widget.model.list('/api/v1/chats/' + id + '/messages'),
      ]);
      if (!mounted) return;
      setState(() {
        messages = rows(values[1]);
        selected =
            (object(object(values[0])['data'])['recording_ids'] as List? ?? [])
                .map(text)
                .toList();
      });
    } catch (e) {
      if (mounted) setState(() => error = TenoModel.friendly(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> contextPicker() async {
    final result = await push<List<String>>(
      context,
      ContextPicker(widget.model, selected),
    );
    if (result == null || !mounted) return;
    await perform(context, () async {
      if (id.isNotEmpty)
        await widget.model.api('PATCH', '/api/v1/chats/' + id, {
          'recording_ids': result,
        });
      setState(() => selected = result);
    });
  }

  Future<void> send() async {
    final value = question.text.trim();
    if (value.isEmpty || sending) return;
    if (selected.isEmpty) {
      await contextPicker();
      if (selected.isEmpty || !mounted) return;
    }
    setState(() {
      sending = true;
      error = '';
    });
    try {
      if (id.isEmpty) {
        final chat = await widget.model.api('POST', '/api/v1/chats', {
          'title': value.length > 80 ? value.substring(0, 80) : value,
          'recording_ids': selected,
        });
        id = text(chat['id']);
      }
      // An uncertain network retry of the same question reuses its id.
      if (lastQuestion != value) {
        lastQuestion = value;
        pendingClient = requestId();
      }
      final job = await widget.model.api(
        'POST',
        '/api/v1/chats/' + id + '/messages',
        {'question': value, 'client_id': pendingClient},
      );
      if (!mounted) return;
      setState(() {
        pendingQuestion = value;
        question.clear();
        jobId = text(job['id']);
        attempts = 0;
      });
      await poll();
    } catch (e) {
      if (mounted)
        setState(() {
          error = TenoModel.friendly(e);
          sending = false;
        });
    }
  }

  Future<void> poll() async {
    if (!mounted || jobId.isEmpty) return;
    try {
      final job = await widget.model.api('GET', '/api/v1/jobs/' + jobId);
      if (!mounted) return;
      if (['done', 'succeeded', 'completed'].contains(job['status'])) {
        setState(() {
          sending = false;
          pendingQuestion = '';
          jobId = '';
          lastQuestion = '';
        });
        await load();
        return;
      }
      if (job['status'] == 'failed') {
        throw StateError(
          text(object(job['error'])['message']).isEmpty
              ? 'The answer could not be generated.'
              : text(object(job['error'])['message']),
        );
      }
      if (attempts++ >= 60) {
        setState(() {
          sending = false;
          error =
              'This answer is taking longer. Refresh this conversation to check again.';
        });
        return;
      }
      timer = Timer(const Duration(seconds: 3), () => unawaited(poll()));
    } catch (e) {
      if (mounted)
        setState(() {
          error = TenoModel.friendly(e);
          sending = false;
        });
    }
  }

  Future<void> retry() async {
    if (jobId.isEmpty) {
      await send();
      return;
    }
    await perform(context, () async {
      final job = await widget.model.api('GET', '/api/v1/jobs/' + jobId);
      if (job['status'] == 'failed')
        await widget.model.api('POST', '/api/v1/jobs/' + jobId + '/retry', {});
      setState(() {
        sending = true;
        error = '';
        attempts = 0;
      });
      await poll();
    });
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Ask Teno',
    actions: [
      CircleAction(
        Icons.refresh,
        'Refresh conversation',
        loading ? null : load,
      ),
    ],
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 23),
          child: OutlinedButton.icon(
            onPressed: sending ? null : contextPicker,
            icon: const Icon(Icons.attach_file, size: 18),
            label: Text(selected.length.toString() + ' recordings selected'),
          ),
        ),
        if (loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: messages.isEmpty && pendingQuestion.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(23),
                  children: [
                    const SizedBox(height: 90),
                    const Text(
                      'What would you like to know?',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 26),
                    for (final suggestion in [
                      'Summarize the key decisions',
                      'What are the next steps?',
                      'What should I follow up on?',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OutlinedButton(
                          onPressed: () {
                            question.text = suggestion;
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(suggestion),
                          ),
                        ),
                      ),
                    if (error.isNotEmpty) ErrorNotice(error, retry: retry),
                  ],
                )
              : ListView(
                  controller: scroll,
                  padding: const EdgeInsets.all(23),
                  children: [
                    for (final item in messages)
                      ...messageWidgets(object(item['data'])),
                    if (pendingQuestion.isNotEmpty) ...[
                      userMessage(pendingQuestion),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Preparing your answer…',
                          style: TextStyle(color: muted),
                        ),
                      ),
                    ],
                    if (error.isNotEmpty) ErrorNotice(error, retry: retry),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 6, 15, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: question,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    hintText: 'Ask about your recordings',
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAction(
                sending ? Icons.hourglass_top : Icons.arrow_upward,
                'Send question',
                sending ? null : send,
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(23, 0, 23, 14),
          child: Text(
            'Check answers against the linked source recordings.',
            style: TextStyle(fontSize: 11, color: muted),
          ),
        ),
      ],
    ),
  );
  Widget userMessage(String value) => Container(
    margin: const EdgeInsets.only(left: 45, top: 12, bottom: 22),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFFEDEEEE),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(value),
  );
  List<Widget> messageWidgets(Json data) => [
    userMessage(text(data['question'])),
    SelectableText(text(data['answer']), style: const TextStyle(height: 1.8)),
    if (data['grounded'] != true)
      const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          'No verifiable source was included. Check this answer against your recordings.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ),
    for (final cite in rows(data['citations']))
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: OutlinedButton.icon(
          onPressed: () => push(
            context,
            DetailPage(
              widget.model,
              text(cite['recording_id']),
              seekMs: (cite['start_ms'] as num? ?? 0).toInt(),
            ),
          ),
          icon: const Icon(Icons.description_outlined, size: 16),
          label: Text('Source · ' + duration(cite['start_ms'])),
        ),
      ),
    Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        tooltip: 'Share answer',
        icon: const Icon(Icons.ios_share, size: 18),
        onPressed: () => perform(
          context,
          () => widget.model.host.shareText(text(data['answer'])),
        ),
      ),
    ),
    const SizedBox(height: 18),
  ];
  @override
  void dispose() {
    timer?.cancel();
    question.dispose();
    scroll.dispose();
    super.dispose();
  }
}

class ContextPicker extends StatefulWidget {
  const ContextPicker(this.model, this.initial, {super.key});
  final TenoModel model;
  final List<String> initial;
  @override
  State<ContextPicker> createState() => _ContextPickerState();
}

class _ContextPickerState extends State<ContextPicker> {
  late final selected = widget.initial.toSet();
  List<Json> items = [];
  bool more = true, loading = false;
  String error = '';
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final next = await widget.model.list(
        '/api/v1/recordings?limit=50&offset=' + items.length.toString(),
      );
      if (mounted)
        setState(() {
          items.addAll(next);
          more = next.length == 50;
        });
    } catch (e) {
      if (mounted) setState(() => error = TenoModel.friendly(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Add context',
    bottom: FilledButton(
      onPressed: selected.isEmpty
          ? null
          : () => Navigator.pop(context, selected.toList()),
      child: Text('Use ' + selected.length.toString() + ' recordings'),
    ),
    child: ListView(
      padding: const EdgeInsets.all(23),
      children: [
        const Text(
          'Choose up to 30 recordings with transcripts.',
          style: TextStyle(color: muted),
        ),
        if (loading) const LinearProgressIndicator(minHeight: 2),
        if (error.isNotEmpty) ErrorNotice(error, retry: load),
        for (final item in items)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(text(item['title'])),
            subtitle: Text(
              dateLabel(item['created_at']) + ' · ' + text(item['status']),
            ),
            value: selected.contains(text(item['id'])),
            onChanged: item['status'] != 'transcribed'
                ? null
                : (value) {
                    if (value == true && selected.length >= 30) return;
                    setState(() {
                      if (value == true) {
                        selected.add(text(item['id']));
                      } else {
                        selected.remove(text(item['id']));
                      }
                    });
                  },
          ),
        if (more)
          TextButton(
            onPressed: loading ? null : load,
            child: const Text('Load more'),
          ),
      ],
    ),
  );
}
