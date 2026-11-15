// The functions preserve route call sites; native exports keep original widgets.
// ignore_for_file: non_constant_identifier_names
import 'package:flutter/material.dart';
import '../../core/model.dart';
import '../../ui/deferred_content.dart';
import '../home.dart' deferred as page;

Widget HomePage(TenoModel model, {Key? key}) => DeferredContent(
  key: key,
  load: page.loadLibrary,
  builder: (_) => page.HomePage(model),
);
