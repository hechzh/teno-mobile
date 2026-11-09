// The functions preserve route call sites; native exports keep original widgets.
// ignore_for_file: non_constant_identifier_names
import 'package:flutter/material.dart';
import '../../core/model.dart';
import '../../ui/deferred_content.dart';
import '../personal_import.dart' deferred as page;
import '../../ui/personal_widgets.dart';

Widget PersonalImportPage(
  TenoModel model, {
  Key? key,
  bool pending = false,
  bool sheet = false,
}) => DeferredContent(
  key: key,
  load: page.loadLibrary,
  builder: (_) =>
      page.PersonalImportPage(model, pending: pending, sheet: sheet),
);

Widget PersonalLocalList(TenoModel model, {Key? key}) => DeferredContent(
  key: key,
  load: page.loadLibrary,
  builder: (_) => page.PersonalLocalList(model),
);

Widget PersonalLocalPage(TenoModel model, String id, {Key? key}) =>
    DeferredContent(
      key: key,
      load: page.loadLibrary,
      builder: (_) => page.PersonalLocalPage(model, id),
    );

Future<void> showPersonalImport(
  BuildContext context,
  TenoModel model, {
  bool pending = false,
}) => showCoreSheet<void>(
  context,
  PersonalImportPage(model, pending: pending, sheet: true),
  height: pending ? 620 : 510,
);
