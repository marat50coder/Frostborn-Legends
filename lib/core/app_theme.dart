import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  const AppColors._();

  static const Color night = Color(0xFF060B1C);
  static const Color deepNavy = Color(0xFF0C1836);
  static const Color navy = Color(0xFF15275A);
  static const Color ice = Color(0xFF7FD8FF);
  static const Color iceDeep = Color(0xFF2E8FD6);
  static const Color gold = Color(0xFFF7CE4B);
  static const Color goldDark = Color(0xFF9A6B12);
  static const Color crimson = Color(0xFF7E0E1C);
  static const Color crimsonLight = Color(0xFFD62B3E);
  static const Color emerald = Color(0xFF2FBF6B);

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFFFF3B0), Color(0xFFF7CE4B), Color(0xFFBE8419)],
  );

  static const LinearGradient iceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFEAF9FF), Color(0xFF7FD8FF), Color(0xFF2E8FD6)],
  );

  static const LinearGradient panelGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xE60E1C42), Color(0xF2060B1C)],
  );
}

/// Hides the Android navigation bar and status bar. The bars briefly reappear
/// when the user swipes from an edge, then tuck themselves away again.
Future<void> hideSystemBars() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );
}

class AppTheme {
  const AppTheme._();

  static ThemeData build() {
    final ThemeData base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.night,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.gold,
        secondary: AppColors.ice,
        surface: AppColors.deepNavy,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}

/// Text styles shared across the game. Kept as helpers so headings stay
/// consistent without a bundled display font.
class AppText {
  const AppText._();

  static TextStyle title(double size) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w900,
    letterSpacing: size * 0.06,
    height: 1.05,
  );

  /// Shared face for every menu and chrome button, so PLAY, PAYTABLE and the
  /// policy links all read as the same type regardless of colour or size.
  static TextStyle button(double size) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.4,
    height: 1.05,
  );

  static TextStyle body(double size, {FontWeight weight = FontWeight.w600}) =>
      TextStyle(fontSize: size, fontWeight: weight, letterSpacing: 0.3);

  static TextStyle numeric(double size) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.5,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );
}
