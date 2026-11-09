// The functions preserve route call sites; native exports keep original widgets.
// ignore_for_file: non_constant_identifier_names
import 'package:flutter/material.dart';
export '../../core/note_text.dart';
import '../../core/model.dart';
import '../../ui/deferred_content.dart';
import '../personal_notes.dart' deferred as page;

Widget PersonalNotePage(TenoModel model, String id, {Key? key}) =>
    DeferredContent(
      key: key,
      load: page.loadLibrary,
      builder: (_) => page.PersonalNotePage(model, id),
    );

Widget NoteContent(Json note, TenoModel model, {Key? key}) => DeferredContent(
  key: key,
  load: page.loadLibrary,
  builder: (_) => page.NoteContent(note, model),
);

Widget PersonalNoteEditor(
  TenoModel model, {
  Key? key,
  Json? note,
  String? folderId,
  String? initialBody,
}) => DeferredContent(
  key: key,
  load: page.loadLibrary,
  builder: (_) => page.PersonalNoteEditor(
    model,
    note: note,
    folderId: folderId,
    initialBody: initialBody,
  ),
);

Widget PersonalTemplatePicker(
  TenoModel model, {
  Key? key,
  bool allowTranscript = false,
}) => DeferredContent(
  key: key,
  load: page.loadLibrary,
  builder: (_) =>
      page.PersonalTemplatePicker(model, allowTranscript: allowTranscript),
);

Widget PersonalTemplates(
  TenoModel model, {
  Key? key,
  bool picker = false,
  String? collection,
  String? initialCategory,
  bool searching = false,
  bool allowTranscript = false,
}) => DeferredContent(
  key: key,
  load: page.loadLibrary,
  builder: (_) => page.PersonalTemplates(
    model,
    picker: picker,
    collection: collection,
    initialCategory: initialCategory,
    searching: searching,
    allowTranscript: allowTranscript,
  ),
);
