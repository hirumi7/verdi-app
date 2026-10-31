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
      textTheme: text.copyWith(
        headlineLarge: text.headlineLarge!.copyWith(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: .34,
        ),
        titleLarge: text.titleLarge!.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: text.bodyLarge!.copyWith(fontSize: 17, height: 1.3),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.all(16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
      ),
    );
  }
}
