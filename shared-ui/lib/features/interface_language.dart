import 'package:flutter/material.dart';
import '../core/model.dart';
import '../l10n/ui_strings.dart';
import '../ui/personal_widgets.dart';
import '../ui/widgets.dart';

/// Lets users select the interface language before they can open Settings.
class InterfaceLanguageButton extends StatefulWidget {
  const InterfaceLanguageButton(this.model, {super.key});
  final TenoModel model;
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
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.language, size: 19),
          SizedBox(width: 7),
          Text('中文 / EN', style: TextStyle(fontSize: 13)),
          Icon(Icons.arrow_drop_down, size: 18),
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
