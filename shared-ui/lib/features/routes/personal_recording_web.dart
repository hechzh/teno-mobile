// The functions preserve route call sites; native exports keep original widgets.
// ignore_for_file: non_constant_identifier_names
import 'package:flutter/material.dart';
import '../../core/model.dart';
import '../../ui/deferred_content.dart';
import '../personal_recording.dart' deferred as page;

Widget PersonalRecordingPage(
  TenoModel model,
  String id, {
  Key? key,
  int? seekMs,
  bool transcriptOnly = false,
}) => DeferredContent(
  key: key,
  load: page.loadLibrary,
  builder: (_) => page.PersonalRecordingPage(
    model,
    id,
    seekMs: seekMs,
    transcriptOnly: transcriptOnly,
  ),
);
