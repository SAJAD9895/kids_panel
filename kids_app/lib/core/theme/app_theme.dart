import 'package:flutter/material.dart';

import 'tokens.g.dart';

export 'tokens.g.dart';

FontWeight _weight(int w) => switch (w) {
  <= 100 => FontWeight.w100,
  <= 200 => FontWeight.w200,
  <= 300 => FontWeight.w300,
  <= 400 => FontWeight.w400,
  <= 500 => FontWeight.w500,
  <= 600 => FontWeight.w600,
  <= 700 => FontWeight.w700,
  <= 800 => FontWeight.w800,
  _ => FontWeight.w900,
};

/// A [TextStyle] from a token type spec. The fonts are variable, so the weight is also set
/// as a font variation (otherwise every weight renders at the font's default).
TextStyle textStyleOf(TypeSpec t, {Color? color}) => TextStyle(
  fontFamily: t.family,
  fontSize: t.size,
  height: t.line / t.size,
  fontWeight: _weight(t.weight),
  fontVariations: [FontVariation.weight(t.weight.toDouble())],
  color: color,
);

/// Kid-zone text styles (Fredoka headings, Nunito body).
abstract final class KidsText {
  static final display = textStyleOf(
    KidsType.display,
    color: AppColors.kidsInk,
  );
  static final title = textStyleOf(KidsType.title, color: AppColors.kidsInk);
  static final heading = textStyleOf(
    KidsType.heading,
    color: AppColors.kidsInk,
  );
  static final label = textStyleOf(KidsType.label, color: AppColors.kidsInk);
  static final body = textStyleOf(KidsType.body, color: AppColors.kidsInk);
  static final caption = textStyleOf(
    KidsType.caption,
    color: AppColors.kidsInkMuted,
  );
}

/// Grown-up zone text styles (Inter, Fredoka for page titles).
abstract final class UiText {
  static final display = textStyleOf(UiType.display, color: AppColors.uiText);
  static final h1 = textStyleOf(UiType.h1, color: AppColors.uiText);
  static final h2 = textStyleOf(UiType.h2, color: AppColors.uiText);
  static final h3 = textStyleOf(UiType.h3, color: AppColors.uiText);
  static final body = textStyleOf(UiType.body, color: AppColors.uiText);
  static final bodyStrong = textStyleOf(
    UiType.bodyStrong,
    color: AppColors.uiText,
  );
  static final small = textStyleOf(UiType.small, color: AppColors.uiTextMuted);
  static final caption = textStyleOf(
    UiType.caption,
    color: AppColors.uiTextMuted,
  );
}

/// The app's Material theme. Material widgets (fields, dialogs, snack bars) use the grown-up
/// tokens; kid screens style themselves with [KidsText] and the kid widgets.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.uiPrimary,
    primary: AppColors.uiPrimary,
    onPrimary: AppColors.uiOnPrimary,
    primaryContainer: AppColors.uiPrimarySoft,
    onPrimaryContainer: AppColors.uiOnPrimarySoft,
    error: AppColors.uiDanger,
    onError: AppColors.uiOnDanger,
    surface: AppColors.uiBg,
    onSurface: AppColors.uiText,
    outline: AppColors.uiBorderInput,
    outlineVariant: AppColors.uiBorder,
  );
  final inputRadius = BorderRadius.circular(Radii.md);
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: inputRadius,
    borderSide: BorderSide(color: c, width: w),
  );
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Radii.md),
  );
  const buttonSize = Size(Sizes.tapUi, Sizes.tapUi + Space.s1);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.uiSurface,
    fontFamily: FontFamilies.sans,
    textTheme: TextTheme(
      displaySmall: UiText.display,
      headlineMedium: UiText.h1,
      titleLarge: UiText.h2,
      titleMedium: UiText.h3,
      bodyLarge: UiText.body,
      bodyMedium: UiText.body,
      bodySmall: UiText.small,
      labelLarge: UiText.bodyStrong,
      labelSmall: UiText.caption,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.uiBg,
      foregroundColor: AppColors.uiText,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleTextStyle: UiText.h2,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.uiBg,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Space.s5,
        vertical: Space.s4,
      ),
      border: border(AppColors.uiBorderInput),
      enabledBorder: border(AppColors.uiBorderInput),
      focusedBorder: border(AppColors.uiFocus, 2),
      errorBorder: border(AppColors.uiDanger),
      focusedErrorBorder: border(AppColors.uiDanger, 2),
      labelStyle: UiText.body.copyWith(color: AppColors.uiTextMuted),
      helperStyle: UiText.small,
      errorStyle: UiText.small.copyWith(color: AppColors.uiDanger),
      helperMaxLines: 3,
      errorMaxLines: 3,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        shape: buttonShape,
        textStyle: UiText.bodyStrong,
        backgroundColor: AppColors.uiPrimary,
        foregroundColor: AppColors.uiOnPrimary,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        shape: buttonShape,
        textStyle: UiText.bodyStrong,
        foregroundColor: AppColors.uiText,
        side: const BorderSide(color: AppColors.uiBorderInput),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(Sizes.tapUi, Sizes.tapUi),
        shape: buttonShape,
        textStyle: UiText.bodyStrong,
        foregroundColor: AppColors.uiPrimary,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      side: const BorderSide(color: AppColors.uiBorderInput, width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xs),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.uiText,
      contentTextStyle: UiText.body.copyWith(color: AppColors.uiOnPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.uiBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      titleTextStyle: UiText.h2,
      contentTextStyle: UiText.body,
    ),
    cardTheme: CardThemeData(
      color: AppColors.uiSurfaceRaised,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: const BorderSide(color: AppColors.uiBorder),
      ),
    ),
    focusColor: AppColors.uiPrimarySoft,
  );
}
