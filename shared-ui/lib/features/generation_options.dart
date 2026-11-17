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
    required this.onLanguage,
    this.language,
    this.enabled = true,
  });
  final TenoModel model;
  final String template;
  final String? language;
  final bool enabled;
  final Future<void> Function(String) onTemplate;
  final Future<void> Function(String?) onLanguage;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      NoteTemplateChoice(
        model,
        value: template,
        enabled: enabled,
        onChanged: onTemplate,
      ),
      DropdownButtonFormField<String>(
        key: ValueKey(
          'output-language-${language ?? 'interface'}-${model.outputLanguage}',
        ),
        initialValue: language ?? 'interface',
        isExpanded: true,
        decoration: InputDecoration(labelText: ui(context, 'Output language')),
        items: [
          DropdownMenuItem(
            value: 'interface',
            child: Text(
              '${ui(context, 'Follow interface')} · ${ui(context, model.outputLanguage == 'zh-CN' ? 'Chinese' : 'English')}',
            ),
          ),
          DropdownMenuItem(value: 'zh-CN', child: Text(ui(context, 'Chinese'))),
          DropdownMenuItem(value: 'en-US', child: Text(ui(context, 'English'))),
        ],
        onChanged: enabled
            ? (value) {
                if (value != null)
                  perform(
                    context,
                    () => onLanguage(value == 'interface' ? null : value),
                  );
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

Future<Json?> chooseGenerationOptions(
  BuildContext context,
  TenoModel model, {
  String template = '@default',
  bool allowTranscript = false,
}) async {
  String? language;
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
                onTemplate: (v) async => update(() => template = v),
                onLanguage: (v) async => update(() => language = v),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(sheet, {
                  'template_id': template,
                  ...model.generationLanguage(language),
                }),
                child: const UiText('Generate note'),
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
