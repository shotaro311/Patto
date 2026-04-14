import 'package:flutter/material.dart';

import '../../domain/app_settings.dart';

class PattoThemeTokens extends ThemeExtension<PattoThemeTokens> {
  const PattoThemeTokens({
    required this.canvasGradient,
    required this.heroGradient,
    required this.panelGradient,
    required this.panelColor,
    required this.panelMutedColor,
    required this.panelStrongColor,
    required this.selectionColor,
    required this.outlineSoftColor,
    required this.shadowColor,
    required this.glowColor,
  });

  final LinearGradient canvasGradient;
  final LinearGradient heroGradient;
  final LinearGradient panelGradient;
  final Color panelColor;
  final Color panelMutedColor;
  final Color panelStrongColor;
  final Color selectionColor;
  final Color outlineSoftColor;
  final Color shadowColor;
  final Color glowColor;

  @override
  PattoThemeTokens copyWith({
    LinearGradient? canvasGradient,
    LinearGradient? heroGradient,
    LinearGradient? panelGradient,
    Color? panelColor,
    Color? panelMutedColor,
    Color? panelStrongColor,
    Color? selectionColor,
    Color? outlineSoftColor,
    Color? shadowColor,
    Color? glowColor,
  }) {
    return PattoThemeTokens(
      canvasGradient: canvasGradient ?? this.canvasGradient,
      heroGradient: heroGradient ?? this.heroGradient,
      panelGradient: panelGradient ?? this.panelGradient,
      panelColor: panelColor ?? this.panelColor,
      panelMutedColor: panelMutedColor ?? this.panelMutedColor,
      panelStrongColor: panelStrongColor ?? this.panelStrongColor,
      selectionColor: selectionColor ?? this.selectionColor,
      outlineSoftColor: outlineSoftColor ?? this.outlineSoftColor,
      shadowColor: shadowColor ?? this.shadowColor,
      glowColor: glowColor ?? this.glowColor,
    );
  }

  @override
  PattoThemeTokens lerp(ThemeExtension<PattoThemeTokens>? other, double t) {
    if (other is! PattoThemeTokens) return this;
    return PattoThemeTokens(
      canvasGradient: LinearGradient.lerp(
        canvasGradient,
        other.canvasGradient,
        t,
      )!,
      heroGradient: LinearGradient.lerp(heroGradient, other.heroGradient, t)!,
      panelGradient: LinearGradient.lerp(
        panelGradient,
        other.panelGradient,
        t,
      )!,
      panelColor: Color.lerp(panelColor, other.panelColor, t)!,
      panelMutedColor: Color.lerp(panelMutedColor, other.panelMutedColor, t)!,
      panelStrongColor: Color.lerp(
        panelStrongColor,
        other.panelStrongColor,
        t,
      )!,
      selectionColor: Color.lerp(selectionColor, other.selectionColor, t)!,
      outlineSoftColor: Color.lerp(
        outlineSoftColor,
        other.outlineSoftColor,
        t,
      )!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      glowColor: Color.lerp(glowColor, other.glowColor, t)!,
    );
  }
}

extension PattoThemeContext on BuildContext {
  PattoThemeTokens get pattoTokens =>
      Theme.of(this).extension<PattoThemeTokens>()!;
}

LinearGradient _solidGradient(Color color) {
  return LinearGradient(colors: [color, color]);
}

List<BoxShadow> pattoShadows(
  BuildContext context, {
  bool floating = false,
  bool selected = false,
}) {
  final tokens = context.pattoTokens;
  if (selected) {
    return [
      BoxShadow(
        color: tokens.glowColor.withValues(alpha: 0.24),
        blurRadius: 30,
        offset: const Offset(0, 6),
        spreadRadius: -12,
      ),
    ];
  }

  return [
    BoxShadow(
      color: tokens.shadowColor.withValues(alpha: floating ? 0.14 : 0.08),
      blurRadius: floating ? 30 : 28,
      offset: Offset(0, floating ? 6 : 4),
      spreadRadius: floating ? -10 : -14,
    ),
  ];
}

BoxDecoration pattoSurfaceDecoration(
  BuildContext context, {
  double radius = 24,
  Color? color,
  Gradient? gradient,
  Color? borderColor,
  bool muted = false,
  bool selected = false,
  bool floating = false,
}) {
  final tokens = context.pattoTokens;
  final scheme = Theme.of(context).colorScheme;
  final fill =
      color ??
      (selected
          ? tokens.selectionColor
          : muted
          ? tokens.panelMutedColor
          : tokens.panelColor);
  return BoxDecoration(
    color: gradient == null ? fill : null,
    gradient: gradient,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color:
          borderColor ??
          (selected
              ? scheme.primary.withValues(alpha: 0.32)
              : tokens.outlineSoftColor),
    ),
    boxShadow: pattoShadows(context, floating: floating, selected: selected),
  );
}

ThemeData buildPattoTheme(
  AppThemeStyle style, {
  Brightness brightness = Brightness.light,
}) {
  final palette = _PattoPalette.fromStyle(style, brightness: brightness);
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: palette.primary,
    onPrimary: palette.onPrimary,
    primaryContainer: palette.primaryContainer,
    onPrimaryContainer: palette.ink,
    secondary: palette.secondary,
    onSecondary: palette.ink,
    secondaryContainer: palette.secondaryContainer,
    onSecondaryContainer: palette.ink,
    tertiary: palette.tertiary,
    onTertiary: palette.onPrimary,
    tertiaryContainer: palette.tertiaryContainer,
    onTertiaryContainer: palette.ink,
    error: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E),
    onError: Colors.white,
    errorContainer:
        isDark ? const Color(0xFF93000A) : const Color(0xFFF9DEDC),
    onErrorContainer:
        isDark ? const Color(0xFFFFDAD6) : const Color(0xFF410E0B),
    surface: palette.surface,
    onSurface: palette.ink,
    onSurfaceVariant: palette.inkMuted,
    outline: palette.outlineStrong,
    outlineVariant: palette.outline,
    shadow: palette.shadow,
    scrim: Colors.black.withValues(alpha: isDark ? 0.32 : 0.12),
    inverseSurface:
        isDark ? const Color(0xFFF1F4F0) : const Color(0xFF2E3141),
    onInverseSurface:
        isDark ? const Color(0xFF17201A) : const Color(0xFFF5F5F8),
    inversePrimary: palette.primaryContainer,
    surfaceTint: palette.primary,
    surfaceDim: palette.background,
    surfaceBright: palette.surface,
    surfaceContainerLowest: palette.background,
    surfaceContainerLow: palette.panelMuted,
    surfaceContainer: palette.panel,
    surfaceContainerHigh: palette.surface,
    surfaceContainerHighest: palette.surfaceStrong,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.background,
  );

  final textTheme = base.textTheme.copyWith(
    headlineSmall: base.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      color: palette.ink,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: palette.ink,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: palette.ink,
    ),
    titleSmall: base.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: palette.ink,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(
      height: 1.45,
      color: palette.ink,
    ),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(
      height: 1.42,
      color: palette.ink,
    ),
    bodySmall: base.textTheme.bodySmall?.copyWith(
      height: 1.35,
      color: palette.inkMuted,
    ),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: palette.ink,
    ),
  );

  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(22),
    borderSide: BorderSide(color: palette.outline),
  );

  return base.copyWith(
    textTheme: textTheme,
    canvasColor: palette.surface,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: palette.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.headlineSmall?.copyWith(fontSize: 28),
      toolbarHeight: 72,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      hintStyle: textTheme.bodyLarge?.copyWith(color: palette.inkMuted),
      labelStyle: textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
      prefixIconColor: palette.inkMuted,
      suffixIconColor: palette.inkMuted,
      border: inputBorder,
      enabledBorder: inputBorder,
      disabledBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: palette.outline.withValues(alpha: 0.7)),
      ),
      focusedBorder: inputBorder,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.ink,
        side: BorderSide(color: palette.outlineStrong.withValues(alpha: 0.75)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: palette.panelMuted.withValues(alpha: 0.42),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: palette.primaryContainer,
      foregroundColor: palette.ink,
      elevation: 0,
      hoverElevation: 0,
      focusElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: palette.panelMuted,
      selectedColor: palette.primaryContainer,
      secondarySelectedColor: palette.secondaryContainer,
      side: BorderSide(color: palette.outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      labelStyle: textTheme.bodySmall?.copyWith(color: palette.ink),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: palette.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    dividerTheme: DividerThemeData(
      color: palette.outline.withValues(alpha: 0.8),
      thickness: 1,
      space: 1,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      textStyle: textTheme.bodyMedium,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      iconColor: palette.inkMuted,
      textColor: palette.ink,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      subtitleTextStyle: textTheme.bodySmall,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: palette.surfaceStrong,
      contentTextStyle: textTheme.bodyMedium,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(
        palette.primary.withValues(alpha: 0.48),
      ),
      radius: const Radius.circular(999),
      thickness: const WidgetStatePropertyAll(8),
    ),
    extensions: [
      PattoThemeTokens(
        canvasGradient: _solidGradient(palette.background),
        heroGradient: _solidGradient(palette.surfaceStrong),
        panelGradient: _solidGradient(palette.surfaceStrong),
        panelColor: palette.panel,
        panelMutedColor: palette.panelMuted,
        panelStrongColor: palette.surfaceStrong,
        selectionColor: palette.selection,
        outlineSoftColor: palette.outline,
        shadowColor: palette.shadow,
        glowColor: palette.glow,
      ),
    ],
  );
}

class _PattoPalette {
  const _PattoPalette({
    required this.background,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.surface,
    required this.surfaceStrong,
    required this.panel,
    required this.panelMuted,
    required this.inputFill,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.secondary,
    required this.secondaryContainer,
    required this.tertiary,
    required this.tertiaryContainer,
    required this.ink,
    required this.inkMuted,
    required this.outline,
    required this.outlineStrong,
    required this.shadow,
    required this.selection,
    required this.glow,
  });

  final Color background;
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color surface;
  final Color surfaceStrong;
  final Color panel;
  final Color panelMuted;
  final Color inputFill;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color secondary;
  final Color secondaryContainer;
  final Color tertiary;
  final Color tertiaryContainer;
  final Color ink;
  final Color inkMuted;
  final Color outline;
  final Color outlineStrong;
  final Color shadow;
  final Color selection;
  final Color glow;

  static _PattoPalette fromStyle(
    AppThemeStyle style, {
    Brightness brightness = Brightness.light,
  }) {
    if (brightness == Brightness.dark) {
      return switch (style) {
        AppThemeStyle.plainSoft => const _PattoPalette(
          background: Color(0xFF191614),
          backgroundTop: Color(0xFF191614),
          backgroundBottom: Color(0xFF191614),
          surface: Color(0xFF22201D),
          surfaceStrong: Color(0xFF2A2724),
          panel: Color(0xFF24211F),
          panelMuted: Color(0xFF1E1B19),
          inputFill: Color(0xFF2A2623),
          primary: Color(0xFFAAB8C7),
          onPrimary: Color(0xFF1A1C1E),
          primaryContainer: Color(0xFF394656),
          secondary: Color(0xFFD1B9A8),
          secondaryContainer: Color(0xFF4A4037),
          tertiary: Color(0xFFA7C0B3),
          tertiaryContainer: Color(0xFF364941),
          ink: Color(0xFFF3ECE4),
          inkMuted: Color(0xFFB6ADA4),
          outline: Color(0xFF4D443E),
          outlineStrong: Color(0xFF7F746B),
          shadow: Color(0xFF000000),
          selection: Color(0xFF30363B),
          glow: Color(0xFF8193A7),
        ),
        AppThemeStyle.softPastel => const _PattoPalette(
          background: Color(0xFF141B16),
          backgroundTop: Color(0xFF141B16),
          backgroundBottom: Color(0xFF141B16),
          surface: Color(0xFF1D2620),
          surfaceStrong: Color(0xFF253029),
          panel: Color(0xFF1F2922),
          panelMuted: Color(0xFF19211C),
          inputFill: Color(0xFF273229),
          primary: Color(0xFFA4D3BD),
          onPrimary: Color(0xFF102118),
          primaryContainer: Color(0xFF2B4639),
          secondary: Color(0xFFF0C0A8),
          secondaryContainer: Color(0xFF5A4135),
          tertiary: Color(0xFFBED4DE),
          tertiaryContainer: Color(0xFF334650),
          ink: Color(0xFFF1F6F0),
          inkMuted: Color(0xFFABB7AF),
          outline: Color(0xFF3D4A42),
          outlineStrong: Color(0xFF728176),
          shadow: Color(0xFF000000),
          selection: Color(0xFF304136),
          glow: Color(0xFF7DB59A),
        ),
      };
    }

    return switch (style) {
      AppThemeStyle.plainSoft => const _PattoPalette(
        background: Color(0xFFF7F2EC),
        backgroundTop: Color(0xFFFBF8F3),
        backgroundBottom: Color(0xFFF1EBE2),
        surface: Color(0xFFFFFCF8),
        surfaceStrong: Color(0xFFF3ECE3),
        panel: Color(0xFFFFFBF7),
        panelMuted: Color(0xFFF2ECE4),
        inputFill: Color(0xFFF7F1E9),
        primary: Color(0xFF7B8A9A),
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFDCE4EE),
        secondary: Color(0xFF9C8E80),
        secondaryContainer: Color(0xFFEFE2D2),
        tertiary: Color(0xFF8BA398),
        tertiaryContainer: Color(0xFFDCEBE4),
        ink: Color(0xFF362F2B),
        inkMuted: Color(0xFF7A6E66),
        outline: Color(0xFFD7CDC2),
        outlineStrong: Color(0xFFB8AA9D),
        shadow: Color(0xFF65584D),
        selection: Color(0xFFE8ECEF),
        glow: Color(0xFFB9C9D8),
      ),
      AppThemeStyle.softPastel => const _PattoPalette(
        background: Color(0xFFF4F7F1),
        backgroundTop: Color(0xFFF4F7F1),
        backgroundBottom: Color(0xFFF4F7F1),
        surface: Color(0xFFFCFDF9),
        surfaceStrong: Color(0xFFF1F6EE),
        panel: Color(0xFFF8FBF5),
        panelMuted: Color(0xFFEEF4EC),
        inputFill: Color(0xFFF2F6F0),
        primary: Color(0xFF7FAE98),
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFDCEDE2),
        secondary: Color(0xFFD8A88F),
        secondaryContainer: Color(0xFFF4E3D8),
        tertiary: Color(0xFF9FBBC8),
        tertiaryContainer: Color(0xFFDCE9F0),
        ink: Color(0xFF2E332E),
        inkMuted: Color(0xFF6E756D),
        outline: Color(0xFFD5DDD2),
        outlineStrong: Color(0xFFB6C3B4),
        shadow: Color(0xFF6D756B),
        selection: Color(0xFFE7EFE8),
        glow: Color(0xFFBFD6C7),
      ),
    };
  }
}
