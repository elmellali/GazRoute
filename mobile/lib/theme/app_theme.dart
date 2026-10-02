import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Dominant Carbon Background Family
  static const Color bgBase = Color(0xFF080C12);
  static const Color bgCarbon = Color(0xFF080C12);
  static const Color bgSurface1 = Color(0xFF0E141E);
  static const Color surfaceDark = Color(0xFF0E141E);
  static const Color bgSurface2 = Color(0xFF141C2A);
  static const Color surfaceBright = Color(0xFF141C2A);
  static const Color bgSurface3 = Color(0xFF1A2436);
  static const Color surfaceMuted = Color(0xFF1A2436);
  static const Color bgActive = Color(0xFF202D42);

  // High-Contrast Inks (WCAG AA & AAA)
  static const Color inkPrimary = Color(0xFFF8FAFC);
  static const Color inkSecondary = Color(0xFFCBD5E1);
  static const Color inkMuted = Color(0xFF94A3B8);
  static const Color inkFaint = Color(0xFF64748B);

  // Intentional Sharp Industrial Accent
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentHover = Color(0xFFD97706);
  static const Color accentContrast = Color(0xFF080C12);
  static const Color accentGlow = Color(0x28F59E0B);

  // High-Contrast Functional Semantic Signals
  static const Color signalOk = Color(0xFF10B981);
  static const Color statusGreen = Color(0xFF10B981);
  static const Color signalOkBg = Color(0x1F10B981);
  static const Color signalOkBorder = Color(0xFF059669);

  static const Color signalWarn = Color(0xFFF59E0B);
  static const Color signalWarnBg = Color(0x1FF59E0B);
  static const Color signalWarnBorder = Color(0xFFD97706);

  static const Color signalDanger = Color(0xFFEF4444);
  static const Color statusRed = Color(0xFFEF4444);
  static const Color signalDangerBg = Color(0x24EF4444);
  static const Color signalDangerBorder = Color(0xFFDC2626);

  static const Color signalInfo = Color(0xFF38BDF8);
  static const Color signalInfoBg = Color(0x1F38BDF8);
  static const Color signalInfoBorder = Color(0xFF0284C7);

  // Raw Hairline & Structural Borders
  static const Color borderSubtle = Color(0xFF1E293B);
  static const Color borderRaw = Color(0xFF29384D);
  static const Color borderStrong = Color(0xFF3B4D66);

  // Spacing (Strict multiples of 4px)
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;

  static TextStyle headlineFont(BuildContext context, {
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w700,
    Color color = inkPrimary,
    double? letterSpacing = -0.5,
  }) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    if (isAr) {
      return GoogleFonts.ibmPlexSansArabic(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: 0,
      );
    }
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle headline(BuildContext context, {
    double size = 18,
    FontWeight weight = FontWeight.w700,
    Color color = inkPrimary,
    double? letterSpacing = -0.5,
  }) {
    return headlineFont(
      context,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle bodyFont(BuildContext context, {
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = inkSecondary,
    double? height = 1.5,
  }) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    if (isAr) {
      return GoogleFonts.ibmPlexSansArabic(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );
    }
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static TextStyle body(BuildContext context, {
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = inkSecondary,
    double? height = 1.5,
  }) {
    return bodyFont(
      context,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  static TextStyle label(BuildContext context, {
    double size = 12,
    FontWeight weight = FontWeight.w600,
    Color color = inkMuted,
  }) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    if (isAr) {
      return GoogleFonts.ibmPlexSansArabic(
        fontSize: size,
        fontWeight: weight,
        color: color,
      );
    }
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: 0.5,
    );
  }

  static TextStyle monoFont({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w600,
    Color color = inkPrimary,
  }) {
    return GoogleFonts.spaceMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  static ThemeData themeData(Locale locale) {
    final isAr = locale.languageCode == 'ar';
    final baseTextTheme = isAr
        ? GoogleFonts.ibmPlexSansArabicTextTheme()
        : GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgBase,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: accentContrast,
        secondary: bgSurface3,
        onSecondary: inkPrimary,
        surface: bgSurface1,
        onSurface: inkPrimary,
        error: signalDanger,
        onError: Colors.white,
      ),
      textTheme: baseTextTheme.apply(
        bodyColor: inkSecondary,
        displayColor: inkPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgSurface1,
        foregroundColor: inkPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: (isAr ? GoogleFonts.ibmPlexSansArabic() : GoogleFonts.spaceGrotesk()).copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: inkPrimary,
        ),
        shape: const Border(bottom: BorderSide(color: borderRaw, width: 1)),
      ),
      cardTheme: const CardThemeData(
        color: bgSurface1,
        elevation: 0,
        margin: EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: borderRaw, width: 1),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: bgSurface3,
        labelStyle: TextStyle(color: inkMuted, fontSize: 13, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: inkFaint, fontSize: 13),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: borderRaw, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: signalDanger, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: accentContrast,
          elevation: 0,
          minimumSize: const Size.fromHeight(50),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: accent, width: 1),
          ),
          textStyle: (isAr ? GoogleFonts.ibmPlexSansArabic() : GoogleFonts.spaceGrotesk()).copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: inkPrimary,
          backgroundColor: bgSurface2,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: borderRaw, width: 1),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: (isAr ? GoogleFonts.ibmPlexSansArabic() : GoogleFonts.spaceGrotesk()).copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderSubtle,
        thickness: 1,
        space: 24,
      ),
    );
  }
}

/// Architectural Raw Panel with Optional Accent Bar
class RawPanel extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  final Color? leftBarColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color backgroundColor;

  const RawPanel({
    super.key,
    required this.child,
    this.borderColor,
    this.leftBarColor,
    this.padding = const EdgeInsets.all(AppTheme.space16),
    this.margin = const EdgeInsets.only(bottom: AppTheme.space16),
    this.backgroundColor = AppTheme.bgSurface1,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(color: borderColor ?? AppTheme.borderRaw, width: 1),
          bottom: BorderSide(color: borderColor ?? AppTheme.borderRaw, width: 1),
          left: isRtl
              ? BorderSide(color: borderColor ?? AppTheme.borderRaw, width: 1)
              : BorderSide(color: leftBarColor ?? borderColor ?? AppTheme.borderRaw, width: leftBarColor != null ? 3.0 : 1.0),
          right: isRtl
              ? BorderSide(color: leftBarColor ?? borderColor ?? AppTheme.borderRaw, width: leftBarColor != null ? 3.0 : 1.0)
              : BorderSide(color: borderColor ?? AppTheme.borderRaw, width: 1),
        ),
      ),
      child: child,
    );
  }
}

/// Multi-Channel Status Signal Badge (Icon + Prefix + Border)
enum BadgeStatus { ok, warn, danger, info, neutral }

class StatusBadge extends StatelessWidget {
  final String label;
  final dynamic status; // accepts BadgeStatus or String

  const StatusBadge({
    super.key,
    required this.label,
    this.status = BadgeStatus.neutral,
  });

  @override
  Widget build(BuildContext context) {
    BadgeStatus badgeStatus;
    if (status is BadgeStatus) {
      badgeStatus = status as BadgeStatus;
    } else if (status is String) {
      final s = (status as String).toUpperCase();
      if (s == 'COMPLETED' || s == 'ARRIVED' || s == 'OK' || s == 'ONLINE') {
        badgeStatus = BadgeStatus.ok;
      } else if (s == 'EN_ROUTE' || s == 'WARN' || s == 'NEARBY') {
        badgeStatus = BadgeStatus.warn;
      } else if (s == 'CRITICAL' || s == 'EXCEPTION' || s == 'DANGER') {
        badgeStatus = BadgeStatus.danger;
      } else if (s == 'IN_SERVICE' || s == 'PENDING' || s == 'INFO') {
        badgeStatus = BadgeStatus.info;
      } else {
        badgeStatus = BadgeStatus.neutral;
      }
    } else {
      badgeStatus = BadgeStatus.neutral;
    }

    Color bg;
    Color fg;
    Color border;
    String prefix;

    switch (badgeStatus) {
      case BadgeStatus.ok:
        bg = AppTheme.signalOkBg;
        fg = AppTheme.signalOk;
        border = AppTheme.signalOkBorder;
        prefix = '● ';
        break;
      case BadgeStatus.warn:
        bg = AppTheme.signalWarnBg;
        fg = AppTheme.signalWarn;
        border = AppTheme.signalWarnBorder;
        prefix = '▲ ';
        break;
      case BadgeStatus.danger:
        bg = AppTheme.signalDangerBg;
        fg = AppTheme.signalDanger;
        border = AppTheme.signalDangerBorder;
        prefix = '🚨 ';
        break;
      case BadgeStatus.info:
        bg = AppTheme.signalInfoBg;
        fg = AppTheme.signalInfo;
        border = AppTheme.signalInfoBorder;
        prefix = '■ ';
        break;
      case BadgeStatus.neutral:
        bg = AppTheme.bgSurface3;
        fg = AppTheme.inkSecondary;
        border = AppTheme.borderRaw;
        prefix = '';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        '$prefix$label',
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
