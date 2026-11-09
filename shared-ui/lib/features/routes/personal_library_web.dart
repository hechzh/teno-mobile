// The functions preserve route call sites; native exports keep original widgets.
// ignore_for_file: non_constant_identifier_names
import 'package:flutter/material.dart';
import '../../core/model.dart';
import '../../ui/deferred_content.dart';
import '../personal_library.dart' deferred as feature;

Widget PersonalListPage(
  TenoModel model, {
  Key? key,
  required String title,
  String? folderId,
  String? type,
  bool trash = false,
}) => DeferredContent(
  key: key,
  load: feature.loadLibrary,
  builder: (_) => feature.PersonalListPage(
    model,
    title: title,
    folderId: folderId,
    type: type,
    trash: trash,
  ),
);

Widget PersonalListBody(
  TenoModel model, {
  Key? key,
  String? folderId,
  String? type,
  bool trash = false,
  bool root = false,
  ValueNotifier<String>? commands,
  ValueChanged<int?>? onSelectionChanged,
}) => DeferredContent(
  key: key,
  load: feature.loadLibrary,
  builder: (_) => feature.PersonalListBody(
    model,
    folderId: folderId,
    type: type,
    trash: trash,
    root: root,
    commands: commands,
    onSelectionChanged: onSelectionChanged,
  ),
);

Widget PersonalFilePage(TenoModel model, String id, {Key? key, int? page}) =>
    DeferredContent(
      key: key,
      load: feature.loadLibrary,
      builder: (_) => feature.PersonalFilePage(model, id, page: page),
    );
