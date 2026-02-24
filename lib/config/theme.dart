import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // TOKENS DE COLOR BASE
  static const Color backgroundColor = Color(0xFFFDF6F0);
  static const Color backgroundMid = Color(0xFFF8ECF3);
  static const Color backgroundEdge = Color(0xFFEFE0F5);

  static const Color accentPrimary = Color(0xFFB89FD8);
  static const Color accentLight = Color(0xFFD9C8F0);
  static const Color accentGlow = Color(0xFFCBACEC);
  static const Color accentButton = Color(0xFF9B7DC8);

  static const Color textPrimary = Color(0xFF2D2040);
  static const Color textSecondary = Color(0xFF7A6A8A);
  static const Color textOnDark = Color(0xFFFFFFFF);

  static const Color surfaceWhite = Color(0xFFFFFAF7);
  static const Color navbarBg = Color(0xFF1A1025);

  static const Color errorRed = Color(0xFFEF4444);
  static const Color successGreen = Color(0xFF22C55E);
  static const Color warningOrange = Color(0xFFFB923C);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFD9C8F0), Color(0xFFC4A8E8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const RadialGradient globalBackgroundGradient = RadialGradient(
    center: Alignment(0.0, -0.3),
    radius: 1.2,
    colors: [
      Color(0xFFFEF0E8), // centro: durazno cálido
      Color(0xFFF5E8F2), // medio: rosa suave
      Color(0xFFEDE0F5), // borde: lavanda pálido
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static BoxShadow softShadow = BoxShadow(
    color: accentPrimary.withValues(alpha: 0.10),
    blurRadius: 20,
    offset: const Offset(0, 8),
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: accentButton,
        secondary: accentLight,
        surface: Colors.transparent, // So global background shows through
        error: errorRed,
        onPrimary: Colors.white,
        onSecondary: textPrimary,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 64,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -1.5,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          letterSpacing: 0.2, // Subtitles
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentButton,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          elevation: 0,
          shadowColor: accentPrimary.withValues(alpha: 0.4),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: accentPrimary, width: 1.5),
          foregroundColor: accentButton,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite.withValues(alpha: 0.88),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide:
              BorderSide(color: const Color(0xFFEDD8F0).withValues(alpha: 0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide:
              BorderSide(color: const Color(0xFFEDD8F0).withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: accentButton, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 20,
        ),
        hintStyle: GoogleFonts.inter(
          color: textSecondary.withValues(alpha: 0.5),
          fontSize: 16,
        ),
        labelStyle: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 16,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors
            .transparent, // Custom floating pill will be used instead mostly
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white.withValues(alpha: 0.75),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentButton,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: StadiumBorder(),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentButton;
          return Colors.transparent;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentButton;
          return textSecondary.withValues(alpha: 0.3);
        }),
      ),
      dividerTheme: DividerThemeData(
        color: textSecondary.withValues(alpha: 0.15),
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: surfaceWhite,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: navbarBg,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final LinearGradient gradient;
  final bool isLoading;

  const GradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.gradient = AppTheme.primaryGradient,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: onPressed != null ? gradient : null,
        color: onPressed == null
            ? AppTheme.textSecondary.withValues(alpha: 0.3)
            : null,
        borderRadius: BorderRadius.circular(40), // Stadium
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: gradient.colors.first.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      text,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;

  const GradientAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, style: AppTheme.lightTheme.textTheme.headlineMedium),
      actions: actions,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      automaticallyImplyLeading: showBack,
    );
  }
}
