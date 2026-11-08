import 'package:flutter/material.dart';
import 'package:teno_mobile/core/model.dart';
import 'package:teno_mobile/main.dart';
import 'web_runtime.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final host = WebRuntime();
  final model = TenoModel(host: host, webExperience: true);
  host.listen(model.changed);
  runApp(TenoApp(model: model));
}
