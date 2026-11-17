import 'package:flutter/material.dart';
import '../core/model.dart';
import '../l10n/ui_strings.dart';
import '../ui/widgets.dart';
import 'routes/personal_notes.dart';
import 'personal_actions.dart';
import 'generation_options.dart';

String templateLabel(String id) =>
    const {
      '@default': 'Account default',
      'teno:general': 'General notes',
      'teno:meeting': 'Meeting notes',
      'teno:interview': 'Interview insights',
      'teno:lecture': 'Lecture notes',
      'teno:inspiration': 'Inspiration',
      'teno:actions': 'Action items',
      'teno:brief': 'Concise recap',
    }[id] ??
    'Custom template';

class NoteTemplateChoice extends StatelessWidget {
  const NoteTemplateChoice(
    this.model, {
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.title = 'This template',
  });
  final TenoModel model;
  final String value;
  final bool enabled;
  final String title;
  final Future<void> Function(String) onChanged;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.article_outlined),
    title: UiText(title),
    subtitle: UiText(templateLabel(value)),
    trailing: const Icon(Icons.chevron_right, size: 18),
    enabled: enabled,
    onTap: !enabled
        ? null
        : () => perform(context, () async {
            final chosen = await push<String>(
              context,
              PersonalTemplatePicker(model),
            );
            if (chosen != null && context.mounted)
              await onChanged(chosen.isEmpty ? 'teno:general' : chosen);
          }),
  );
}

Future<void> generateAnotherNote(
  BuildContext context,
  TenoModel model,
  String recordingId,
) async {
  final chosen = await chooseGenerationOptions(context, model);
  if (chosen == null || !context.mounted) return;
  final job = await model.api('POST', '/api/v1/recordings/$recordingId/notes', {
    'client_id': requestId(),
    ...chosen,
  });
  if (context.mounted) await push(context, PersonalJobPage(model, job));
}
