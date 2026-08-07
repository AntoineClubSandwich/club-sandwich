import 'package:flutter/painting.dart';

/// Color tokens for the Club Sandwich design system.
///
/// `primary` (`#EA5133`) and `secondary` (`#293283`) are sampled directly
/// from the real Club Sandwich logo — not invented. Every other token is a
/// deliberately restrained, desaturated neutral so the two brand colors
/// stay the only saturated accents on the page (Linear/Stripe/Notion-style
/// "calm premium", not Material defaults).
class DsColorTokens {
  const DsColorTokens({
    required this.primary,
    required this.primaryHover,
    required this.primaryPressed,
    required this.primarySelectedBg,
    required this.primaryDisabled,
    required this.secondary,
    required this.secondaryHover,
    required this.secondaryPressed,
    required this.secondarySelectedBg,
    required this.secondaryDisabled,
    required this.canvas,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.borderSubtle,
    required this.borderFocus,
    required this.borderStrong,
    required this.success,
    required this.successBg,
    required this.successHover,
    required this.warning,
    required this.warningBg,
    required this.warningHover,
    required this.error,
    required this.errorBg,
    required this.errorHover,
    required this.info,
    required this.infoBg,
    required this.infoHover,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.textOnColor,
    required this.neutralHoverOverlay,
    required this.neutralPressedOverlay,
    required this.neutralSelectedBg,
    required this.disabledBg,
  });

  final Color primary;
  final Color primaryHover;
  final Color primaryPressed;
  final Color primarySelectedBg;
  final Color primaryDisabled;

  final Color secondary;
  final Color secondaryHover;
  final Color secondaryPressed;
  final Color secondarySelectedBg;
  final Color secondaryDisabled;

  final Color canvas;
  final Color surface;
  final Color surfaceElevated;

  final Color border;
  final Color borderSubtle;
  final Color borderFocus;

  /// Structural "ink" border/shadow color for the neo-brutalist surfaces
  /// (`DsCard`, buttons, chips): a thick outline or a hard offset shadow,
  /// as opposed to [border]'s hairline dividers. Same hex as [textPrimary]
  /// — it's the same near-black ink, just named for its structural role.
  final Color borderStrong;

  final Color success;
  final Color successBg;
  final Color successHover;

  final Color warning;
  final Color warningBg;
  final Color warningHover;

  final Color error;
  final Color errorBg;
  final Color errorHover;

  final Color info;
  final Color infoBg;
  final Color infoHover;

  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color textOnColor;

  final Color neutralHoverOverlay;
  final Color neutralPressedOverlay;
  final Color neutralSelectedBg;
  final Color disabledBg;

  static const DsColorTokens light = DsColorTokens(
    primary: Color(0xFFEA5133),
    primaryHover: Color(0xFFD6431F),
    primaryPressed: Color(0xFFB93A1A),
    primarySelectedBg: Color(0xFFFCE9E3),
    primaryDisabled: Color(0x62EA5133), // #EA5133 @ 38%
    secondary: Color(0xFF293283),
    secondaryHover: Color(0xFF212868),
    secondaryPressed: Color(0xFF1A2050),
    secondarySelectedBg: Color(0xFFE7E9F7),
    secondaryDisabled: Color(0x62293283), // #293283 @ 38%
    canvas: Color(0xFFFAFBFC),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    border: Color(0xFFE5E7EB),
    borderSubtle: Color(0xFFEEF0F3),
    borderFocus: Color(0xFFEA5133),
    borderStrong: Color(0xFF14161A),
    success: Color(0xFF1F9254),
    successBg: Color(0xFFE7F6EE),
    successHover: Color(0xFF187A45),
    warning: Color(0xFFC8850E),
    warningBg: Color(0xFFFCF1DC),
    warningHover: Color(0xFFA66C0B),
    error: Color(0xFFD92D20),
    errorBg: Color(0xFFFDECEA),
    errorHover: Color(0xFFB7241A),
    info: Color(0xFF2970D6),
    infoBg: Color(0xFFEAF2FD),
    infoHover: Color(0xFF1F5BB0),
    textPrimary: Color(0xFF14161A),
    textSecondary: Color(0xFF5B6270),
    textDisabled: Color(0xFF9AA1AE),
    textOnColor: Color(0xFFFFFFFF),
    neutralHoverOverlay: Color(0x0A000000), // #000000 @ 4%
    neutralPressedOverlay: Color(0x14000000), // #000000 @ 8%
    neutralSelectedBg: Color(0xFFF1F2F4),
    disabledBg: Color(0xFFF1F2F4),
  );

  DsColorTokens lerp(DsColorTokens other, double t) {
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return DsColorTokens(
      primary: c(primary, other.primary),
      primaryHover: c(primaryHover, other.primaryHover),
      primaryPressed: c(primaryPressed, other.primaryPressed),
      primarySelectedBg: c(primarySelectedBg, other.primarySelectedBg),
      primaryDisabled: c(primaryDisabled, other.primaryDisabled),
      secondary: c(secondary, other.secondary),
      secondaryHover: c(secondaryHover, other.secondaryHover),
      secondaryPressed: c(secondaryPressed, other.secondaryPressed),
      secondarySelectedBg: c(secondarySelectedBg, other.secondarySelectedBg),
      secondaryDisabled: c(secondaryDisabled, other.secondaryDisabled),
      canvas: c(canvas, other.canvas),
      surface: c(surface, other.surface),
      surfaceElevated: c(surfaceElevated, other.surfaceElevated),
      border: c(border, other.border),
      borderSubtle: c(borderSubtle, other.borderSubtle),
      borderFocus: c(borderFocus, other.borderFocus),
      borderStrong: c(borderStrong, other.borderStrong),
      success: c(success, other.success),
      successBg: c(successBg, other.successBg),
      successHover: c(successHover, other.successHover),
      warning: c(warning, other.warning),
      warningBg: c(warningBg, other.warningBg),
      warningHover: c(warningHover, other.warningHover),
      error: c(error, other.error),
      errorBg: c(errorBg, other.errorBg),
      errorHover: c(errorHover, other.errorHover),
      info: c(info, other.info),
      infoBg: c(infoBg, other.infoBg),
      infoHover: c(infoHover, other.infoHover),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textDisabled: c(textDisabled, other.textDisabled),
      textOnColor: c(textOnColor, other.textOnColor),
      neutralHoverOverlay: c(neutralHoverOverlay, other.neutralHoverOverlay),
      neutralPressedOverlay: c(
        neutralPressedOverlay,
        other.neutralPressedOverlay,
      ),
      neutralSelectedBg: c(neutralSelectedBg, other.neutralSelectedBg),
      disabledBg: c(disabledBg, other.disabledBg),
    );
  }
}
