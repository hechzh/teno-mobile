// The functions preserve route call sites; native exports keep original widgets.
// ignore_for_file: non_constant_identifier_names
import 'package:flutter/material.dart';
import '../../core/model.dart';
import '../../ui/deferred_content.dart';
import '../personal_ask.dart' deferred as page;

Widget PersonalChatPage(
  TenoModel model, {
  Key? key,
  String? chatId,
  bool embedded = false,
  List<Json> initial = const [],
}) => DeferredContent(
  key: key,
  load: page.loadLibrary,
  builder: (_) => page.PersonalChatPage(
    model,
    chatId: chatId,
    embedded: embedded,
    initial: initial,
  ),
);

Widget PersonalChatHistory(TenoModel model, {Key? key}) => DeferredContent(
  key: key,
  load: page.loadLibrary,
  builder: (_) => page.PersonalChatHistory(model),
);

Widget PersonalContextPicker(TenoModel model, List<Json> initial, {Key? key}) =>
    DeferredContent(
      key: key,
      load: page.loadLibrary,
      builder: (_) => page.PersonalContextPicker(model, initial),
    );
