import 'package:flutter/material.dart';
import 'fonts.dart';

import '../models/parcel.dart';

class AppTheme {
  // Palette extraite du SendProcolis Design System.
  static const Color green50 = Color(0xFFE7F7EE);
  static const Color green100 = Color(0xFFC5ECD6);
  static const Color green500 = Color(0xFF0FA958);
  static const Color green600 = Color(0xFF079A4B);
  static const Color green700 = Color(0xFF07803E);
  static const Color green800 = Color(0xFF0A6334);

  static const Color green300 = Color(0xFF4FC684);

  static const Color teal50 = Color(0xFFE4F4F2);
  static const Color teal100 = Color(0xFFBFE6E2);
  static const Color teal400 = Color(0xFF199A92);
  static const Color teal500 = Color(0xFF018982);
  static const Color teal600 = Color(0xFF066E68);
  static const Color teal700 = Color(0xFF0B5650);
  static const Color teal800 = Color(0xFF0C453F);

  static const Color deep500 = Color(0xFF0C6E7D);
  static const Color deep700 = Color(0xFF0B4853);
  static const Color amber50 = Color(0xFFFFF6E2);
  static const Color amber100 = Color(0xFFFDE9B8);
  static const Color amber200 = Color(0xFFFBD477);
  static const Color amber400 = Color(0xFFFCA202);
  static const Color amber500 = Color(0xFFE98C00);
  static const Color amber600 = Color(0xFFC77600);
  static const Color amber700 = Color(0xFF9A5B00);
  static const Color amberOnFg = Color(0xFF3A2600); // texte sur fond ambre
  static const Color red50 = Color(0xFFFDEAE6);
  static const Color red100 = Color(0xFFFACABF);
  static const Color red400 = Color(0xFFE5240F);
  static const Color red500 = Color(0xFFC81C08);
  static const Color infoSoft = Color(0xFFE4F1F4);

  static const Color slate0 = Color(0xFFFFFFFF);
  static const Color slate50 = Color(0xFFF6F8F8);
  static const Color slate100 = Color(0xFFEDF1F1);
  static const Color slate200 = Color(0xFFDDE4E4);
  static const Color slate300 = Color(0xFFC4CFCF);
  static const Color slate400 = Color(0xFF94A3A3);
  static const Color slate500 = Color(0xFF677474);
  static const Color slate600 = Color(0xFF4A5656);
  static const Color slate700 = Color(0xFF333D3D);
  static const Color slate800 = Color(0xFF1F2727);
  static const Color slate900 = Color(0xFF111717);

  static const Color primary = teal500;
  static const Color primaryLight = teal50;
  static const Color secondary = amber400;
  static const Color error = red400;
  static const Color backgroundColor = slate50;
  static const Color cardColor = slate0;
  static const Color textPrimary = slate900;
  static const Color textSecondary = slate500;
  static const Color textBody = slate700;
  static const Color successColor = green600;
  static const Color warningColor = amber500;
  static const Color errorColor = red400;

  // Alias conservés pour les écrans existants.
  static const Color primaryBlue = teal500;
  static const Color lightBlue = teal50;
  static const Color darkBlue = teal800;

  static const double radiusXs = 6;
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
  static const double radiusPill = 999;
  static const double screenMaxWidth = 440;

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [green500, teal500, deep500],
    stops: [0, 0.55, 1],
  );

  static const LinearGradient amberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [amber400, amber500],
  );

  static List<BoxShadow> softShadow({double alpha = 0.08}) => [
        BoxShadow(
          color: const Color(0xFF0B464F).withOpacity( alpha),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> brandShadow() => [
        BoxShadow(
          color: primary.withOpacity( 0.28),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> amberShadow() => [
        BoxShadow(
          color: amber400.withOpacity( 0.30),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ];

  // Ombres discrètes (spec design : xs / sm).
  static List<BoxShadow> shadowXs() => [
        BoxShadow(
          color: const Color(0xFF0B464F).withOpacity( 0.06),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> shadowSm() => [
        BoxShadow(
          color: const Color(0xFF0B464F).withOpacity( 0.08),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static ThemeData lightTheme = _buildLightTheme();

  static ThemeData darkTheme = _buildLightTheme().copyWith(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: slate900,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: primary,
      secondary: secondary,
      error: error,
      surface: slate800,
    ),
  );

  static ThemeData _buildLightTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: secondary,
        error: error,
        surface: cardColor,
      ),
    );

    final displayTextTheme =
        base.textTheme.apply(fontFamily: AppFonts.display);
    final bodyTextTheme = base.textTheme.apply(fontFamily: AppFonts.body);

    return base.copyWith(
      primaryColor: primary,
      scaffoldBackgroundColor: backgroundColor,
      textTheme: bodyTextTheme.copyWith(
        displayLarge: displayTextTheme.displayLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w800,
        ),
        headlineLarge: displayTextTheme.headlineLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: displayTextTheme.headlineMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w800,
        ),
        headlineSmall: displayTextTheme.headlineSmall?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: displayTextTheme.titleLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: displayTextTheme.titleMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: bodyTextTheme.bodyLarge?.copyWith(color: slate700),
        bodyMedium: bodyTextTheme.bodyMedium?.copyWith(color: slate700),
        bodySmall: bodyTextTheme.bodySmall?.copyWith(color: slate500),
        labelLarge: displayTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cardColor,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(fontFamily: AppFonts.display, 
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        prefixIconColor: primary,
        suffixIconColor: slate500,
        labelStyle: const TextStyle(color: slate600, fontSize: 13),
        hintStyle: const TextStyle(color: slate400, fontSize: 14),
        helperStyle: const TextStyle(color: slate500, fontSize: 12),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: _inputBorder(slate300),
        enabledBorder: _inputBorder(slate200),
        focusedBorder: _inputBorder(primary, width: 2),
        errorBorder: _inputBorder(error),
        focusedErrorBorder: _inputBorder(error, width: 2),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: slate200,
          disabledForegroundColor: slate400,
          minimumSize: const Size(double.infinity, 50),
          elevation: 0,
          textStyle: const TextStyle(fontFamily: AppFonts.display, 
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: teal600,
          textStyle: const TextStyle(fontFamily: AppFonts.display, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: teal500),
          textStyle: const TextStyle(fontFamily: AppFonts.display, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: slate200),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: slate100,
        selectedColor: teal50,
        labelStyle: const TextStyle(fontFamily: AppFonts.display, 
          color: textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        secondaryLabelStyle: const TextStyle(fontFamily: AppFonts.display, 
          color: teal700,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: slate200),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: slate200,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardColor,
        selectedItemColor: primary,
        unselectedItemColor: slate500,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: slate900,
        contentTextStyle: const TextStyle(fontFamily: AppFonts.body, color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        titleTextStyle: const TextStyle(fontFamily: AppFonts.display, 
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: const TextStyle(fontFamily: AppFonts.body, color: slate700),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? primary : cardColor,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: slate300),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXs),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMd),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static ProcolisStatusColors statusColors(ParcelStatus status) {
    switch (status) {
      case ParcelStatus.pending:
        return const ProcolisStatusColors(amber700, amber50, amber400);
      case ParcelStatus.free:
        return const ProcolisStatusColors(
            Color(0xFF1D4FB8), Color(0xFFE7EEFC), Color(0xFF2563EB));
      case ParcelStatus.confirmed:
        return const ProcolisStatusColors(teal600, teal50, teal500);
      case ParcelStatus.pickedUp:
        return const ProcolisStatusColors(
            Color(0xFF5B27B0), Color(0xFFEFE7FB), Color(0xFF7C3AED));
      case ParcelStatus.inTransit:
        return const ProcolisStatusColors(green700, green50, green500);
      case ParcelStatus.arrived:
        return const ProcolisStatusColors(
            Color(0xFF0A6072), Color(0xFFE2F1F4), deep500);
      case ParcelStatus.outForDelivery:
        return const ProcolisStatusColors(
            Color(0xFFB34A00), Color(0xFFFCEEE2), Color(0xFFEA580C));
      case ParcelStatus.delivered:
        return const ProcolisStatusColors(green800, green100, green600);
      case ParcelStatus.cancelled:
        return const ProcolisStatusColors(red500, red50, red400);
    }
  }

  static TextStyle mono({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w700,
    Color color = textPrimary,
  }) {
    return TextStyle(fontFamily: AppFonts.monoFamily, 
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
}

class ProcolisStatusColors {
  final Color foreground;
  final Color background;
  final Color dot;

  const ProcolisStatusColors(this.foreground, this.background, this.dot);
}

extension ThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  Color get primaryColor => AppTheme.primary;
  Color get backgroundColor => AppTheme.backgroundColor;
  Color get cardColor => AppTheme.cardColor;
  Color get textPrimary => AppTheme.textPrimary;
  Color get textSecondary => AppTheme.textSecondary;
  Color get successColor => AppTheme.successColor;
  Color get warningColor => AppTheme.warningColor;
  Color get errorColor => AppTheme.errorColor;
}
