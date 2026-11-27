import 'package:flutter/material.dart';
import '../core/model.dart';
import '../l10n/ui_strings.dart';
import '../ui/widgets.dart';
import 'note_templates.dart';

class GenerationOptions extends StatelessWidget {
  const GenerationOptions(
    this.model, {
    super.key,
    required this.template,
    required this.onTemplate,
    this.onLanguage,
    this.language,
    this.enabled = true,
    this.templateTitle = 'This template',
    this.promptForSelection = false,
  });
  final TenoModel model;
  final String template;
  final String? language;
  final bool enabled;
  final String templateTitle;
  final bool promptForSelection;
  final Future<void> Function(String) onTemplate;
  final Future<void> Function(String?)? onLanguage;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      NoteTemplateChoice(
        model,
        value: template,
        title: templateTitle,
        promptForSelection: promptForSelection,
        enabled: enabled,
        onChanged: onTemplate,
      ),
      if (onLanguage case final change?)
        GenerationLanguageChoice(
          model,
          value: language,
          onChanged: enabled
              ? (value) {
                  perform(context, () => change(value));
                }
              : null,
        ),
      const SizedBox(height: 6),
      const UiText(
        'Applies to this file only. Saved notes are unchanged.',
        style: TextStyle(fontSize: 11),
      ),
    ],
  );
}

class GenerationLanguageChoice extends StatelessWidget {
  const GenerationLanguageChoice(
    this.model, {
    super.key,
    this.value,
    this.onChanged,
  });

  final TenoModel model;
  final String? value;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    key: ValueKey<String>(
      'output-language-' + (value ?? 'interface') + '-' + model.outputLanguage,
    ),
    initialValue: value ?? 'interface',
    isExpanded: true,
    decoration: InputDecoration(labelText: ui(context, 'Output language')),
    items: [
      DropdownMenuItem(
        value: 'interface',
        child: Text(
          ui(context, 'Follow interface') +
              ' · ' +
              ui(
                context,
                model.outputLanguage == 'zh-CN' ? 'Chinese' : 'English',
              ),
        ),
      ),
      DropdownMenuItem(value: 'zh-CN', child: Text(ui(context, 'Chinese'))),
      DropdownMenuItem(value: 'en-US', child: Text(ui(context, 'English'))),
    ],
    onChanged: onChanged == null
        ? null
        : (next) => onChanged!(next == 'interface' ? null : next),
  );
}

Future<Json?> chooseGenerationOptions(
  BuildContext context,
  TenoModel model, {
  String template = '@default',
  bool allowTranscript = false,
  bool requireTemplateChoice = false,
}) async {
  String? language;
  var templateConfirmed = !requireTemplateChoice;
  return showModalBottomSheet<Json>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, update) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            24 + MediaQuery.viewInsetsOf(sheet).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const UiText(
                'Generation options',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              GenerationOptions(
                model,
                template: template,
                language: language,
                templateTitle: requireTemplateChoice
                    ? 'Summary template'
                    : 'This template',
                promptForSelection: !templateConfirmed,
                onTemplate: (v) async => update(() {
                  template = v;
                  templateConfirmed = true;
                }),
                onLanguage: (v) async => update(() => language = v),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: !templateConfirmed
                    ? null
                    : () => Navigator.pop(sheet, {
                        'template_id': template,
                        ...model.generationLanguage(language),
                      }),
                child: UiText(
                  requireTemplateChoice ? 'Generate' : 'Generate note',
                ),
              ),
              if (allowTranscript)
                TextButton(
                  onPressed: () =>
                      Navigator.pop(sheet, {'template_id': '__transcript__'}),
                  child: const UiText('Transcript'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
