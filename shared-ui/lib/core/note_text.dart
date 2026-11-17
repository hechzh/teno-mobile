import 'model.dart';

String noteGenerationLabel(Json data) {
  if (text(data['output_language']).isEmpty) return '';
  final zh = text(data['output_language']).startsWith('zh');
  final template = object(data['template_snapshot']);
  final title = text(template[zh ? 'title_zh' : 'title'] ?? template['title']);
  return zh
      ? '模板：$title · 输出语言：中文'
      : 'Template: $title · Output language: English';
}

String copyNoteText(Json data) => [
  if (noteGenerationLabel(data).isNotEmpty) noteGenerationLabel(data),
  editableNoteText(data),
].join('\n\n');

String editableNoteText(Json data) {
  final narrative = data['schema_version'] == 'personal-notes-v2';
  if (!narrative && data['body'] != null) return text(data['body']);
  final summary = text(data['summary']), body = text(data['body']);
  final parts = [
    if (summary.isNotEmpty && (!narrative || summary != body)) summary,
    if (narrative && body.isNotEmpty) body,
  ];
  final zh = text(data['language']).startsWith('zh');
  for (final section in [
    ('key_points', zh ? '要点' : 'Key points'),
    ('action_items', zh ? '行动项' : 'Next steps'),
  ]) {
    final values = data[section.$1] as List? ?? [];
    if (values.isNotEmpty)
      parts.add(
        '${section.$2}\n${values.map((v) => '• ${v is Map ? text(v['title'] ?? v['text']) : text(v)}').join('\n')}',
      );
  }
  return parts.join('\n\n');
}
