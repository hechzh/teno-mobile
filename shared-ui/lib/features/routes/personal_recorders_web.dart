// ignore_for_file: non_constant_identifier_names
import 'package:flutter/material.dart';
import '../../core/model.dart';
import '../../ui/deferred_content.dart';
import '../personal_recorders.dart' deferred as page;

Widget MyRecordersPage(TenoModel model, {Key? key}) => DeferredContent(
  key: key,
  load: page.loadLibrary,
  builder: (_) => page.MyRecordersPage(model),
);
