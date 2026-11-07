import 'dart:async';
import 'package:flutter/material.dart';
import '../core/model.dart';
import 'widgets.dart' show CircleAction, ErrorNotice;

ThemeData personalTheme(bool dark) {
  final surface = dark ? const Color(0xFF17191B) : const Color(0xFFFAFBFB);
  final ink = dark ? const Color(0xFFF1F2F3) : const Color(0xFF151719);
  final colors =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF307ACB),
        brightness: dark ? Brightness.dark : Brightness.light,
      ).copyWith(
        surface: surface,
        onSurface: ink,
        primary: ink,
        onPrimary: surface,
        outlineVariant: dark
            ? const Color(0xFF414548)
            : const Color(0xFFDFE1E2),
        secondaryContainer: dark
            ? const Color(0xFF303335)
            : const Color(0xFFECEEEF),
        onSecondaryContainer: ink,
        surfaceContainerLow: dark
            ? const Color(0xFF23272A)
            : const Color(0xFFF1F4F6),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: surface,
    fontFamily: 'Inter',
    textTheme: TextTheme(
      bodyMedium: TextStyle(fontSize: 14, height: 1.55, color: ink),
      bodyLarge: TextStyle(fontSize: 15, height: 1.55, color: ink),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(
        dark ? const Color(0xFFEDEFF0) : Colors.white,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? const Color(0xFF327BCC)
            : dark
            ? const Color(0xFF4B5055)
            : const Color(0xFFDDE0E2),
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: colors.secondaryContainer,
      backgroundColor: surface,
      showCheckmark: false,
      side: BorderSide(color: colors.outlineVariant),
      labelStyle: TextStyle(fontFamily: 'Inter', fontSize: 12, color: ink),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF24272A) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
    ),
  );
}

Color subtle(BuildContext c) => Theme.of(c).colorScheme.onSurfaceVariant;
Widget heading(String text) => Padding(
  padding: const EdgeInsets.only(top: 20, bottom: 12),
  child: Text(
    text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  ),
);

class CoreFrame extends StatelessWidget {
  const CoreFrame({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.bottom,
  });
  final String title;
  final Widget child;
  final List<Widget> actions;
  final Widget? bottom;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leadingWidth: 60,
      leading: Padding(
        padding: const EdgeInsets.all(7),
        child: CircleAction(
          Icons.arrow_back_ios_new_rounded,
          'Back',
          () => Navigator.pop(context),
        ),
      ),
      title: Text(title),
      actions: [...actions, const SizedBox(width: 12)],
    ),
    body: SafeArea(top: false, child: child),
    bottomNavigationBar: bottom == null
        ? null
        : SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
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
  });
  final Json item;
  final VoidCallback open;
  final bool? selected;
  final VoidCallback? select;
  final String? snippet;
  final String? highlight;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: selected == null ? open : select,
    onLongPress: select,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selected != null) ...[
            Icon(
              selected! ? Icons.check_circle : Icons.circle_outlined,
              size: 22,
            ),
            const SizedBox(width: 13),
          ],
          if (selected == null && item['type'] != 'recording') ...[
            Icon(itemIcon(item), size: 20, color: subtle(context)),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                highlightedText(
                  context,
                  text(item['title']).isEmpty
                      ? 'Untitled'
                      : text(item['title']),
                  highlight,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  dateLabel(item['created_at']) +
                      (item['duration_ms'] == null
                          ? ''
                          : ' · ' + duration(item['duration_ms'])),
                  style: TextStyle(fontSize: 11, color: subtle(context)),
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
                    recordingStatus(item['status']),
                    style: TextStyle(fontSize: 11, color: subtle(context)),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
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
        style: const TextStyle(
          backgroundColor: Color(0xFFFFE9A3),
          color: Color(0xFF151719),
        ),
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
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: subtle(context)),
            ),
          ),
          const Icon(Icons.tune, size: 19),
        ],
      ),
    ),
  );
}
