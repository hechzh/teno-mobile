import 'package:flutter/material.dart';

/// Teno MVP tokens, shared by the browser and native Flutter surfaces.
ThemeData mvpTheme(bool dark) {
  final paper = Color(dark ? 0xFF191F1B : 0xFFFBFAF6);
  final card = Color(dark ? 0xFF242D25 : 0xFFF3F4EC);
  final sage = Color(dark ? 0xFF344632 : 0xFFE4EDDA);
  final green = Color(dark ? 0xFFB4D19E : 0xFF356448);
  final ink = Color(dark ? 0xFFEEF1E9 : 0xFF252C24);
  final muted = Color(dark ? 0xFFB2BBAA : 0xFF697064);
  final line = Color(dark ? 0xFF394338 : 0xFFE1E4D9);
  final colors =
      ColorScheme.fromSeed(
        seedColor: green,
        brightness: dark ? Brightness.dark : Brightness.light,
      ).copyWith(
        primary: green,
        onPrimary: dark ? const Color(0xFF19281B) : Colors.white,
        surface: paper,
        onSurface: ink,
        onSurfaceVariant: muted,
        surfaceContainerLowest: paper,
        surfaceContainerLow: card,
        surfaceContainer: card,
        surfaceContainerHigh: sage,
        surfaceContainerHighest: sage,
        secondaryContainer: sage,
        onSecondaryContainer: ink,
        outline: muted,
        outlineVariant: line,
        error: dark ? const Color(0xFFF0ADA5) : const Color(0xFFA64F48),
        surfaceTint: Colors.transparent,
      );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: line),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: paper,
    fontFamily: 'Inter',
    fontFamilyFallback: const ['NotoSansSC'],
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontSize: 30,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.45,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.75, color: ink),
      bodyMedium: TextStyle(fontSize: 15, height: 1.65, color: ink),
      bodySmall: TextStyle(fontSize: 13, height: 1.5, color: muted),
      labelLarge: TextStyle(
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w500,
        color: ink,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: paper,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: 60,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: const ['NotoSansSC'],
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
    ),
    dividerColor: line,
    dividerTheme: DividerThemeData(color: line, thickness: 1),
    popupMenuTheme: PopupMenuThemeData(
      color: paper,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: .10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: line),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    chipTheme: ChipThemeData(
      selectedColor: sage,
      backgroundColor: paper,
      side: BorderSide(color: line),
      showCheckmark: false,
      labelStyle: TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: const ['NotoSansSC'],
        fontSize: 13,
        color: ink,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: green, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        side: BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: paper,
      indicatorColor: sage,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, color: ink),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: green),
  );
}
