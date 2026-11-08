import 'dart:async';
import 'package:flutter/material.dart';
import '../core/model.dart';
import 'widgets.dart' show ErrorNotice;

// Measured shared geometry; system bars and native pickers remain Android-owned.
const coreInset = 24.0;
const coreBlue = Color(0xFF3478D4);

ThemeData personalTheme(bool dark, {bool webExperience = false}) {
  final surface = dark ? const Color(0xFF171719) : const Color(0xFFF8F8F8);
  final ink = dark ? const Color(0xFFF1F1F3) : const Color(0xFF080808);
  final colors =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF307ACB),
        brightness: dark ? Brightness.dark : Brightness.light,
      ).copyWith(
        surface: surface,
        onSurface: ink,
        onSurfaceVariant: dark
            ? const Color(0xFFA5A5A8)
            : const Color(0xFF808080),
        primary: ink,
        onPrimary: surface,
        outlineVariant: dark
            ? const Color(0xFF414548)
            : const Color(0xFFE4E4E4),
        secondaryContainer: dark
            ? const Color(0xFF303335)
            : const Color(0xFFEAEAEA),
        surfaceContainerHighest: dark
            ? const Color(0xFF303033)
            : const Color(0xFFEAEAEA),
        surfaceContainerLowest: dark ? const Color(0xFF202023) : Colors.white,
        onSecondaryContainer: ink,
        surfaceContainerLow: dark
            ? const Color(0xFF23272A)
            : const Color(0xFFF0F0F0),
        surfaceTint: Colors.transparent,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: surface,
    fontFamily: 'Inter',
    fontFamilyFallback: webExperience ? const ['NotoSansSC'] : null,
    textTheme: TextTheme(
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.4,
        letterSpacing: 0,
        color: ink,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.4,
        letterSpacing: 0,
        color: ink,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.35,
        color: colors.onSurfaceVariant,
      ),
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
      toolbarHeight: 76,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
    ),
    dividerColor: colors.outlineVariant,
    popupMenuTheme: PopupMenuThemeData(
      color: colors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: .12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
        side: BorderSide(color: colors.outlineVariant, width: .7),
      ),
      textStyle: TextStyle(fontFamily: 'Inter', fontSize: 14, color: ink),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF24272A) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
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
    style: const TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w600,
      height: 1.25,
    ),
  ),
);

class CoreSurface extends StatelessWidget {
  const CoreSurface({
    super.key,
    required this.child,
    this.radius = 28,
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
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.surfaceContainerLowest, colors.surface],
        ),
        border: Border.all(color: colors.outlineVariant, width: .7),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
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
  Widget build(BuildContext context) => Align(
    widthFactor: 1,
    heightFactor: 1,
    child: Tooltip(
      message: label,
      child: SizedBox(
        width: size,
        height: size,
        child: CoreSurface(
          radius: size / 2,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: onPressed,
            icon: Icon(
              icon,
              size: 23,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    ),
  );
}

Future<T?> showCoreSheet<T>(
  BuildContext context,
  Widget child, {
  double height = 560,
  bool edgeToEdge = false,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  showDragHandle: false,
  barrierColor: Colors.black.withValues(alpha: .20),
  builder: (sheet) {
    final media = MediaQuery.of(sheet);
    final available =
        media.size.height - media.padding.top - media.viewInsets.bottom - 16;
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
        child: ClipRRect(borderRadius: BorderRadius.circular(30), child: child),
      ),
    );
  },
);

String coreDate(dynamic value, {bool weekday = false, bool time = false}) {
  final d = DateTime.tryParse(text(value))?.toLocal();
  if (d == null) return '';
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
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final day = '${months[d.month - 1]} ${d.day}';
  final clock =
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  return weekday
      ? '${days[d.weekday - 1]}, $day'
      : time
      ? '$day at $clock'
      : day;
}

String coreDuration(dynamic milliseconds) {
  final seconds = ((milliseconds as num? ?? 0) / 1000).floor();
  return seconds < 60
      ? '${seconds}s'
      : seconds < 3600
      ? '${seconds ~/ 60}m'
      : '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
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
  });
  final String title;
  final Widget child;
  final List<Widget> actions;
  final Widget? bottom;
  final bool sheet, close, sheetDone;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: sheet
        ? Theme.of(context).colorScheme.surfaceContainerLowest
        : null,
    appBar: AppBar(
      backgroundColor: sheet
          ? Theme.of(context).colorScheme.surfaceContainerLowest
          : null,
      toolbarHeight: sheet ? 64 : 76,
      leadingWidth: sheet ? 16 : 68,
      leading: Padding(
        padding: const EdgeInsets.all(12),
        child: sheet
            ? const SizedBox.shrink()
            : CoreAction(
                close ? Icons.close : Icons.arrow_back_ios_new_rounded,
                close ? 'Close' : 'Back',
                () => Navigator.pop(context),
              ),
      ),
      title: Text(title),
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
              child: const Text('Done'),
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
    body: SafeArea(top: false, child: child),
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
          if (showIcon && !showFolder) ...[
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
                      ? 'Untitled'
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
                    ),
                    if (item['duration_ms'] != null)
                      coreDuration(item['duration_ms']),
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
                            text(item['folder_title']).isEmpty
                                ? 'Recordings'
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
                    recordingStatus(item['status']),
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
      radius: 32,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
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
