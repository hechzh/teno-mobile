import 'package:flutter/material.dart';
import '../core/model.dart';
import '../l10n/ui_strings.dart';
import 'widgets.dart';

String processingStage(Json p) =>
    const {
      'saved': 'Recording saved',
      'syncing': 'Syncing from recorder',
      'waiting_upload': 'Waiting to upload',
      'uploading': 'Uploading',
      'transcribing': 'Transcribing',
      'extracting_text': 'Extracting text',
      'preparing_audio': 'Preparing audio',
      'generating_note': 'Generating note',
      'complete': 'Complete',
      'awaiting_generation': 'Note generation not started',
      'awaiting_transcription': 'Transcription not started',
      'awaiting_extraction': 'Text extraction not started',
    }[p['stage']] ??
    'Checking processing status';

String processingReason(Json p) =>
    const {
      'wifi_only': 'Waiting for Wi-Fi',
      'network': 'Network unavailable',
      'cloud_disabled': 'Cloud processing is off · Saved locally only',
      'sign_in': 'Sign in to upload',
      'server_queue': 'Waiting for a processing slot',
      'retry_backoff': 'Waiting to retry',
      'no_speech': 'No speech was found. The audio is saved.',
    }[p['waiting_reason']] ??
    '';

class ProcessingProgress extends StatelessWidget {
  const ProcessingProgress(
    this.value, {
    super.key,
    this.retry,
    this.compact = false,
    this.browser = false,
  });
  final Json value;
  final Future<void> Function()? retry;
  final bool compact, browser;
  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    final failed = value['stage_status'] == 'failed';
    final kept = object(value['preserved']);
    final reason = processingReason(value);
    final percent = value['percent'] is num
        ? (value['percent'] as num).clamp(0, 100)
        : null;
    final localOnly = value['waiting_reason'] == 'cloud_disabled';
    final stage = value['stage'] == 'saved' && kept['local_file'] == true
        ? (browser ? 'Saved in this browser' : 'Saved on this phone')
        : processingStage(value);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${ui(context, stage)}${failed ? ' · ${ui(context, 'Failed')}' : ''}${percent != null ? ' · $percent%' : ''}',
            style: TextStyle(
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w600,
              color: failed ? Theme.of(context).colorScheme.error : null,
            ),
          ),
          if (reason.isNotEmpty)
            UiText(reason, style: const TextStyle(fontSize: 12)),
          if (value['stale'] == true)
            const UiText(
              'Showing the last confirmed status. Not refreshed.',
              style: TextStyle(fontSize: 12),
            ),
          if (!compact) ...[
            if (!failed &&
                !localOnly &&
                ['running', 'queued'].contains(value['stage_status']))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(
                  value: percent == null ? null : percent / 100,
                  minHeight: 2,
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (kept['device_file'] == true)
                  const UiText('Saved on recorder'),
                if (kept['local_file'] == true)
                  UiText(
                    browser ? 'Saved in this browser' : 'Saved on this phone',
                  ),
                if (kept['cloud_audio'] == true || kept['cloud_file'] == true)
                  const UiText('Cloud file kept'),
                if (kept['transcript'] == true) const UiText('Transcript kept'),
                if (kept['extracted_text'] == true)
                  const UiText('Extracted text kept'),
                if ((kept['notes'] as num? ?? 0) > 0)
                  const UiText('Existing notes kept'),
              ],
            ),
            if ((value['warnings'] as List? ?? []).contains(
              'note_needs_verification',
            ))
              const UiText(
                'Some content needs verification. Open the note for details.',
              ),
            if ((value['warnings'] as List? ?? []).contains(
              'cleanup_failed_original_kept',
            ))
              const UiText(
                'Transcript cleanup failed. The original transcript is kept.',
              ),
            if (failed && text(object(value['error'])['message']).isNotEmpty)
              ErrorNotice(text(object(value['error'])['message'])),
            if (failed && retry != null)
              TextButton(
                onPressed: () => perform(context, retry!),
                child: UiText(
                  value['stage'] == 'generating_note'
                      ? 'Retry note generation'
                      : 'Retry this step',
                ),
              ),
          ],
        ],
      ),
    );
  }
}
