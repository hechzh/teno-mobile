// Web has no device or microphone routes; native retains its original exports.
// ignore_for_file: non_constant_identifier_names
import 'package:flutter/material.dart';
import '../../core/model.dart';

Widget DevicePage(TenoModel model, {Key? key}) => const SizedBox.shrink();
Future<void> showRecorder(BuildContext context, TenoModel model) async =>
    throw UnsupportedError('Recording requires the native app.');
