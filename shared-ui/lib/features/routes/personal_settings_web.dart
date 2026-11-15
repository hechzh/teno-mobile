// The functions preserve route call sites; native exports keep original widgets.
// ignore_for_file: non_constant_identifier_names
import 'package:flutter/material.dart';
import '../../core/model.dart';
import '../../ui/deferred_content.dart';
import '../personal_settings.dart' deferred as page;

Widget PersonalSettings(TenoModel model, {Key? key}) => DeferredContent(
  key: key,
  load: page.loadLibrary,
  builder: (_) => page.PersonalSettings(model),
);

Widget PersonalCalendarPage(TenoModel model, {Key? key, bool select = false}) =>
    DeferredContent(
      key: key,
      load: page.loadLibrary,
      builder: (_) => page.PersonalCalendarPage(model, select: select),
    );

Widget PersonalPreferences(TenoModel model, {Key? key, bool detail = false}) =>
    DeferredContent(
      key: key,
      load: page.loadLibrary,
      builder: (_) => page.PersonalPreferences(model, detail: detail),
    );
