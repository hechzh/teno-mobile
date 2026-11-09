part of 'personal_recording.dart';

// Shared personal Notes presentation. Native and Web use the same version-safe
// content rendering; browser caches remain an optional runtime capability.
class _WebRecordingPageState extends _PersonalRecordingPageState {
  final _noteScroll = ScrollController(),
      _transcriptScroll = ScrollController();
  final _topicKeys = <int, GlobalKey>{};
  bool _transcriptTab = false, _playPending = false;
  int _loadStamp = 0;
  String _selectedNote = '', _folderTitle = '';
  List<Json>? _shares;
  Json _sourceTranscript = {};
  String _cacheStatus = '', _visibleVariant = '', _accountScope = '';

  @override
  bool get audio => _transcriptTab;
  Color get _paper => Theme.of(context).colorScheme.surface;
  Color get _ink => Theme.of(context).colorScheme.onSurface;
  Color get _muted => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _green => Theme.of(context).colorScheme.primary;
  Color get _sage => Theme.of(context).colorScheme.surfaceContainerLow;
  Color get _line => Theme.of(context).colorScheme.outlineVariant;
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
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontFamilyFallback: ['NotoSansSC'],
          fontSize: 13,
        ),
      ),
    ),
  );

  @override
  void initState() {
    _transcriptTab = widget.transcriptOnly || widget.seekMs != null;
    _accountScope = widget.model.runtime?.session.scope ?? '';
    super.initState();
  }

  @override
  void playbackChanged() {
    if (!mounted) return;
    if (_accountScope != (widget.model.runtime?.session.scope ?? '')) {
      ++_loadStamp;
      timer?.cancel();
      setState(() {
        record = {};
        transcript = {};
        metadata = {};
        processing = {};
        notes = [];
        peaks = [];
        _sourceTranscript = {};
        _shares = null;
        loading = false;
        _cacheStatus = '';
        error = 'Account changed. Open this recording again.';
      });
      return;
    }
    super.playbackChanged();
  }

  void _applyContent(Json value, String requestedVariant) {
    record = object(value['record']);
    transcript = object(value['transcript']);
    notes = rows(value['notes']);
    metadata = object(value['metadata']);
    processing = object(value['processing']);
    _visibleVariant = requestedVariant;
    loading = false;
    error = '';
    final selected = notes.indexWhere((n) => n['id'] == _selectedNote);
    noteIndex = selected < 0 ? 0 : selected;
    _selectedNote = text(_note['id']);
    if (requestedVariant == 'edited') _sourceTranscript = transcript;
  }

  Future<Json> _readCache(String requestedVariant) async {
    if (!widget.model.webExperience) return {};
    try {
      return await widget.model.command('recording_cache', {
        'action': 'read',
        'id': widget.id,
        'variant': requestedVariant,
      });
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveCache(
    int stamp,
    String requestedVariant,
    Future<Json> cached,
  ) async {
    try {
      final cache = await cached;
      if (!mounted || stamp != _loadStamp || text(cache['token']).isEmpty)
        return;
      await widget.model.command('recording_cache', {
        'action': 'write',
        'id': widget.id,
        'variant': requestedVariant,
        'token': cache['token'],
        'value': {
          'record': record,
          'transcript': transcript,
          'notes': notes,
          'metadata': metadata,
          'processing': processing,
          'peaks': peaks,
        },
      });
    } catch (_) {
      /* Reading cloud data must not depend on browser storage. */
    }
  }

  @override
  Future<void> load() async {
    timer?.cancel();
    final stamp = ++_loadStamp, requestedVariant = variant;
    var networkDone = false;
    final cached = _readCache(requestedVariant);
    if (_visibleVariant != requestedVariant) transcript = {};
    // Start storage and network together. Slow/blocked IndexedDB cannot delay
    // the server, and a late cache read cannot overwrite a fresh response.
    unawaited(
      cached.then((cache) {
        final value = object(cache['value']);
        if (!mounted ||
            stamp != _loadStamp ||
            networkDone ||
            _accountScope != widget.model.runtime?.session.scope ||
            object(value['record'])['id'] != widget.id ||
            record.isNotEmpty && _visibleVariant == requestedVariant)
          return;
        setState(() {
          _applyContent(value, requestedVariant);
          peaks = (value['peaks'] as List? ?? [])
              .whereType<num>()
              .map((v) => v.toDouble())
              .toList();
          _cacheStatus = 'Saved copy · Checking for updates…';
        });
      }),
    );
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
      networkDone = true;
      if (!mounted || stamp != _loadStamp) return;
      setState(() {
        if (record['revision'] != values[0]['revision'] ||
            record['duration_ms'] != values[0]['duration_ms'])
          peaks = [];
        _applyContent({
          'record': values[0],
          'transcript': values[1],
          'notes': values[2]['items'],
          'metadata': values[3],
          'processing': values[4],
        }, requestedVariant);
        _cacheStatus = '';
      });
      unawaited(_saveCache(stamp, requestedVariant, cached));
      unawaited(
        _loadRelated(
          stamp,
        ).then((_) => _saveCache(stamp, requestedVariant, cached)),
      );
      if (processing['status'] == 'processing')
        timer = Timer(const Duration(seconds: 6), load);
      if (audio) playbackChanged();
    } catch (e) {
      if (!e.toString().contains('RECORDING_UNAVAILABLE')) {
        // A failed offline fetch can finish before IndexedDB opens.
        await cached.timeout(
          const Duration(milliseconds: 500),
          onTimeout: () => <String, dynamic>{},
        );
      }
      networkDone = true;
      if (mounted && stamp == _loadStamp)
        setState(() {
          if (e.toString().contains('RECORDING_UNAVAILABLE')) {
            record = {};
            transcript = {};
            notes = [];
            metadata = {};
            processing = {};
            peaks = [];
            _sourceTranscript = {};
            _shares = null;
            _cacheStatus = '';
            error = 'This recording is no longer available.';
          } else {
            _cacheStatus = record.isEmpty
                ? ''
                : 'Saved copy · Could not check for updates';
            error = TenoModel.friendly(e);
          }
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
          ? ui(context, 'Recordings')
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
      showCoreSheet<T>(
        context,
        Theme(
          data: _theme,
          child: Builder(
            builder: (sheet) => CoreFrame(
              title: title,
              sheet: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: content(sheet),
              ),
            ),
          ),
        ),
        height: MediaQuery.sizeOf(context).height * .78,
        edgeToEdge: true,
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
                subtitle: Text(
                  context.strings.versionLabel(text(note['revision'] ?? 1)),
                ),
                trailing: note['id'] == _note['id']
                    ? Icon(Icons.check, color: _green, size: 18)
                    : null,
                onTap: () => Navigator.pop(sheet, text(note['id'])),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add),
              title: const UiText('New note'),
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
              context.strings.topicCount(chapters.length),
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
                context.strings.versionLabel(
                  text(value['selected_revision'] ?? value['revision']),
                ),
              ),
              subtitle: Text(dateLabel(value['updated_at'])),
              trailing:
                  (value['selected_revision'] ?? value['revision']) ==
                      _note['revision']
                  ? const UiText('Current', style: TextStyle(fontSize: 11))
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
      context.strings.versionLabel(
        text(selected['selected_revision'] ?? selected['revision']),
      ),
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
              context.strings.savedVersionDate(
                coreDate(selected['updated_at'], context: context),
              ),
              style: TextStyle(fontSize: 12, color: _muted),
            ),
            const SizedBox(height: 20),
            ..._document(selected, overviewShown: false, anchors: false),
          ],
        ),
      ),
    );
  });

  Future<void> _share() => _shareCenter(includeLink: true);
  Future<void> _copyExport() => _shareCenter(includeLink: false);

  Future<void> _shareCenter({required bool includeLink}) async {
    final choice = await _panel<String>(
      includeLink ? 'Share' : 'Copy / Export',
      (sheet) => ListView(
        shrinkWrap: true,
        children: [
          if (includeLink) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link),
              title: const UiText('Share link'),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => Navigator.pop(sheet, 'link'),
            ),
            const Divider(),
          ],
          heading('Copy to clipboard'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.copy_outlined),
            title: const UiText('Copy transcript'),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => Navigator.pop(sheet, 'copy-transcript'),
          ),
          if (notes.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.copy_outlined),
              title: const UiText('Copy note'),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => Navigator.pop(sheet, 'copy'),
            ),
          heading('Export files'),
          for (final entry in [
            ('audio', 'Export audio', Icons.graphic_eq),
            ('transcript', 'Export transcript', Icons.article_outlined),
            if (notes.isNotEmpty)
              ('note', 'Export note', Icons.description_outlined),
          ])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(entry.$3),
              title: UiText(entry.$2),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => Navigator.pop(sheet, entry.$1),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.pop(sheet),
            child: const UiText('Cancel'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'link') {
      await personalShare(context, widget.model, {
        ...record,
        'type': 'recording',
        'id': widget.id,
      }, noteId: notes.isEmpty ? null : text(_note['id']));
      if (mounted) unawaited(_loadRelated(_loadStamp));
      return;
    }
    if (choice == 'copy' || choice == 'copy-transcript') {
      await perform(context, () async {
        final value = choice == 'copy'
            ? editableNoteText(object(_note['data']))
            : rows(transcript['segments'])
                  .map(
                    (s) =>
                        '${coreTimestamp(s['start_ms'])} ${text(s['speaker_name'] ?? s['speaker'])}\n${text(s['text'])}',
                  )
                  .join('\n\n');
        await Clipboard.setData(ClipboardData(text: value));
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: UiText(
                choice == 'copy' ? 'Note copied' : 'Transcript copied',
              ),
            ),
          );
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
  Future<void> generate() async {
    final template = await push<String>(
      context,
      PersonalTemplatePicker(widget.model, allowTranscript: true),
    );
    if (!mounted || template == null) return;
    if (template == '__transcript__') {
      _tab(true);
      return;
    }
    await perform(context, () async {
      final job = await widget.model.api('POST', '$path/notes', {
        'client_id': requestId(),
        if (template.isNotEmpty) 'template_id': template,
      });
      if (mounted) await push(context, PersonalJobPage(widget.model, job));
      await load();
    });
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
    final narrative =
        data['schema_version'] == 'personal-notes-v2' &&
        chapters.isNotEmpty &&
        chapters.every((chapter) => text(chapter['body']).trim().isNotEmpty);
    final usedSources = chapters.map((c) => c['source_id']).toSet();
    void showSource(Json source) {
      if (!anchors) Navigator.pop(context);
      unawaited(_source(source));
    }

    final standalone = narrative
        ? (overviewShown ? '' : text(data['summary']))
        : body.isNotEmpty
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
              if (narrative) ...[
                const SizedBox(height: 12),
                paragraph(text(chapter['body'])),
              ],
              if (!narrative && excerpt.isNotEmpty) ...[
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
                      UiText(
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
                  label: const UiText('View source'),
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
                UiText(
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
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text(record['title']),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              coreDate(record['created_at'], time: true, context: context),
              style: TextStyle(fontSize: 12, color: _muted),
            ),
            Text(
              '· ${duration(_duration)}',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
            if (_shares != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _shared ? Icons.link : Icons.lock_outline,
                    size: 14,
                    color: _muted,
                  ),
                  const SizedBox(width: 4),
                  UiText(
                    _shared ? 'Shared' : 'Private',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
          ],
        ),
        if (_folderTitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _folderTitle,
              style: TextStyle(fontSize: 12, color: _muted),
            ),
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
          if (notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _chooseNote,
                    icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                    label: Text(
                      selectedTitle.isEmpty ||
                              selectedTitle == text(record['title'])
                          ? ui(context, 'Meeting notes')
                          : selectedTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: generate,
                    icon: const Icon(Icons.add, size: 18),
                    label: const UiText('New note'),
                  ),
                  TextButton(
                    onPressed: _versions,
                    child: const UiText('Version'),
                  ),
                ],
              ),
            ),
          if (overview)
            Row(
              children: [
                const Expanded(
                  child: UiText(
                    'Overview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(onPressed: _editNote, child: const UiText('Edit')),
              ],
            ),
          if (overview) const SizedBox(height: 12),
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
                  SelectableText(
                    text(data['summary']),
                    style: TextStyle(fontSize: 15, height: 1.8, color: _ink),
                  ),
                  const SizedBox(height: 12),
                  UiText(
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
                      child: UiText('Topics', style: TextStyle(fontSize: 13)),
                    ),
                    Text(
                      context.strings.topicCount(chapters.length),
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
                const Expanded(
                  child: UiText(
                    'Full meeting notes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: _copyExport,
                  child: const UiText('Copy / Export'),
                ),
                if (!overview)
                  IconButton(
                    onPressed: _editNote,
                    tooltip: ui(context, 'Edit'),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
              ],
            ),
            Text(
              context.strings.fullNoteVersion(text(_note['revision'] ?? 1)),
              style: TextStyle(fontSize: 12, color: _muted),
            ),
            const SizedBox(height: 16),
            ..._document(_note, overviewShown: overview, anchors: true),
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Center(
                child: UiText(
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
                  label: const UiText('New note'),
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
    if (_cacheStatus.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          _cacheStatus,
          style: TextStyle(fontSize: 12, color: _muted),
        ),
      ),
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
          child: const UiText('Retry processing'),
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
            tooltip: ui(context, 'Transcript version'),
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
                PopupMenuItem(value: item.$1, child: UiText(item.$2)),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UiText(
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
            label: const UiText('Speakers'),
          ),
        ],
      ),
      Divider(color: _line, height: 12),
      if (variant == 'cleaned' && transcript['available'] == false) ...[
        const UiText('Cleaned-up text is not available yet.'),
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
          child: const UiText('Generate cleaned-up text'),
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
                      tooltip: ui(
                        context,
                        current && p.playing
                            ? 'Pause recording'
                            : 'Play recording',
                      ),
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
                        label: ui(context, 'Open audio player'),
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
                      label: const UiText(
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

  Widget _tabs() => Row(
    children: [
      for (final tab in [(true, 'Source'), (false, 'Notes')])
        Expanded(
          child: Semantics(
            selected: audio == tab.$1,
            button: true,
            child: InkWell(
              onTap: () => _tab(tab.$1),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UiText(
                      tab.$2,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: audio == tab.$1 ? _ink : _muted,
                        fontWeight: audio == tab.$1
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 32,
                      height: 2,
                      color: audio == tab.$1 ? _green : Colors.transparent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
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
        toolbarHeight: MediaQuery.textScalerOf(context).scale(1) > 1.2
            ? 72
            : 60,
        leadingWidth: 48,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: ui(context, 'Back to library'),
          icon: const Icon(Icons.chevron_left, size: 25),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: SizedBox(width: 280, child: _tabs()),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: ui(context, 'Share recording'),
            icon: const Icon(Icons.ios_share_outlined, size: 21),
            onPressed: loading ? null : _share,
          ),
          PopupMenuButton<String>(
            tooltip: ui(context, 'Recording options'),
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
                PopupMenuItem(value: item.$1, child: UiText(item.$2)),
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
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width >= 1100 ? 980 : 760,
            ),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: audio ? _transcriptView() : _notesView()),
                      if (!audio &&
                          MediaQuery.sizeOf(context).width >= 1100 &&
                          _chapters(_note).isNotEmpty)
                        Container(
                          width: 230,
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                          decoration: BoxDecoration(
                            border: Border(left: BorderSide(color: _line)),
                          ),
                          child: ListView(
                            children: [
                              const UiText(
                                'Topics',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              for (var i = 0; i < _chapters(_note).length; i++)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    text(_chapters(_note)[i]['title']),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  onTap: () {
                                    final anchor =
                                        _topicKeys[i]?.currentContext;
                                    if (anchor != null)
                                      Scrollable.ensureVisible(
                                        anchor,
                                        alignment: .04,
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                      );
                                  },
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
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
