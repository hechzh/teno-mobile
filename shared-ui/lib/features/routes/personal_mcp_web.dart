// ignore_for_file: non_constant_identifier_names
import 'package:flutter/material.dart';
import '../../core/model.dart';
import '../../ui/deferred_content.dart';
import '../personal_mcp.dart' deferred as page;

Widget McpConnectionsPage(TenoModel model, {Key? key}) => DeferredContent(
  key: key,
  load: page.loadLibrary,
  builder: (_) => page.McpConnectionsPage(model),
);
Widget McpCreatePage(
  TenoModel model, {
  Key? key,
  List<Json> initial = const [],
}) => DeferredContent(
  key: key,
  load: page.loadLibrary,
  builder: (_) => page.McpCreatePage(model, initial: initial),
);
Widget McpConnectionPage(
  TenoModel model,
  String id, {
  Key? key,
  String? sourceKey,
  String? snapshotId,
  int chunk = 0,
}) => DeferredContent(
  key: key,
  load: page.loadLibrary,
  builder: (_) => page.McpConnectionPage(
    model,
    id,
    sourceKey: sourceKey,
    snapshotId: snapshotId,
    chunk: chunk,
  ),
);
