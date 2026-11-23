import 'package:flutter/material.dart';
import 'generated/app_localizations.dart';
import 'ui_catalog.g.dart';
export 'generated/app_localizations.dart';

/// Only app-authored labels opt into this lookup. User/server text stays Text.
String ui(BuildContext context, String source) {
  final locale = Localizations.maybeLocaleOf(context) ?? const Locale('en');
  final strings = lookupAppLocalizations(
    locale.languageCode == 'zh' ? const Locale('zh') : const Locale('en'),
  );
  return lookupUiMessage(strings, source);
}

/// Localize a native status line, including its numeric and compound forms.
String statusText(BuildContext context, String source) {
  final value = source.trim();
  if (value.isEmpty) return value;
  final chinese =
      Localizations.maybeLocaleOf(context)?.languageCode == 'zh';
  String look(String text) => ui(context, text);

  final uploading = RegExp(r'^Uploading (\d+)%$').firstMatch(value);
  if (uploading != null) {
    return chinese ? '正在上传 ${uploading[1]}%' : 'Uploading ${uploading[1]}%';
  }
  final decoding = RegExp(r'^Decoding audio (\d+)%$').firstMatch(value);
  if (decoding != null) {
    return chinese ? '正在解码音频 ${decoding[1]}%' : 'Decoding audio ${decoding[1]}%';
  }
  final connected = RegExp(r'^Recorder connected · (\d+) folders$').firstMatch(value);
  if (connected != null) {
    return chinese ? '录音卡已连接 · ${connected[1]} 个文件夹' : value;
  }
  final loaded = RegExp(r'^Loaded (\d+) recordings$').firstMatch(value);
  if (loaded != null) {
    return chinese ? '已加载 ${loaded[1]} 条录音' : value;
  }
  final confirm =
      RegExp(r'^Recorder did not confirm the action \((.+?)\)\.\s*(.*)$').firstMatch(value);
  if (confirm != null) {
    final tail = confirm[2]!.trim();
    if (!chinese) return value;
    const operations = {
      'auth': '授权',
      'identity': '身份',
      'rotate': '密钥轮换',
      'start': '开始录音',
      'stop': '停止录音',
      'probe': '设备检测',
      'connect': '连接',
    };
    final code = operations[confirm[1]!] ?? confirm[1]!;
    final suffix = tail.isEmpty ? '' : ' ${look(tail)}';
    return '录音卡未确认操作（$code）。$suffix';
  }
  final request = RegExp(r'^Request failed \((\d+)\)$').firstMatch(value);
  if (request != null) {
    return chinese ? '请求失败（${request[1]}）' : value;
  }
  for (final entry in {
    'Bluetooth scan failed (': '蓝牙扫描失败（',
    'Request could not be completed (': '请求未能完成（',
  }.entries) {
    if (value.startsWith(entry.key)) {
      return chinese ? entry.value + value.substring(entry.key.length) : value;
    }
  }
  for (final entry in {
    'Invalid device response: ': '设备响应无效：',
    'Audio could not finish syncing: ': '音频同步未能完成：',
    'Upload failed: ': '上传失败：',
    'Recording could not start. ': '录音无法开始。',
  }.entries) {
    if (value.startsWith(entry.key)) {
      return chinese ? entry.value + value.substring(entry.key.length) : value;
    }
  }
  if (value.contains(' · ')) {
    return value.split(' · ').map(look).join(' · ');
  }
  return look(value);
}

extension TenoStrings on BuildContext {
  AppLocalizations get strings => lookupAppLocalizations(
    (Localizations.maybeLocaleOf(this)?.languageCode == 'zh')
        ? const Locale('zh')
        : const Locale('en'),
  );
}

/// Const-friendly localized label, deliberately separate from content Text.
class UiText extends StatelessWidget {
  const UiText(
    this.source, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.textDirection,
    this.textWidthBasis,
    this.semanticsLabel,
    this.textHeightBehavior,
    this.strutStyle,
  });
  final String source;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final TextDirection? textDirection;
  final TextWidthBasis? textWidthBasis;
  final String? semanticsLabel;
  final TextHeightBehavior? textHeightBehavior;
  final StrutStyle? strutStyle;
  @override
  Widget build(BuildContext context) => Text(
    ui(context, source),
    style: style,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
    softWrap: softWrap,
    textDirection: textDirection,
    textWidthBasis: textWidthBasis,
    textHeightBehavior: textHeightBehavior,
    strutStyle: strutStyle,
    semanticsLabel: semanticsLabel == null
        ? null
        : ui(context, semanticsLabel!),
  );
}
