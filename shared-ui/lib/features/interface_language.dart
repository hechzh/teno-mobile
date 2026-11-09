import 'package:flutter/material.dart';
import '../core/model.dart';
import '../l10n/ui_strings.dart';
import '../ui/personal_widgets.dart';
import '../ui/widgets.dart';

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
