import 'dart:async';
import 'package:flutter/material.dart';
import '../core/model.dart';
import '../ui/widgets.dart';
import '../ui/personal_widgets.dart';
import 'personal_actions.dart';
import 'personal_ask.dart';

class PersonalSearchPage extends StatefulWidget {
  const PersonalSearchPage(this.model, {super.key, this.onNavigation});
  final TenoModel model;
  final VoidCallback? onNavigation;
  @override
  State<PersonalSearchPage> createState() => _PersonalSearchPageState();
}

class _PersonalSearchPageState extends State<PersonalSearchPage> {
  final query = TextEditingController();
  Timer? timer;
  List<Json> found = [];
  List<String> history = [];
  Json options = {};
  bool loading = false, ascending = false;
  String error = '', optionError = '', sort = 'match';
  String? folder, kind, speaker;
  DateTimeRange? dates;
  int generation = 0, total = 0;
  bool get supported => widget.model.capabilities['library_filters'] == 1;
  bool get filtered =>
      folder != null || kind != null || speaker != null || dates != null;
  bool get active => query.text.trim().isNotEmpty || filtered;

  @override
  void initState() {
    super.initState();
    unawaited(loadHistory());
    if (supported) unawaited(loadOptions());
  }

  Future<void> loadHistory() async {
    try {
      final value = await widget.model.command('history');
      if (mounted)
        setState(
          () => history = (value['items'] as List? ?? []).map(text).toList(),
        );
    } catch (_) {
      /* History is optional; search remains available. */
    }
  }

  Future<void> loadOptions() async {
    try {
      final value = await widget.model.api(
        'GET',
        '/api/v1/library/search/options',
      );
      if (mounted)
        setState(() {
          options = value;
          optionError = '';
        });
    } catch (e) {
      if (mounted) setState(() => optionError = TenoModel.friendly(e));
    }
  }

  void search(String value, {bool immediate = false}) {
    timer?.cancel();
    final current = ++generation;
    setState(() {
      found = [];
      total = 0;
      error = '';
      loading = active;
    });
    timer = Timer(
      Duration(milliseconds: immediate ? 0 : 350),
      () => fetch(current),
    );
  }

  Future<void> fetch(int current, {bool append = false}) async {
    if (!active) {
      if (mounted) setState(() => loading = false);
      return;
    }
    setState(() {
      loading = true;
      error = '';
    });
    final params = <String, String>{
      'q': query.text.trim(),
      'sort': sort,
      'limit': '50',
      'offset': append ? '${found.length}' : '0',
      if (supported) 'ascending': '$ascending',
      if (supported && folder != null) 'folder_id': folder!,
      if (supported && kind != null) 'type': kind!,
      if (supported && speaker != null) 'speaker': speaker!,
      if (supported && dates != null) ...{
        'date_from': DateTime(
          dates!.start.year,
          dates!.start.month,
          dates!.start.day,
        ).toUtc().toIso8601String(),
        // Construct the next local midnight, including daylight-saving transitions.
        'date_to': DateTime(
          dates!.end.year,
          dates!.end.month,
          dates!.end.day + 1,
        ).toUtc().toIso8601String(),
      },
    };
    try {
      final result = await widget.model.api(
        'GET',
        '/api/v1/library/search?${Uri(queryParameters: params).query}',
      );
      if (!mounted || current != generation) return;
      setState(() {
        found = [...(append ? found : <Json>[]), ...rows(result['items'])];
        total = (result['total'] as num? ?? found.length).toInt();
      });
      if (!append && query.text.trim().isNotEmpty) {
        try {
          await widget.model.command('history', {'query': query.text.trim()});
        } catch (_) {}
      }
    } catch (e) {
      if (mounted && current == generation)
        setState(() => error = TenoModel.friendly(e));
    } finally {
      if (mounted && current == generation) setState(() => loading = false);
    }
  }

  String folderLabel() =>
      rows(options['folders'])
          .where((v) => v['id'] == folder)
          .map((v) => text(v['title']))
          .firstOrNull ??
      'Folder';
  String typeLabel(String? value) =>
      const {
        'recording': 'Recordings',
        'note': 'Notes',
        'documents': 'Documents',
        'images': 'Photos',
        'folder': 'Folders',
        'file': 'Files',
      }[value] ??
      'Type';

  Future<void> choose(String field) async {
    FocusScope.of(context).unfocus();
    if (field == 'Date range') {
      final action = await showCoreSheet<String>(
        context,
        Builder(
          builder: (sheet) => CoreFrame(
            title: 'Date range',
            sheet: true,
            child: ListView(
              children: [
                ListTile(
                  title: const Text('Choose dates'),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () => Navigator.pop(sheet, 'pick'),
                ),
                ListTile(
                  title: const Text('Any date'),
                  trailing: dates == null ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(sheet, 'clear'),
                ),
              ],
            ),
          ),
        ),
        height: 230,
      );
      if (!mounted || action == null) return;
      if (action == 'clear') {
        setState(() => dates = null);
        search(query.text, immediate: true);
        return;
      }
      final result = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(DateTime.now().year + 2),
        initialDateRange: dates,
        helpText: 'Date range',
        confirmText: 'Save',
      );
      if (!mounted || result == null) return;
      setState(() => dates = result);
    } else {
      final selected = switch (field) {
        'Folder' => folder,
        'Type' => kind,
        _ => speaker,
      };
      final values = field == 'Folder'
          ? rows(options['folders'])
                .map(
                  (v) => ({
                    'id': text(v['id']),
                    'title': text(v['title']),
                    'parent_id': v['parent_id'],
                  }),
                )
                .toList()
          : field == 'Type'
          ? (options['types'] as List? ?? [])
                .map((v) => ({'id': text(v), 'title': typeLabel(text(v))}))
                .toList()
          : (options['speakers'] as List? ?? [])
                .map((v) => ({'id': text(v), 'title': text(v)}))
                .toList();
      final result = await showCoreSheet<String>(
        context,
        Builder(
          builder: (sheet) => CoreFrame(
            title: field,
            sheet: true,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                ListTile(
                  title: Text('Any ${field.toLowerCase()}'),
                  trailing: selected == null
                      ? const Icon(Icons.check, size: 20)
                      : null,
                  onTap: () => Navigator.pop(sheet, '__all__'),
                ),
                for (final v in values)
                  ListTile(
                    leading: field == 'Folder'
                        ? Icon(
                            v['parent_id'] == null
                                ? Icons.folder_outlined
                                : Icons.subdirectory_arrow_right,
                          )
                        : null,
                    title: Text(text(v['title'])),
                    trailing: selected == v['id']
                        ? const Icon(Icons.check, size: 20)
                        : null,
                    onTap: () => Navigator.pop(sheet, text(v['id'])),
                  ),
                if (values.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      field == 'Speaker'
                          ? 'Name a speaker in a transcript to filter recordings.'
                          : 'No options yet.',
                    ),
                  ),
              ],
            ),
          ),
        ),
        height: 470,
      );
      if (!mounted || result == null) return;
      setState(() {
        final v = result == '__all__' ? null : result;
        if (field == 'Folder')
          folder = v;
        else if (field == 'Type')
          kind = v;
        else
          speaker = v;
      });
    }
    search(query.text, immediate: true);
  }

  Widget filter(String label, String display, bool selected) => InkWell(
    onTap: () => choose(label),
    borderRadius: BorderRadius.circular(5),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: selected
            ? coreBlue.withValues(alpha: .12)
            : Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 115),
            child: Text(
              display,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: selected ? coreBlue : subtle(context),
              ),
            ),
          ),
          if (label != 'Speaker')
            Icon(
              Icons.keyboard_arrow_down,
              size: 13,
              color: selected ? coreBlue : subtle(context),
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leadingWidth: 68,
      leading: Padding(
        padding: const EdgeInsets.all(12),
        child: CoreAction(
          widget.onNavigation == null
              ? Icons.arrow_back_ios_new_rounded
              : Icons.menu_rounded,
          widget.onNavigation == null ? 'Back' : 'Navigation',
          () {
            Navigator.pop(context);
            widget.onNavigation?.call();
          },
        ),
      ),
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: TextField(
          controller: query,
          autofocus: false,
          onChanged: search,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) => search(v, immediate: true),
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search',
            prefixIcon: const Icon(Icons.search, size: 20),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            suffixIcon: query.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      query.clear();
                      search('');
                    },
                    icon: const Icon(Icons.close, size: 18),
                  ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
          ),
        ),
      ),
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          if (supported)
            Padding(
              padding: const EdgeInsets.fromLTRB(coreInset, 0, coreInset, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    filter('Folder', folderLabel(), folder != null),
                    filter('Type', typeLabel(kind), kind != null),
                    filter('Speaker', speaker ?? 'Speaker', speaker != null),
                    filter(
                      'Date range',
                      dates == null
                          ? 'Date range'
                          : '${coreDate(dates!.start.toIso8601String())} – ${coreDate(dates!.end.toIso8601String())}',
                      dates != null,
                    ),
                  ],
                ),
              ),
            ),
          if (optionError.isNotEmpty)
            ErrorNotice(optionError, retry: loadOptions),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: coreInset),
              children: [
                if (error.isNotEmpty)
                  ErrorNotice(
                    error,
                    retry: () => fetch(generation, append: found.isNotEmpty),
                  ),
                if (!active) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Recent searches',
                          style: TextStyle(
                            fontSize: 14,
                            color: subtle(context),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Clear search history',
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => perform(context, () async {
                          await widget.model.command('history', {
                            'clear': true,
                          });
                          await loadHistory();
                        }),
                      ),
                    ],
                  ),
                  for (final value in history)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.search, size: 20),
                      title: Text(value, style: const TextStyle(fontSize: 14)),
                      onTap: () {
                        query.text = value;
                        search(value, immediate: true);
                      },
                    ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$total results',
                          style: TextStyle(
                            fontSize: 13,
                            color: subtle(context),
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Sort search results',
                        onSelected: (value) {
                          final parts = value.split(':');
                          setState(() {
                            sort = parts[0];
                            ascending = parts[1] == 'asc';
                          });
                          search(query.text, immediate: true);
                        },
                        itemBuilder: (_) => [
                          for (final v in [
                            ('match:desc', 'Best match'),
                            ('modified:desc', 'Date modified · newest'),
                            ('created:desc', 'Date created · newest'),
                            if (supported)
                              ('created:asc', 'Date created · oldest'),
                          ])
                            PopupMenuItem(value: v.$1, child: Text(v.$2)),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            children: [
                              Text(
                                sort == 'match'
                                    ? 'Best match'
                                    : sort == 'modified'
                                    ? 'Date modified'
                                    : 'Date created',
                                style: const TextStyle(fontSize: 13),
                              ),
                              const Icon(Icons.keyboard_arrow_down, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  for (final result in found)
                    Builder(
                      builder: (context) {
                        final item = object(result['item']),
                            matches = rows(result['matches']);
                        return CoreTile(
                          item,
                          () => openPersonalItem(
                            context,
                            widget.model,
                            item,
                            matches.isEmpty ? null : matches.first,
                          ),
                          highlight: query.text,
                          showFolder: true,
                          snippet: matches.isEmpty
                              ? null
                              : text(matches.first['text']),
                        );
                      },
                    ),
                  if (!loading && found.isEmpty && error.isEmpty)
                    const EmptyState(
                      'No results',
                      'Try another word or adjust your filters.',
                    ),
                  if (found.length < total)
                    TextButton(
                      onPressed: loading
                          ? null
                          : () => fetch(generation, append: true),
                      child: const Text('Load more'),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
        ? null
        : SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: AskBar(
                () => push(context, PersonalChatPage(widget.model)),
              ),
            ),
          ),
  );

  @override
  void dispose() {
    timer?.cancel();
    query.dispose();
    super.dispose();
  }
}
