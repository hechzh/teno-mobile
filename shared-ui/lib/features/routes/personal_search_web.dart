// The functions preserve route call sites; native exports keep original widgets.
// ignore_for_file: non_constant_identifier_names
import 'package:flutter/material.dart';
import '../../core/model.dart';
import '../../ui/deferred_content.dart';
import '../personal_search.dart' deferred as page;

Widget PersonalSearchPage(
  TenoModel model, {
  Key? key,
  VoidCallback? onNavigation,
}) => DeferredContent(
  key: key,
  load: page.loadLibrary,
  builder: (_) => page.PersonalSearchPage(model, onNavigation: onNavigation),
);
