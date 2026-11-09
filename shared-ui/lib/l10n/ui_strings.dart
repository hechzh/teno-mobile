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
