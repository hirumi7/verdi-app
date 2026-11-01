import 'app_layout.dart';

import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final paper = Color(dark ? 0xff0f1411 : 0xfff2f3ef);
    final surface = Color(dark ? 0xff1a201c : 0xffffffff);
    final ink = Color(dark ? 0xffedf1ec : 0xff131b16);
    final muted = Color(dark ? 0xffb6bfb8 : 0xff4c574f);
    final leaf = Color(dark ? 0xff7cc792 : 0xff1f6b41);
    final onLeaf = dark ? const Color(0xff0f1411) : Colors.white;
    final scheme = ColorScheme.fromSeed(seedColor: leaf, brightness: brightness)
        .copyWith(
          primary: leaf,
          onPrimary: onLeaf,
          surface: surface,
          onSurface: ink,
          onSurfaceVariant: muted,
          outline: muted,
          error: Color(dark ? 0xffee9a78 : 0xffb04a26),
          primaryContainer: Color(dark ? 0xff1f3527 : 0xffe1eee4),
          onPrimaryContainer: leaf,
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
    final text = base.textTheme.apply(bodyColor: ink, displayColor: ink);
    return base.copyWith(
      scaffoldBackgroundColor: paper,
      dividerColor: Color(dark ? 0xff374238 : 0xffdce0d7),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Color(dark ? 0xff151b17 : 0xfff8f9f6),
        indicatorColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 10,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected) ? leaf : muted,
          ),
        ),
      ),
      textTheme: text.copyWith(
        displayLarge: text.displayLarge!.copyWith(
          fontSize: 40,
          height: 44 / 40,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        displayMedium: text.displayMedium!.copyWith(
          fontSize: 34,
          height: 41 / 34,
          fontWeight: FontWeight.w700,
          letterSpacing: .34,
        ),
        displaySmall: text.displaySmall!.copyWith(
          fontSize: 28,
          height: 34 / 28,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        headlineLarge: text.headlineLarge!.copyWith(
          fontSize: 34,
          height: 41 / 34,
          fontWeight: FontWeight.w700,
          letterSpacing: .34,
        ),
        headlineMedium: text.headlineMedium!.copyWith(
          fontSize: 28,
          height: 34 / 28,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        headlineSmall: text.headlineSmall!.copyWith(
          fontSize: 20,
          height: 25 / 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        titleLarge: text.titleLarge!.copyWith(
          fontSize: 22,
          height: 28 / 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        titleMedium: text.titleMedium!.copyWith(
          fontSize: 17,
          height: 22 / 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        titleSmall: text.titleSmall!.copyWith(
          fontSize: 15,
          height: 20 / 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        bodyLarge: text.bodyLarge!.copyWith(
          fontSize: 17,
          height: 22 / 17,
          letterSpacing: 0,
        ),
        bodyMedium: text.bodyMedium!.copyWith(
          fontSize: 17,
          height: 22 / 17,
          letterSpacing: 0,
        ),
        bodySmall: text.bodySmall!.copyWith(
          fontSize: 15,
          height: 20 / 15,
          letterSpacing: 0,
        ),
        labelLarge: text.labelLarge!.copyWith(
          fontSize: 15,
          height: 20 / 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        labelMedium: text.labelMedium!.copyWith(
          fontSize: 13,
          height: 18 / 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        labelSmall: text.labelSmall!.copyWith(
          fontSize: 12,
          height: 16 / 12,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: leaf, width: 2),
        ),
        contentPadding: AppLayout.cardPadding,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: AppLayout.actionPadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: AppLayout.actionPadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppLayout.gutter,
        ),
        minTileHeight: 48,
        horizontalTitleGap: 12,
        minVerticalPadding: 8,
        titleTextStyle: text.titleMedium!.copyWith(
          fontSize: 17,
          height: 22 / 17,
          fontWeight: FontWeight.w600,
          color: ink,
          letterSpacing: 0,
        ),
        subtitleTextStyle: text.bodySmall!.copyWith(
          fontSize: 15,
          height: 20 / 15,
          color: muted,
          letterSpacing: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
    );
  }
}
