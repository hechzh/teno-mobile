import 'package:flutter/material.dart';
import '../core/model.dart';
import '../l10n/ui_strings.dart';
import '../ui/personal_widgets.dart';
import '../ui/widgets.dart';

/// A shared shortcut to the app-wide, device-persisted interface preference.
class InterfaceLanguageButton extends StatefulWidget {
  const InterfaceLanguageButton(this.model, {super.key, this.compact = false});
  final TenoModel model;
  final bool compact;
  @override
  State<InterfaceLanguageButton> createState() =>
      _InterfaceLanguageButtonState();
}

class _InterfaceLanguageButtonState extends State<InterfaceLanguageButton> {
  bool saving = false;
  Future<void> select(String value) async {
    if (saving || value == widget.model.interfaceLanguage) return;
    setState(() => saving = true);
    await perform(context, () => widget.model.setInterfaceLanguage(value));
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    key: const ValueKey('interface-language-switch'),
    tooltip: context.strings.interfaceLanguage,
    enabled: !saving,
    initialValue: widget.model.interfaceLanguage,
    onSelected: select,
    itemBuilder: (menu) => [
      for (final item in [
        ('zh', '简体中文'),
        ('en', 'English'),
        ('system', context.strings.followSystem),
      ])
        CheckedPopupMenuItem<String>(
          value: item.$1,
          checked: widget.model.interfaceLanguage == item.$1,
          child: Text(item.$2),
        ),
    ],
    child: widget.compact
        ? const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.language, size: 20),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language, size: 19),
                const SizedBox(width: 7),
                const Text('中文 / EN', style: TextStyle(fontSize: 13)),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
  );
}

class InterfaceLanguagePage extends StatelessWidget {
  const InterfaceLanguagePage(this.model, {super.key});
  final TenoModel model;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) => CoreFrame(
      title: context.strings.interfaceLanguage,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(context.strings.languageHint),
          const SizedBox(height: 24),
          RadioGroup<String>(
            groupValue: model.interfaceLanguage,
            onChanged: (value) {
              if (value != null)
                perform(context, () => model.setInterfaceLanguage(value));
            },
            child: Column(
              children: [
                for (final item in [
                  ('system', context.strings.followSystem),
                  ('zh', '简体中文'),
                  ('en', 'English'),
                ])
                  RadioListTile<String>(value: item.$1, title: UiText(item.$2)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
