import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/ui_strings.dart';

/// A page keeps its navigation context while its Web code is fetched. Native
/// routes export their original widgets and never construct this wrapper.
class DeferredContent extends StatefulWidget {
  const DeferredContent({super.key, required this.load, required this.builder});
  final Future<void> Function() load;
  final WidgetBuilder builder;
  @override
  State<DeferredContent> createState() => _DeferredContentState();
}

class _DeferredContentState extends State<DeferredContent> {
  bool ready = false, failed = false;
  int attempt = 0;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    final current = ++attempt;
    setState(() => failed = false);
    try {
      await widget.load().timeout(const Duration(seconds: 30));
      if (mounted && current == attempt) setState(() => ready = true);
    } catch (_) {
      if (mounted && current == attempt) setState(() => failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ready) return widget.builder(context);
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!failed) const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              failed
                  ? (zh
                        ? '页面未能加载，请检查网络后重试。'
                        : 'This page could not load. Check your connection and retry.')
                  : (zh ? '正在加载页面…' : 'Loading this page…'),
              textAlign: TextAlign.center,
            ),
            if (failed)
              TextButton(onPressed: load, child: const UiText('Retry')),
          ],
        ),
      ),
    );
  }
}
