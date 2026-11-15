import 'model.dart';

String editableNoteText(Json data) {
  final narrative = data['schema_version'] == 'personal-notes-v2';
  if (!narrative && data['body'] != null) return text(data['body']);
  final summary = text(data['summary']), body = text(data['body']);
  final parts = [
    if (summary.isNotEmpty && (!narrative || summary != body)) summary,
    if (narrative && body.isNotEmpty) body,
  ];
  for (final section in [
    ('key_points', 'Key points'),
    ('action_items', 'Next steps'),
  ]) {
    final values = data[section.$1] as List? ?? [];
    if (values.isNotEmpty)
      parts.add(
        '${section.$2}\n${values.map((v) => '- ${v is Map ? text(v['title'] ?? v['text']) : text(v)}').join('\n')}',
      );
  }
  return parts.join('\n\n');
}
