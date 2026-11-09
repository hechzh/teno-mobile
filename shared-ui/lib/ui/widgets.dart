import '../l10n/ui_strings.dart';
import 'package:flutter/material.dart';
import '../core/model.dart';

const ink = Color(0xFF101112);
const muted = Color(0xFF8C9093);
const canvas = Color(0xFFF8F9F9);
const line = Color(0xFFE0E2E3);

ThemeData tenoTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: canvas,
  colorScheme: ColorScheme.fromSeed(
    seedColor: ink,
    primary: ink,
    surface: canvas,
  ),
  fontFamily: 'Inter',
  textTheme: const TextTheme(
    headlineMedium: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: ink,
    ),
    bodyLarge: TextStyle(fontSize: 15, height: 1.5, color: ink),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: ink),
    bodySmall: TextStyle(fontSize: 12, height: 1.4, color: muted),
  ),
  dividerColor: line,
  appBarTheme: const AppBarTheme(
    backgroundColor: canvas,
    foregroundColor: ink,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.all(16),
    border: OutlineInputBorder(
      borderSide: const BorderSide(color: line),
      borderRadius: BorderRadius.circular(14),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: line),
      borderRadius: BorderRadius.circular(14),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: ink,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
  ),
);

class CircleAction extends StatelessWidget {
  const CircleAction(
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
    width: size,
    height: size,
    child: IconButton.outlined(
      onPressed: onPressed,
      tooltip: ui(context, label),
      style: IconButton.styleFrom(
        side: const BorderSide(color: line),
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surface.withValues(alpha: .5),
      ),
      icon: Icon(icon, size: 22),
    ),
  );
}

class PageFrame extends StatelessWidget {
  const PageFrame({
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
      title: Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      leading: Padding(
        padding: const EdgeInsets.all(6),
        child: CircleAction(
          Icons.arrow_back,
          'Back',
          () => Navigator.of(context).pop(),
        ),
      ),
      actions: [...actions, const SizedBox(width: 12)],
    ),
    body: SafeArea(top: false, child: child),
    bottomNavigationBar: bottom == null
        ? null
        : SafeArea(
            child: Padding(padding: const EdgeInsets.all(16), child: bottom),
          ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
    this.title,
    this.message, {
    super.key,
    this.action,
    this.icon = Icons.notes_outlined,
  });
  final String title, message;
  final Widget? action;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: muted),
          const SizedBox(height: 20),
          Text(
            ui(context, title),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            ui(context, message),
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice(this.message, {super.key, this.retry});
  final String message;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 20),
        const SizedBox(width: 12),
        Expanded(child: UiText(message)),
        if (retry != null)
          TextButton(onPressed: retry, child: const UiText('Retry')),
      ],
    ),
  );
}

class MenuRow extends StatelessWidget {
  const MenuRow(
    this.icon,
    this.title,
    this.onTap, {
    super.key,
    this.subtitle,
    this.trailing,
    this.localizeTitle = true,
  });
  final bool localizeTitle;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    leading: Icon(icon, size: 23),
    title: localizeTitle ? UiText(title) : Text(title),
    subtitle: subtitle == null
        ? null
        : UiText(subtitle!, style: const TextStyle(color: muted, fontSize: 12)),
    trailing:
        trailing ??
        (onTap == null
            ? null
            : const Icon(Icons.chevron_right, color: muted, size: 20)),
    onTap: onTap,
  );
}

class RecordTile extends StatelessWidget {
  const RecordTile(this.record, this.onTap, {super.key, this.local = false});
  final Json record;
  final VoidCallback onTap;
  final bool local;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text(record['title']).isEmpty
                      ? ui(context, 'Untitled recording')
                      : text(record['title']),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  dateLabel(record['created_at']) +
                      ' · ' +
                      duration(record['duration_ms']),
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDEEEE),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: UiText(
                        local ? 'On this phone' : 'Recordings',
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                    ),
                    if (![
                      'transcribed',
                      'ready',
                      'local',
                      '',
                    ].contains(text(record['status'])))
                      Text(
                        ui(context, recordingStatus(record['status'])),
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: muted, size: 18),
        ],
      ),
    ),
  );
}

Future<T?> push<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

Future<void> perform(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: UiText(TenoModel.friendly(e))));
  }
}

Future<String?> inputDialog(
  BuildContext context,
  String title, {
  String initial = '',
  bool multiline = false,
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: UiText(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: multiline ? 4 : 1,
        maxLines: multiline ? 8 : 1,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const UiText('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const UiText('Save'),
        ),
      ],
    ),
  );
  // The route may animate for another frame while retaining its controller.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  controller.dispose();
  return result;
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: UiText(title),
        content: UiText(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const UiText('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const UiText('Confirm'),
          ),
        ],
      ),
    ) ??
    false;
