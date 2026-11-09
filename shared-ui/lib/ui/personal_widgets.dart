import 'dart:async';
import 'package:flutter/material.dart';
import '../core/model.dart';
import '../l10n/ui_strings.dart';
import 'mvp_theme.dart';
import 'widgets.dart' show ErrorNotice;

// Measured shared geometry; system bars and native pickers remain Android-owned.
const coreInset = 20.0;
const coreBlue = Color(0xFF356448);

ThemeData personalTheme(bool dark, {bool webExperience = false}) =>
    mvpTheme(dark);

Color subtle(BuildContext c) => Theme.of(c).colorScheme.onSurfaceVariant;
Widget heading(String text, {bool localize = true}) => Padding(
  padding: const EdgeInsets.only(top: 20, bottom: 12),
  child: Builder(
    builder: (context) => Text(
      localize ? ui(context, text) : text,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        height: 1.25,
      ),
    ),
  ),
);

class CoreSurface extends StatelessWidget {
  const CoreSurface({
    super.key,
    required this.child,
    this.radius = 14,
    this.padding = EdgeInsets.zero,
  });
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant, width: .7),
      ),
      child: child,
    );
  }
}

class CoreAction extends StatelessWidget {
  const CoreAction(
    this.icon,
    this.label,
    this.onPressed, {
    super.key,
    this.size = 44,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size < 44 ? 44 : size,
    height: size < 44 ? 44 : size,
    child: IconButton(
      tooltip: ui(context, label),
      onPressed: onPressed,
      icon: Icon(icon, size: 23),
    ),
  );
}

Future<T?> showCoreSheet<T>(
  BuildContext context,
  Widget child, {
  double height = 560,
  bool edgeToEdge = false,
}) {
  if (MediaQuery.sizeOf(context).width >= 900) {
    return showDialog<T>(
      context: context,
      builder: (dialog) => Dialog(
        child: SizedBox(
          width: 560,
          height: height.clamp(0, MediaQuery.sizeOf(dialog).height - 80),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: child,
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    showDragHandle: false,
    barrierColor: Colors.black.withValues(alpha: .20),
    builder: (sheet) {
      final media = MediaQuery.of(sheet);
      final available =
          (media.size.height - media.padding.top - media.viewInsets.bottom - 16)
              .clamp(0.0, double.infinity);
      final wanted = media.textScaler.scale(1) > 1.2 ? available : height;
      return Padding(
        padding: EdgeInsets.fromLTRB(
          edgeToEdge ? 0 : 8,
          0,
          edgeToEdge ? 0 : 8,
          (edgeToEdge ? 0 : 8) + media.viewInsets.bottom,
        ),
        child: SizedBox(
          height: wanted.clamp(0, available),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: child,
          ),
        ),
      );
    },
  );
}

String coreDate(
  dynamic value, {
  bool weekday = false,
  bool time = false,
  BuildContext? context,
}) {
  final d = DateTime.tryParse(text(value))?.toLocal();
  if (d == null) return '';
  if (context == null)
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}${time ? ' ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}' : ''}';
  final local = MaterialLocalizations.of(context);
  final date = weekday ? local.formatFullDate(d) : local.formatMediumDate(d);
  return time
      ? '$date · ${local.formatTimeOfDay(TimeOfDay.fromDateTime(d), alwaysUse24HourFormat: true)}'
      : date;
}

String coreDuration(dynamic milliseconds, {BuildContext? context}) {
  final seconds = ((milliseconds as num? ?? 0) / 1000).floor();
  final chinese =
      context != null &&
      Localizations.maybeLocaleOf(context)?.languageCode == 'zh';
  return seconds < 60
      ? '$seconds${chinese ? '秒' : 's'}'
      : seconds < 3600
      ? '${seconds ~/ 60}${chinese ? '分钟' : 'm'}'
      : '${seconds ~/ 3600}${chinese ? '小时' : 'h'} ${(seconds % 3600) ~/ 60}${chinese ? '分钟' : 'm'}';
}

String coreTimestamp(dynamic milliseconds) {
  final seconds = ((milliseconds as num? ?? 0) / 1000).floor().clamp(
    0,
    9999999,
  );
  return '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class CoreFrame extends StatelessWidget {
  const CoreFrame({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.bottom,
    this.sheet = false,
    this.close = false,
    this.sheetDone = false,
    this.showBack = true,
    this.localizeTitle = true,
  });
  final String title;
  final Widget child;
  final List<Widget> actions;
  final Widget? bottom;
  final bool sheet, close, sheetDone, showBack, localizeTitle;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: sheet
        ? Theme.of(context).colorScheme.surfaceContainerLowest
        : null,
    appBar: AppBar(
      backgroundColor: sheet
          ? Theme.of(context).colorScheme.surfaceContainerLowest
          : null,
      toolbarHeight: 60,
      automaticallyImplyLeading: false,
      leadingWidth: sheet || !showBack ? 16 : 56,
      leading: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: sheet || !showBack
            ? const SizedBox.shrink()
            : CoreAction(
                close ? Icons.close : Icons.arrow_back_ios_new_rounded,
                close ? 'Close' : 'Back',
                () => Navigator.pop(context),
              ),
      ),
      title: localizeTitle ? UiText(title) : Text(title),
      actions: [
        ...actions,
        if (sheetDone)
          Center(
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(68, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.pop(context),
              child: const UiText('Done'),
            ),
          ),
        if (sheet && !sheetDone)
          CoreAction(
            Icons.close,
            'Close',
            () => Navigator.pop(context),
            size: 36,
          ),
        const SizedBox(width: 16),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: child,
        ),
      ),
    ),
    bottomNavigationBar: bottom == null
        ? null
        : SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: bottom,
            ),
          ),
  );
}

class CoreLoad extends StatefulWidget {
  const CoreLoad({super.key, required this.load, required this.builder});
  final Future<Json> Function() load;
  final Widget Function(BuildContext, Json, VoidCallback) builder;
  @override
  State<CoreLoad> createState() => _CoreLoadState();
}

class _CoreLoadState extends State<CoreLoad> {
  late Future<Json> future;
  @override
  void initState() {
    super.initState();
    future = widget.load();
  }

  @override
  void didUpdateWidget(CoreLoad old) {
    super.didUpdateWidget(old);
  }

  void reload() {
    if (mounted) setState(() => future = widget.load());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
    future: future,
    builder: (context, snap) {
      if (snap.hasError)
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ErrorNotice(TenoModel.friendly(snap.error!), retry: reload),
          ],
        );
      if (!snap.hasData)
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      return widget.builder(context, snap.data!, reload);
    },
  );
}

IconData itemIcon(Json item) => switch (text(item['type'])) {
  'folder' => Icons.folder_outlined,
  'note' => Icons.article_outlined,
  'file' =>
    item['kind'] == 'image' ? Icons.image_outlined : Icons.description_outlined,
  _ => Icons.mic_none_rounded,
};

class CoreTile extends StatelessWidget {
  const CoreTile(
    this.item,
    this.open, {
    super.key,
    this.selected,
    this.select,
    this.snippet,
    this.trailing,
    this.highlight,
    this.showFolder = false,
    this.showIcon = true,
  });
  final Json item;
  final VoidCallback open;
  final bool? selected;
  final VoidCallback? select;
  final String? snippet;
  final String? highlight;
  final Widget? trailing;
  final bool showFolder, showIcon;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: selected == null ? open : select,
    onLongPress: select,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showIcon) ...[
            Icon(itemIcon(item), size: 23, color: subtle(context)),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                highlightedText(
                  context,
                  text(item['title']).isEmpty
                      ? ui(context, 'Untitled')
                      : text(item['title']),
                  highlight,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    coreDate(
                      item['content_updated_at'] ?? item['created_at'],
                      time: true,
                      context: context,
                    ),
                    if (item['duration_ms'] != null)
                      coreDuration(item['duration_ms'], context: context),
                    if (item['child_count'] != null)
                      '${item['child_count']} items',
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: TextStyle(fontSize: 12, color: subtle(context)),
                ),
                if (showFolder)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 15,
                          color: subtle(context),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            text(item['folder_id']).isEmpty ||
                                    text(item['folder_title']).isEmpty
                                ? ui(context, 'Recordings')
                                : text(item['folder_title']),
                            style: TextStyle(
                              fontSize: 13,
                              color: subtle(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (snippet != null)
                  highlightedText(
                    context,
                    snippet!,
                    highlight,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: subtle(context)),
                  ),
                if (item['status'] != null &&
                    !['ready', 'transcribed'].contains(item['status']))
                  Text(
                    ui(context, recordingStatus(item['status'])),
                    style: TextStyle(fontSize: 11, color: subtle(context)),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (selected != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 3),
              child: Icon(
                selected! ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
              ),
            ),
        ],
      ),
    ),
  );
}

Widget highlightedText(
  BuildContext context,
  String value,
  String? query, {
  TextStyle? style,
  int? maxLines,
  TextOverflow? overflow,
}) {
  if (query == null || query.isEmpty)
    return Text(value, style: style, maxLines: maxLines, overflow: overflow);
  final spans = <TextSpan>[];
  var offset = 0;
  for (final match in RegExp(
    RegExp.escape(query),
    caseSensitive: false,
  ).allMatches(value)) {
    if (match.start > offset)
      spans.add(TextSpan(text: value.substring(offset, match.start)));
    spans.add(
      TextSpan(
        text: value.substring(match.start, match.end),
        style: const TextStyle(color: coreBlue),
      ),
    );
    offset = match.end;
  }
  if (offset < value.length) spans.add(TextSpan(text: value.substring(offset)));
  return Text.rich(
    TextSpan(children: spans),
    style: style,
    maxLines: maxLines,
    overflow: overflow,
  );
}

class AskBar extends StatelessWidget {
  const AskBar(
    this.open, {
    super.key,
    this.label = 'Ask me anything about your recordings',
  });
  final VoidCallback open;
  final String label;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: open,
    borderRadius: BorderRadius.circular(30),
    child: CoreSurface(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      child: Row(
        children: [
          Expanded(
            child: Text(
              ui(context, label),
              maxLines: MediaQuery.textScalerOf(context).scale(1) > 1.2 ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: subtle(context)),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.checklist_rounded, size: 23),
        ],
      ),
    ),
  );
}
