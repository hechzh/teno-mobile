part of 'personal_recording.dart';

// Web-only presentation of the existing recording/note contracts. Native keeps
// its original state and layout. No prompts, generated text or timestamps here.
class _WebRecordingPageState extends _PersonalRecordingPageState {
  final _noteScroll = ScrollController(),
      _transcriptScroll = ScrollController();
  final _topicKeys = <int, GlobalKey>{};
  bool _transcriptTab = false, _playPending = false;
  int _loadStamp = 0;
  String _selectedNote = '', _folderTitle = '';
  List<Json>? _shares;
  Json _sourceTranscript = {};

  @override
  bool get audio => _transcriptTab;
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _paper => _dark ? const Color(0xFF16211C) : Colors.white;
  Color get _ink => _dark ? const Color(0xFFECF2ED) : const Color(0xFF1C2925);
  Color get _muted => _dark ? const Color(0xFFA2B3A7) : const Color(0xFF7B897F);
  Color get _green => _dark ? const Color(0xFFABD5B9) : const Color(0xFF2D6552);
  Color get _sage => _dark ? const Color(0xFF23382C) : const Color(0xFFF1F6F2);
  Color get _line => _dark ? const Color(0xFF34473A) : const Color(0xFFE9EEEB);
  Json get _note => notes.isEmpty ? {} : notes[noteIndex];
  List<Json> _chapters(Json note) => rows(
    object(note['data'])['chapters'],
  ).where((v) => text(v['title']).trim().isNotEmpty).toList();
  int get _duration => (record['duration_ms'] as num? ?? 0).toInt();
  ThemeData get _theme => Theme.of(context).copyWith(
    scaffoldBackgroundColor: _paper,
    colorScheme: Theme.of(context).colorScheme.copyWith(
      surface: _paper,
      onSurface: _ink,
      primary: _green,
      onSurfaceVariant: _muted,
      outlineVariant: _line,
      surfaceContainerLowest: _paper,
      surfaceContainerLow: _sage,
      surfaceContainerHighest: _sage,
    ),
    textTheme: Theme.of(
      context,
    ).textTheme.apply(bodyColor: _ink, displayColor: _ink),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _green,
        minimumSize: const Size(36, 40),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12),
      ),
    ),
  );

  @override
  void initState() {
    _transcriptTab = widget.transcriptOnly || widget.seekMs != null;
    super.initState();
  }

  @override
  Future<void> load() async {
    timer?.cancel();
    final stamp = ++_loadStamp, requestedVariant = variant;
    try {
      final values = await Future.wait([
        widget.model.api('GET', path),
        widget.model.api(
          'GET',
          '/api/v1/personal/recordings/${widget.id}/transcript?variant=$requestedVariant',
        ),
        widget.model.api('GET', '$path/notes'),
        widget.model.api('GET', '$path/metadata'),
        widget.model.api(
          'GET',
          '/api/v1/personal/recordings/${widget.id}/processing',
        ),
      ]);
      if (!mounted || stamp != _loadStamp) return;
      setState(() {
        record = values[0];
        transcript = values[1];
        notes = rows(values[2]['items']);
        metadata = values[3];
        processing = values[4];
        loading = false;
        error = '';
        final selected = notes.indexWhere((n) => n['id'] == _selectedNote);
        noteIndex = selected < 0 ? 0 : selected;
        _selectedNote = text(_note['id']);
        if (requestedVariant == 'edited') _sourceTranscript = transcript;
      });
      unawaited(_loadRelated(stamp));
      if (processing['status'] == 'processing')
        timer = Timer(const Duration(seconds: 6), load);
      if (audio) playbackChanged();
    } catch (e) {
      if (mounted && stamp == _loadStamp)
        setState(() {
          error = TenoModel.friendly(e);
          loading = false;
        });
    }
  }

  Future<void> _loadRelated(int stamp) async {
    Future<Json?> optional(String route) async {
      try {
        return await widget.model.api('GET', route);
      } catch (_) {
        return null;
      }
    }

    final folder = text(record['folder_id']);
    final values = await Future.wait([
      optional('/api/v1/shares'),
      folder.isEmpty
          ? Future<Json?>.value(null)
          : optional('/api/v1/folders/${Uri.encodeComponent(folder)}'),
      peaks.isNotEmpty || _duration <= 0
          ? Future<Json?>.value(null)
          : optional('$path/waveform'),
    ]);
    if (!mounted || stamp != _loadStamp) return;
    setState(() {
      _shares = values[0] == null ? null : rows(values[0]!['items']);
      _folderTitle = folder.isEmpty
          ? 'Recordings'
          : text(object(values[1]?['data'])['title']);
      if (values[2] != null)
        peaks = (values[2]!['peaks'] as List? ?? [])
            .whereType<num>()
            .map((v) => v.toDouble())
            .toList();
    });
  }

  bool get _shared {
    final noteIds = notes.map((n) => text(n['id'])).toSet();
    return (_shares ?? []).any((s) {
      final expires = DateTime.tryParse(text(s['expires_at']));
      return s['revoked'] != true &&
          expires != null &&
          expires.isAfter(DateTime.now()) &&
          (s['source_type'] == 'recording' && s['source_id'] == widget.id ||
              s['source_type'] == 'note' &&
                  noteIds.contains(text(s['source_id'])));
    });
  }

  void _tab(bool transcript) {
    if (_transcriptTab == transcript) return;
    setState(() {
      _transcriptTab = transcript;
      currentSegment = -1;
    });
    if (transcript)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) playbackChanged();
      });
  }

  Future<T?> _panel<T>(String title, Widget Function(BuildContext) content) =>
      showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: _paper,
        constraints: const BoxConstraints(maxWidth: 760),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheet) => Theme(
          data: _theme,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                21,
                0,
                21,
                MediaQuery.viewInsetsOf(sheet).bottom + 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheet).height * .78,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close panel',
                          onPressed: () => Navigator.pop(sheet),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Flexible(child: content(sheet)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> _chooseNote() async {
    final chosen = await _panel<String>(
      'Your notes',
      (sheet) => SingleChildScrollView(
        child: Column(
          children: [
            for (final note in notes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(text(note['title'])),
                subtitle: Text('Version ${note['revision'] ?? 1}'),
                trailing: note['id'] == _note['id']
                    ? Icon(Icons.check, color: _green, size: 18)
                    : null,
                onTap: () => Navigator.pop(sheet, text(note['id'])),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add),
              title: const Text('New note'),
              onTap: () => Navigator.pop(sheet, '__new'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || chosen == null) return;
    if (chosen == '__new') {
      await generate();
      return;
    }
    final index = notes.indexWhere((n) => n['id'] == chosen);
    if (index < 0) return;
    setState(() {
      noteIndex = index;
      _selectedNote = chosen;
      _topicKeys.clear();
    });
    if (_noteScroll.hasClients) _noteScroll.jumpTo(0);
  }

  Future<void> _topics() async {
    final chapters = _chapters(_note);
    final chosen = await _panel<int>(
      'Topics',
      (sheet) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${chapters.length} topics',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ),
          for (var i = 0; i < chapters.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text(
                '${i + 1}'.padLeft(2, '0'),
                style: TextStyle(color: _green, fontSize: 12),
              ),
              title: Text(
                text(chapters[i]['title']),
                style: const TextStyle(fontSize: 15),
              ),
              trailing: const Icon(Icons.chevron_right, size: 17),
              onTap: () => Navigator.pop(sheet, i),
            ),
        ],
      ),
    );
    if (!mounted || chosen == null) return;
    final anchor = _topicKeys[chosen]?.currentContext;
    if (anchor != null && anchor.mounted)
      await Scrollable.ensureVisible(
        anchor,
        alignment: .04,
        duration: const Duration(milliseconds: 250),
      );
  }

  Future<void> _editNote() => perform(context, () async {
    final latest = await widget.model.api(
      'GET',
      '/api/v1/notes/${_note['id']}',
    );
    if (!mounted) return;
    await push(context, PersonalNoteEditor(widget.model, note: latest));
    await load();
  });

  Future<void> _versions() => perform(context, () async {
    final versions = await widget.model.list(
      '/api/v1/notes/${_note['id']}/versions',
    );
    if (!mounted) return;
    final selected = await _panel<Json>(
      'Version history',
      (sheet) => ListView(
        shrinkWrap: true,
        children: [
          for (final value in versions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Version ${value['selected_revision'] ?? value['revision']}',
              ),
              subtitle: Text(dateLabel(value['updated_at'])),
              trailing:
                  (value['selected_revision'] ?? value['revision']) ==
                      _note['revision']
                  ? const Text('Current', style: TextStyle(fontSize: 11))
                  : null,
              onTap: () => Navigator.pop(sheet, value),
            ),
          if (versions.isEmpty)
            const EmptyState(
              'No saved versions',
              'The current note is available on this page.',
            ),
        ],
      ),
    );
    if (!mounted || selected == null) return;
    await _panel<void>(
      'Version ${selected['selected_revision'] ?? selected['revision']}',
      (_) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text(selected['title']),
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Saved version · ${dateLabel(selected['updated_at'])}',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
            const SizedBox(height: 20),
            ..._document(selected, overviewShown: false, anchors: false),
          ],
        ),
      ),
    );
  });

  Future<void> _share() async {
    await personalShare(context, widget.model, {
      ...record,
      'type': 'recording',
      'id': widget.id,
    }, noteId: notes.isEmpty ? null : text(_note['id']));
    if (mounted) unawaited(_loadRelated(_loadStamp));
  }

  Future<void> _copyExport() async {
    final choice = await _panel<String>(
      'Copy / Export',
      (sheet) => ListView(
        shrinkWrap: true,
        children: [
          if (notes.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy note'),
              onTap: () => Navigator.pop(sheet, 'copy'),
            ),
          if (notes.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Export note'),
              onTap: () => Navigator.pop(sheet, 'note'),
            ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('Export transcript'),
            onTap: () => Navigator.pop(sheet, 'transcript'),
          ),
          ListTile(
            leading: const Icon(Icons.audio_file_outlined),
            title: const Text('Export audio'),
            onTap: () => Navigator.pop(sheet, 'audio'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'copy') {
      await perform(context, () async {
        await Clipboard.setData(
          ClipboardData(text: editableNoteText(object(_note['data']))),
        );
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Note copied')));
      });
      return;
    }
    await showCoreSheet<void>(
      context,
      PersonalExportPage(
        widget.model,
        {...record, 'id': widget.id, 'type': 'recording'},
        noteId: choice == 'note' ? text(_note['id']) : null,
        initialContent: choice,
        sheet: true,
      ),
      height: 560,
    );
  }

  @override
  Future<void> menu(String action) async {
    if (action == 'export') {
      await _copyExport();
      return;
    }
    if (action == 'versions') {
      if (notes.isNotEmpty) await _versions();
      return;
    }
    if (action == 'copy' && !audio) {
      await perform(
        context,
        () => Clipboard.setData(
          ClipboardData(text: editableNoteText(object(_note['data']))),
        ),
      );
      return;
    }
    await super.menu(action);
    if (action == 'move' && mounted) await load();
  }

  Future<void> _source(Json source) async {
    if (source['type'] == 'recording' && source['recording_id'] == widget.id) {
      _tab(true);
      final start = source['start_ms'];
      if (start is num)
        await perform(
          context,
          () => widget.model.host.playback(
            PlaybackAction.play,
            widget.id,
            false,
            start.toInt(),
            1,
          ),
        );
    } else {
      await openPersonalItem(context, widget.model, {
        'type': source['type'],
        'id': source['file_id'] ?? source['note_id'] ?? source['recording_id'],
        'title': source['title'],
      }, source);
    }
  }

  bool _hasOverview(Json note) {
    final data = object(note['data']),
        summary = text(data['summary']).trim(),
        body = text(data['body']).trim();
    if (summary.isEmpty) return false;
    return body.isNotEmpty && body != summary ||
        body.isEmpty &&
            ((data['key_points'] as List? ?? []).isNotEmpty ||
                (data['action_items'] as List? ?? []).isNotEmpty ||
                _chapters(note).isNotEmpty);
  }

  List<Widget> _document(
    Json note, {
    required bool overviewShown,
    required bool anchors,
  }) {
    final data = object(note['data']), body = text(data['body']).trim();
    final sources = rows(data['sources']), chapters = _chapters(note);
    final usedSources = chapters.map((c) => c['source_id']).toSet();
    void showSource(Json source) {
      if (!anchors) Navigator.pop(context);
      unawaited(_source(source));
    }

    final standalone = body.isNotEmpty
        ? body
        : overviewShown
        ? ''
        : text(data['summary']);
    Widget paragraph(String value) => SelectableText(
      value,
      style: TextStyle(fontSize: 15.5, height: 1.85, color: _ink),
    );
    final result = <Widget>[
      if (note['stale'] == true)
        const ErrorNotice(
          'The transcript has changed. This note retains its earlier version.',
        ),
      if (standalone.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: paragraph(standalone),
        ),
    ];
    for (var i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      final source = sources
          .where((s) => s['source_id'] == chapter['source_id'])
          .firstOrNull;
      final sameRevision =
          note['stale'] != true &&
          note['source_revision'] != null &&
          note['source_revision'] == _sourceTranscript['revision'];
      final excerpt =
          source == null ||
              source['type'] != 'recording' ||
              source['recording_id'] != widget.id ||
              !sameRevision
          ? ''
          : text(
              rows(_sourceTranscript['segments'])
                  .where((s) => s['id'] == source['source_id'])
                  .firstOrNull?['text'],
            );
      result.add(
        Container(
          key: anchors ? _topicKeys.putIfAbsent(i, () => GlobalKey()) : null,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: _line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${i + 1}'.padLeft(2, '0'),
                style: TextStyle(
                  color: _green,
                  fontSize: 11,
                  letterSpacing: .6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                text(chapter['title']),
                style: const TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                ),
              ),
              if (excerpt.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.only(left: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: _green.withValues(alpha: .35),
                        width: 2,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transcript excerpt',
                        style: TextStyle(color: _muted, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        excerpt,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.85,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (source != null)
                TextButton.icon(
                  onPressed: () => showSource(source),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.north_east, size: 12),
                  label: const Text('View source'),
                ),
            ],
          ),
        ),
      );
    }
    for (final section in [
      ('key_points', 'Key points'),
      ('action_items', 'Next steps'),
    ]) {
      final values = data[section.$1] as List? ?? [];
      if (values.isEmpty) continue;
      result.add(
        Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 12),
          child: Text(
            section.$2,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
      );
      for (final value in values) {
        final content = value is Map
            ? text(value['title'] ?? value['text'])
            : text(value);
        result.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '•  ',
                  style: TextStyle(fontSize: 15.5, height: 1.85, color: _green),
                ),
                Expanded(child: paragraph(content)),
              ],
            ),
          ),
        );
      }
    }
    final remaining = sources.where(
      (s) => !usedSources.contains(s['source_id']),
    );
    if (remaining.isNotEmpty) {
      result.add(heading('Sources'));
      for (final source in remaining)
        result.add(
          TextButton.icon(
            onPressed: () => showSource(source),
            icon: const Icon(Icons.link, size: 16),
            label: Text(
              source['page'] != null
                  ? 'Page ${source['page']}'
                  : source['start_ms'] is num
                  ? 'Source · ${duration(source['start_ms'])}'
                  : text(source['title']),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
    }
    return result;
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.folder_outlined, size: 14, color: _muted),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                _folderTitle.isEmpty
                    ? (text(record['folder_id']).isEmpty
                          ? 'Recordings'
                          : 'Folder')
                    : _folderTitle,
                style: TextStyle(fontSize: 11.5, color: _muted),
              ),
            ),
            if (_shares != null) ...[
              Icon(
                _shared ? Icons.link : Icons.lock_outline,
                size: 13,
                color: _muted,
              ),
              const SizedBox(width: 4),
              Text(
                _shared ? 'Shared' : 'Private',
                style: TextStyle(fontSize: 11, color: _muted),
              ),
            ],
          ],
        ),
        const SizedBox(height: 11),
        Text(
          text(record['title']),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            height: 1.4,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 7,
          runSpacing: 4,
          children: [
            Text(
              coreDate(record['created_at'], time: true),
              style: TextStyle(fontSize: 11.5, color: _muted),
            ),
            Text('·', style: TextStyle(color: _muted)),
            Text(
              duration(_duration),
              style: TextStyle(fontSize: 11.5, color: _muted),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _notesView() {
    final overview = _hasOverview(_note),
        data = object(_note['data']),
        chapters = _chapters(_note);
    final selectedTitle = text(_note['title']);
    return SingleChildScrollView(
      key: const ValueKey('web-notes-scroll'),
      controller: _noteScroll,
      padding: const EdgeInsets.fromLTRB(21, 22, 21, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._notices(),
          if (record.isNotEmpty) _header(),
          if (overview)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(
                color: _sage,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        size: 15,
                        color: _green,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'At a glance',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    text(data['summary']),
                    style: TextStyle(fontSize: 15, height: 1.8, color: _ink),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'AI-generated · Review key details',
                    style: TextStyle(fontSize: 10, color: _muted),
                  ),
                ],
              ),
            ),
          if (chapters.isNotEmpty)
            InkWell(
              onTap: _topics,
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: _line)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.format_list_bulleted, size: 17),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Topics', style: TextStyle(fontSize: 13)),
                    ),
                    Text(
                      '${chapters.length} ${chapters.length == 1 ? 'topic' : 'topics'}',
                      style: TextStyle(fontSize: 11, color: _muted),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right, size: 15, color: _muted),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (notes.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _chooseNote,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              selectedTitle.isEmpty ||
                                      selectedTitle == text(record['title'])
                                  ? 'Meeting notes'
                                  : selectedTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.keyboard_arrow_down, size: 15),
                        ],
                      ),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _editNote,
                  icon: const Icon(Icons.edit_outlined, size: 13),
                  label: const Text('Edit'),
                ),
              ],
            ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: _line)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 18,
                runSpacing: 0,
                children: [
                  Text(
                    'Full note · v${_note['revision'] ?? 1}',
                    style: TextStyle(fontSize: 11, color: _muted),
                  ),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _versions,
                        child: const Text(
                          'Version',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                      TextButton(
                        onPressed: _copyExport,
                        child: const Text(
                          'Copy / Export',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ..._document(_note, overviewShown: overview, anchors: true),
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Center(
                child: Text(
                  'End of note',
                  style: TextStyle(fontSize: 11, color: _muted),
                ),
              ),
            ),
          ] else if (!loading) ...[
            EmptyState(
              processing['status'] == 'failed'
                  ? 'Summary unavailable'
                  : record['status'] == 'transcribed' &&
                        rows(transcript['segments']).isEmpty
                  ? 'No speech recognized'
                  : 'Preparing your summary',
              'Your audio remains available.',
            ),
            if (rows(transcript['segments']).isNotEmpty)
              Center(
                child: TextButton.icon(
                  onPressed: generate,
                  icon: const Icon(Icons.add),
                  label: const Text('New note'),
                ),
              ),
          ],
          if (rows(metadata['photos']).isNotEmpty) ...[
            heading('Photos'),
            for (final photo in rows(metadata['photos']))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.image_outlined),
                title: Text(text(photo['title'])),
                subtitle: Text(duration(photo['at_ms'])),
                onTap: () => push(
                  context,
                  PersonalFilePage(widget.model, text(photo['id'])),
                ),
              ),
          ],
        ],
      ),
    );
  }

  List<Widget> _notices() => [
    if (loading) const LinearProgressIndicator(minHeight: 2),
    if (error.isNotEmpty) ErrorNotice(error, retry: load),
    if (processing['status'] == 'failed') ...[
      ErrorNotice(text(object(processing['error'])['message'])),
      if (text(processing['job_id']).isNotEmpty)
        TextButton(
          onPressed: () => perform(context, () async {
            await widget.model.api(
              'POST',
              '/api/v1/jobs/${processing['job_id']}/retry',
            );
            await load();
          }),
          child: const Text('Retry processing'),
        ),
    ],
    if (text(processing['message']).isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text(processing['message'])),
      ),
  ];

  Widget _transcriptView() => ListView(
    key: const ValueKey('web-transcript-scroll'),
    controller: _transcriptScroll,
    padding: const EdgeInsets.fromLTRB(21, 22, 21, 28),
    children: [
      ..._notices(),
      if (record.isNotEmpty) _header(),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        children: [
          PopupMenuButton<String>(
            tooltip: 'Transcript version',
            initialValue: variant,
            onSelected: (v) {
              setState(() => variant = v);
              unawaited(load());
            },
            itemBuilder: (_) => [
              for (final item in [
                ('original', 'Original text'),
                ('edited', 'Edited text'),
                ('cleaned', 'Cleaned-up text'),
              ])
                PopupMenuItem(value: item.$1, child: Text(item.$2)),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    {
                      'original': 'Original text',
                      'edited': 'Edited text',
                      'cleaned': 'Cleaned-up text',
                    }[variant]!,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 17),
                ],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: speakers,
            icon: const Icon(Icons.people_outline, size: 16),
            label: const Text('Speakers'),
          ),
        ],
      ),
      Divider(color: _line, height: 12),
      if (variant == 'cleaned' && transcript['available'] == false) ...[
        const Text('Cleaned-up text is not available yet.'),
        TextButton(
          onPressed: () => perform(context, () async {
            final job = await widget.model.api(
              'POST',
              '/api/v1/personal/recordings/${widget.id}/cleanup',
            );
            if (mounted)
              await push(context, PersonalJobPage(widget.model, job));
            await load();
          }),
          child: const Text('Generate cleaned-up text'),
        ),
      ] else ...[
        for (var i = 0; i < rows(transcript['segments']).length; i++)
          segment(rows(transcript['segments'])[i], i),
        if (rows(transcript['segments']).isEmpty && !loading)
          EmptyState(
            record['status'] == 'transcribed'
                ? 'No speech recognized'
                : 'Preparing your transcript',
            'Your audio remains available.',
          ),
      ],
    ],
  );

  Future<void> _togglePlay() async {
    if (_playPending) return;
    setState(() => _playPending = true);
    try {
      await perform(context, () async {
        final p = widget.model.runtime!.playback,
            current = p.mediaId == widget.id;
        final position = current && p.positionMs < _duration ? p.positionMs : 0;
        await widget.model.host.playback(
          current && p.playing ? PlaybackAction.pause : PlaybackAction.play,
          widget.id,
          false,
          position,
          current ? p.speed : 1,
        );
      });
    } finally {
      if (mounted) setState(() => _playPending = false);
    }
  }

  Future<void> _player() => _panel<void>(
    'Audio',
    (_) => SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text(record['title']),
            style: TextStyle(fontSize: 13, color: _muted),
          ),
          PersonalAudioPlayer(
            widget.model,
            widget.id,
            peaks: peaks,
            durationMs: _duration,
          ),
        ],
      ),
    ),
  );

  Widget _dock() => AnimatedBuilder(
    animation: widget.model,
    builder: (context, _) {
      final p = widget.model.runtime!.playback,
          current = p.mediaId == widget.id;
      final position = current ? p.positionMs.clamp(0, _duration) : 0;
      return Container(
        decoration: BoxDecoration(
          color: _paper,
          border: Border(top: BorderSide(color: _line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(21, 10, 21, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (current && p.error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      p.error,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    IconButton.filled(
                      tooltip: current && p.playing
                          ? 'Pause recording'
                          : 'Play recording',
                      style: IconButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: _paper,
                        fixedSize: const Size(44, 44),
                      ),
                      onPressed: _duration <= 0 || _playPending
                          ? null
                          : _togglePlay,
                      icon: _playPending
                          ? SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _paper,
                              ),
                            )
                          : Icon(
                              current && p.playing
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              size: 21,
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Open audio player',
                        child: InkWell(
                          onTap: _player,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 16,
                                  width: double.infinity,
                                  child: CustomPaint(
                                    painter: _Wave(
                                      peaks,
                                      _duration == 0 ? 0 : position / _duration,
                                      _green,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${duration(position)} / ${duration(_duration)}',
                                  style: TextStyle(fontSize: 10, color: _muted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: 28,
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: _line,
                    ),
                    TextButton.icon(
                      onPressed: () => push(
                        context,
                        PersonalChatPage(
                          widget.model,
                          initial: [
                            {'type': 'recording', 'id': widget.id},
                          ],
                        ),
                      ),
                      icon: const Icon(Icons.auto_awesome_outlined, size: 15),
                      label: const Text(
                        'Ask Teno',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: _theme,
    child: Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        backgroundColor: _paper,
        foregroundColor: _ink,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 52,
        leading: IconButton(
          tooltip: 'Back to library',
          icon: const Icon(Icons.chevron_left, size: 25),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Teno',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Share recording',
            icon: const Icon(Icons.ios_share_outlined, size: 21),
            onPressed: loading ? null : _share,
          ),
          PopupMenuButton<String>(
            tooltip: 'Recording options',
            icon: const Icon(Icons.more_horiz, size: 23),
            onSelected: menu,
            itemBuilder: (_) => [
              for (final item in [
                ('rename', 'Rename'),
                ('move', 'Move to folder'),
                ('generate', 'New note'),
                if (notes.isNotEmpty) ('versions', 'Version history'),
                ('speakers', 'Name speakers'),
                ('transcribe', 'Transcribe again'),
                ('replace', 'Find & replace'),
                ('trim', 'Trim audio'),
                if (audio)
                  ('follow', follow ? 'Stop following audio' : 'Follow audio'),
                ('copy', 'Copy to clipboard'),
                ('export', 'Export as'),
                ('trash', 'Move to trash'),
              ])
                PopupMenuItem(value: item.$1, child: Text(item.$2)),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: _line)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final tab in [
                        (false, 'Notes'),
                        (true, 'Transcript'),
                      ])
                        Semantics(
                          selected: audio == tab.$1,
                          button: true,
                          child: InkWell(
                            onTap: () => _tab(tab.$1),
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 100,
                                minHeight: 44,
                              ),
                              padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    tab.$2,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: audio == tab.$1 ? _ink : _muted,
                                      fontWeight: audio == tab.$1
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: 32,
                                    height: 2,
                                    color: audio == tab.$1
                                        ? _green
                                        : Colors.transparent,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(child: audio ? _transcriptView() : _notesView()),
                _dock(),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _loadStamp++;
    _noteScroll.dispose();
    _transcriptScroll.dispose();
    super.dispose();
  }
}
