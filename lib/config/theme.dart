import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Gama principal: escala de granates
  static const Color primaryColor = Color(0xFF6B1024);
  static const Color primaryDark = Color(0xFF4A0B19);
  static const Color primaryLight = Color(0xFF8C1F3B);
  // Color secundario: verde oscuro tipo "botella"
  static const Color accentColor = Color(0xFF2E5F3A);
  // Neutros institucionales: verde botella muy suave y desaturado
  static const Color backgroundColor = Color(0xFFF3F7F4);
  static const Color surfaceColor = Color(0xFFFBFEFC);
  static const Color surfaceMutedColor = Color(0xFFE8F0EA);
  static const Color surfaceContainerLowestColor = Color(0xFFFBFEFC);
  static const Color surfaceContainerLowColor = Color(0xFFF6FAF7);
  static const Color surfaceContainerColor = Color(0xFFF0F5F1);
  static const Color surfaceContainerHighColor = Color(0xFFEAF1EC);
  static const Color surfaceContainerHighestColor = Color(0xFFE3ECE5);
  static const Color surfaceBrightColor = Color(0xFFFBFEFC);
  static const Color surfaceDimColor = Color(0xFFDFE9E2);
  static const Color borderColor = Color(0xFFD8E3DB);
  static const Color borderMutedColor = Color(0xFFC6D5CA);
  static const Color primaryContainerColor = Color(0xFFE3D8D9);
  static const Color primaryFixedDimColor = Color(0xFFD2BEC3);
  static const Color secondaryContainerColor = Color(0xFFDDE8DF);
  static const Color secondaryFixedDimColor = Color(0xFFC4D6C8);
  static const Color onSurfaceVariantColor = Color(0xFF595752);
  static const Color inverseSurfaceColor = Color(0xFF2D2C29);
  static const Color errorColor = Color(0xFFB71C1C);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color adminBorderColor = Color(0x33FFFFFF);
  static const LinearGradient publicCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF8FCF9), Color(0xFFEAF3EC)],
  );
  static const LinearGradient adminCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFCF7F8), Color(0xFFF4E8EB)],
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        error: errorColor,
      ).copyWith(
        surface: surfaceColor,
        onSurface: textPrimary,
        onSurfaceVariant: onSurfaceVariantColor,
        surfaceContainerLowest: surfaceContainerLowestColor,
        surfaceContainerLow: surfaceContainerLowColor,
        surfaceContainer: surfaceContainerColor,
        surfaceContainerHigh: surfaceContainerHighColor,
        surfaceContainerHighest: surfaceContainerHighestColor,
        surfaceBright: surfaceBrightColor,
        surfaceDim: surfaceDimColor,
        surfaceTint: Colors.transparent,
        outline: borderColor,
        outlineVariant: borderMutedColor,
        primaryContainer: primaryContainerColor,
        onPrimaryContainer: primaryDark,
        primaryFixed: primaryContainerColor,
        primaryFixedDim: primaryFixedDimColor,
        onPrimaryFixed: primaryDark,
        onPrimaryFixedVariant: primaryDark,
        secondaryContainer: secondaryContainerColor,
        onSecondaryContainer: const Color(0xFF173A22),
        secondaryFixed: secondaryContainerColor,
        secondaryFixedDim: secondaryFixedDimColor,
        onSecondaryFixed: const Color(0xFF173A22),
        onSecondaryFixedVariant: const Color(0xFF173A22),
        tertiaryContainer: surfaceMutedColor,
        onTertiaryContainer: textPrimary,
        inverseSurface: inverseSurfaceColor,
        onInverseSurface: surfaceColor,
        inversePrimary: primaryLight,
        shadow: Colors.black,
        scrim: Colors.black,
      ),
      scaffoldBackgroundColor: backgroundColor,
      textTheme: GoogleFonts.latoTextTheme().copyWith(
        headlineLarge: GoogleFonts.playfairDisplay(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineSmall: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.lato(
          fontSize: 16,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.lato(
          fontSize: 14,
          color: textSecondary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: borderColor),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          tapTargetSize:
              const WidgetStatePropertyAll(MaterialTapTargetSize.padded),
        ),
      ),
      chipTheme: ChipThemeData(
        materialTapTargetSize: MaterialTapTargetSize.padded,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
