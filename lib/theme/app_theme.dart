import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'fonts.dart';

import '../models/parcel.dart';

/// Palette et thèmes de l'application.
///
/// Les jetons de couleur sont des *getters* et non des constantes : ils se
/// résolvent selon la luminosité courante ([applyBrightness]), ce qui permet
/// au mode sombre de traverser les ~3000 usages de `AppTheme.xxx` sans avoir à
/// passer un `BuildContext` partout. Seules restent constantes les valeurs
/// identiques dans les deux modes (dégradés de marque, rayons, `amberOnFg`).
class AppTheme {
  static Brightness _brightness = Brightness.light;

  /// Luminosité effective appliquée aux jetons de couleur.
  static Brightness get brightness => _brightness;

  static bool get isDark => _brightness == Brightness.dark;

  /// Bascule la palette. À appeler avant de construire l'arbre de widgets
  /// (cf. `ProColisApp`), car les jetons sont lus à la construction.
  static void applyBrightness(Brightness value) => _brightness = value;

  /// Choisit la valeur claire ou sombre du jeton.
  static Color _tone(Color light, Color dark) => isDark ? dark : light;

  /// Version publique de [_tone], pour les couleurs propres à un écran ou à un
  /// rôle qui ne font pas partie de la palette.
  static Color tone(Color light, Color dark) => _tone(light, dark);

  // ---- Palette extraite du SendProcolis Design System (clair → sombre) ----
  // En mode sombre, les tons « 50/100 » deviennent des fonds profonds et les
  // tons « 600/700/800 » deviennent des couleurs de texte claires : les paires
  // fond/texte du design system restent donc lisibles sans être inversées site
  // par site.
  static Color get green50 => _tone(const Color(0xFFE7F7EE), const Color(0xFF0E2A1B));
  static Color get green100 => _tone(const Color(0xFFC5ECD6), const Color(0xFF143B26));
  static Color get green500 => _tone(const Color(0xFF0FA958), const Color(0xFF22C46B));
  static Color get green600 => _tone(const Color(0xFF079A4B), const Color(0xFF17B45C));
  static Color get green700 => _tone(const Color(0xFF07803E), const Color(0xFF4FC684));
  static Color get green800 => _tone(const Color(0xFF0A6334), const Color(0xFF78D9A2));

  static Color get green300 => _tone(const Color(0xFF4FC684), const Color(0xFF7BE0A8));

  static Color get teal50 => _tone(const Color(0xFFE4F4F2), const Color(0xFF0C2A28));
  static Color get teal100 => _tone(const Color(0xFFBFE6E2), const Color(0xFF113A36));
  static Color get teal400 => _tone(const Color(0xFF199A92), const Color(0xFF33C3B8));
  static Color get teal500 => _tone(const Color(0xFF018982), const Color(0xFF12ADA3));
  static Color get teal600 => _tone(const Color(0xFF066E68), const Color(0xFF35C4BA));
  static Color get teal700 => _tone(const Color(0xFF0B5650), const Color(0xFF5AD6CD));
  static Color get teal800 => _tone(const Color(0xFF0C453F), const Color(0xFF7FE3DB));

  static Color get deep500 => _tone(const Color(0xFF0C6E7D), const Color(0xFF128A9C));
  static Color get deep700 => _tone(const Color(0xFF0B4853), const Color(0xFF0F6273));
  static Color get amber50 => _tone(const Color(0xFFFFF6E2), const Color(0xFF2C2007));
  static Color get amber100 => _tone(const Color(0xFFFDE9B8), const Color(0xFF3C2C0A));
  static Color get amber200 => _tone(const Color(0xFFFBD477), const Color(0xFFFBD477));
  static Color get amber400 => _tone(const Color(0xFFFCA202), const Color(0xFFFFB627));
  static Color get amber500 => _tone(const Color(0xFFE98C00), const Color(0xFFF5A31A));
  static Color get amber600 => _tone(const Color(0xFFC77600), const Color(0xFFFFC24D));
  static Color get amber700 => _tone(const Color(0xFF9A5B00), const Color(0xFFFBD477));

  /// Texte posé sur un aplat ambre : l'ambre reste vif dans les deux modes.
  static const Color amberOnFg = Color(0xFF3A2600);

  static Color get red50 => _tone(const Color(0xFFFDEAE6), const Color(0xFF2E120D));
  static Color get red100 => _tone(const Color(0xFFFACABF), const Color(0xFF3F1913));
  static Color get red400 => _tone(const Color(0xFFE5240F), const Color(0xFFF2503C));
  static Color get red500 => _tone(const Color(0xFFC81C08), const Color(0xFFFF7A66));
  static Color get infoSoft => _tone(const Color(0xFFE4F1F4), const Color(0xFF10272E));

  // Rampe neutre : inversée en mode sombre (slate0 = surface, slate900 = texte).
  static Color get slate0 => _tone(const Color(0xFFFFFFFF), const Color(0xFF161C1C));
  static Color get slate50 => _tone(const Color(0xFFF6F8F8), const Color(0xFF0E1313));
  static Color get slate100 => _tone(const Color(0xFFEDF1F1), const Color(0xFF1D2424));
  static Color get slate200 => _tone(const Color(0xFFDDE4E4), const Color(0xFF27302F));
  static Color get slate300 => _tone(const Color(0xFFC4CFCF), const Color(0xFF364040));
  static Color get slate400 => _tone(const Color(0xFF94A3A3), const Color(0xFF6D7A79));
  static Color get slate500 => _tone(const Color(0xFF677474), const Color(0xFF94A0A0));
  static Color get slate600 => _tone(const Color(0xFF4A5656), const Color(0xFFAEB9B9));
  static Color get slate700 => _tone(const Color(0xFF333D3D), const Color(0xFFCBD4D4));
  static Color get slate800 => _tone(const Color(0xFF1F2727), const Color(0xFFE3E9E9));
  static Color get slate900 => _tone(const Color(0xFF111717), const Color(0xFFF3F7F7));

  static Color get primary => teal500;
  static Color get primaryLight => teal50;
  static Color get secondary => amber400;
  static Color get error => red400;
  static Color get backgroundColor => slate50;
  static Color get cardColor => slate0;
  static Color get textPrimary => slate900;
  static Color get textSecondary => slate500;
  static Color get textBody => slate700;
  static Color get successColor => green600;
  static Color get warningColor => amber500;
  static Color get errorColor => red400;

  // Alias conservés pour les écrans existants.
  static Color get primaryBlue => teal500;
  static Color get lightBlue => teal50;
  static Color get darkBlue => teal800;

  static const double radiusXs = 6;
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
  static const double radiusPill = 999;
  static const double screenMaxWidth = 440;

  // Dégradés de marque : mêmes teintes dans les deux modes (identité visuelle),
  // donc constants et utilisables dans des expressions `const`.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0FA958), Color(0xFF018982), Color(0xFF0C6E7D)],
    stops: [0, 0.55, 1],
  );

  static const LinearGradient amberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFCA202), Color(0xFFE98C00)],
  );

  /// Teinte des ombres : le vert-bleu du design system en clair, un noir franc
  /// en sombre (une ombre colorée sur fond sombre ne se voit pas).
  static Color get _shadowTint =>
      _tone(const Color(0xFF0B464F), const Color(0xFF000000));

  static double _shadowAlpha(double light, double dark) => isDark ? dark : light;

  static List<BoxShadow> softShadow({double alpha = 0.08}) => [
        BoxShadow(
          color: _shadowTint.withValues(alpha: isDark ? alpha * 3 : alpha),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> brandShadow() => [
        BoxShadow(
          color: primary.withValues(alpha: isDark ? 0.36 : 0.28),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> amberShadow() => [
        BoxShadow(
          color: amber400.withValues(alpha: 0.30),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ];

  // Ombres discrètes (spec design : xs / sm).
  static List<BoxShadow> shadowXs() => [
        BoxShadow(
          color: _shadowTint.withValues(alpha: _shadowAlpha(0.06, 0.28)),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> shadowSm() => [
        BoxShadow(
          color: _shadowTint.withValues(alpha: _shadowAlpha(0.08, 0.34)),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static ThemeData get lightTheme => themeFor(Brightness.light);

  static ThemeData get darkTheme => themeFor(Brightness.dark);

  /// Construit le thème d'une luminosité donnée en résolvant les jetons dans ce
  /// mode, puis restaure la luminosité courante (celle de l'arbre affiché).
  static ThemeData themeFor(Brightness brightness) {
    final previous = _brightness;
    _brightness = brightness;
    final theme = _buildTheme(brightness);
    _brightness = previous;
    return theme;
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: primary,
        secondary: secondary,
        error: error,
        surface: cardColor,
        onSurface: textPrimary,
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
        // Icônes de la barre système lisibles sur la barre d'app.
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.display,
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
        labelStyle: TextStyle(color: slate600, fontSize: 13),
        hintStyle: TextStyle(color: slate400, fontSize: 14),
        helperStyle: TextStyle(color: slate500, fontSize: 12),
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
          textStyle: const TextStyle(
            fontFamily: AppFonts.display,
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
          textStyle: const TextStyle(
              fontFamily: AppFonts.display, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: teal500),
          textStyle: const TextStyle(
              fontFamily: AppFonts.display, fontWeight: FontWeight.w700),
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
          side: BorderSide(color: slate200),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: slate100,
        selectedColor: teal50,
        labelStyle: TextStyle(
          fontFamily: AppFonts.display,
          color: textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: AppFonts.display,
          color: teal700,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: slate200),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: slate200,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardColor,
        selectedItemColor: primary,
        unselectedItemColor: slate500,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      snackBarTheme: SnackBarThemeData(
        // En sombre, le fond « encre » du mode clair deviendrait blanc :
        // on garde une surface contrastée avec le fond de page.
        backgroundColor: isDark ? slate100 : slate900,
        contentTextStyle: TextStyle(
          fontFamily: AppFonts.body,
          color: isDark ? textPrimary : Colors.white,
        ),
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
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.display,
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle:
            TextStyle(fontFamily: AppFonts.body, color: slate700),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? primary : cardColor,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: BorderSide(color: slate300),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXs),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
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
        return ProcolisStatusColors(amber700, amber50, amber400);
      case ParcelStatus.free:
        return ProcolisStatusColors(
          _tone(const Color(0xFF1D4FB8), const Color(0xFF9DB8F7)),
          _tone(const Color(0xFFE7EEFC), const Color(0xFF131E36)),
          const Color(0xFF2563EB),
        );
      case ParcelStatus.negotiating:
        return ProcolisStatusColors(
          _tone(const Color(0xFFC24A00), const Color(0xFFFFB27A)),
          _tone(const Color(0xFFFFF3E0), const Color(0xFF2E1808)),
          Colors.deepOrange,
        );
      case ParcelStatus.confirmed:
        return ProcolisStatusColors(teal600, teal50, teal500);
      case ParcelStatus.pickedUp:
        return ProcolisStatusColors(
          _tone(const Color(0xFF5B27B0), const Color(0xFFC4A7F5)),
          _tone(const Color(0xFFEFE7FB), const Color(0xFF1F1533)),
          const Color(0xFF7C3AED),
        );
      case ParcelStatus.inTransit:
        return ProcolisStatusColors(green700, green50, green500);
      case ParcelStatus.arrived:
        return ProcolisStatusColors(
          _tone(const Color(0xFF0A6072), const Color(0xFF7FD4E6)),
          _tone(const Color(0xFFE2F1F4), const Color(0xFF0D262D)),
          deep500,
        );
      case ParcelStatus.outForDelivery:
        return ProcolisStatusColors(
          _tone(const Color(0xFFB34A00), const Color(0xFFFFB27A)),
          _tone(const Color(0xFFFCEEE2), const Color(0xFF2E1808)),
          const Color(0xFFEA580C),
        );
      case ParcelStatus.delivered:
        return ProcolisStatusColors(green800, green100, green600);
      case ParcelStatus.cancelled:
        return ProcolisStatusColors(red500, red50, red400);
    }
  }

  static TextStyle mono({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: AppFonts.monoFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? textPrimary,
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
