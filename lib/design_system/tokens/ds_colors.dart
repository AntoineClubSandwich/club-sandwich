import 'package:flutter/painting.dart';

/// Color tokens for the Club Sandwich design system — "Bento Soft Modern":
/// a warm off-white canvas, white cards, a single saturated purple brand
/// accent, and soft low-opacity tints for everything else. Values come
/// from the project's `design-system/CLAUDE.md` brief (the authoritative
/// source where it's explicit); a handful of tints/hovers not spelled out
/// there are still derived from the initial Figma extraction.
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
    required this.secondaryMuted,
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

  /// A medium-emphasis neutral, not a second brand hue — the Figma
  /// reference has exactly one saturated accent (`primary`). Used for
  /// outline-style secondary actions.
  final Color secondary;
  final Color secondaryHover;
  final Color secondaryPressed;
  final Color secondarySelectedBg;
  final Color secondaryDisabled;

  /// A deep, softened indigo — [secondary]'s near-black ink lightened
  /// with a hint of [primary]'s purple. For dark surfaces that want depth
  /// and brand warmth (e.g. the admin sidebar) without reading as a stark
  /// neo-brutalist black block.
  final Color secondaryMuted;

  final Color canvas;
  final Color surface;
  final Color surfaceElevated;

  final Color border;
  final Color borderSubtle;
  final Color borderFocus;

  /// Same ink as [textPrimary] — kept as a distinct field for call sites
  /// that reason about "the ink color" semantically (dark surfaces, text)
  /// rather than "border color". No longer used for card/button borders,
  /// which are 1px [border] in this style, not a thick ink outline.
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
    primary: Color(0xFF6C5CE7),
    primaryHover: Color(0xFF5D4DD8),
    primaryPressed: Color(0xFF4E3EC9),
    primarySelectedBg: Color(0x0F6C5CE7), // primary @ ~6%
    primaryDisabled: Color(0x616C5CE7), // primary @ 38%
    secondary: Color(0xFF1A1A2E),
    secondaryHover: Color(0xFF141422),
    secondaryPressed: Color(0xFF0E0E18),
    secondarySelectedBg: Color(0xFFF1F0EE),
    secondaryDisabled: Color(0x611A1A2E), // secondary @ 38%
    secondaryMuted: Color(0xFF2D2B55),
    canvas: Color(0xFFF8F7F4),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    border: Color(0xFFE5E7EB),
    borderSubtle: Color(0xFFF1EFEB),
    borderFocus: Color(0xFF6C5CE7),
    borderStrong: Color(0xFF1A1A2E),
    // Functional colors: `success`/`warning`/`error`/`info` hold the
    // *text/icon* tone (readable on the pale `*Bg`), not the mid-tone
    // swatch from the design brief — that mid-tone lives in `*Hover`
    // instead, since it reads well as a hover/pressed accent between the
    // two.
    success: Color(0xFF059669),
    successBg: Color(0xFFECFDF5),
    successHover: Color(0xFF34D399),
    warning: Color(0xFFD97706),
    warningBg: Color(0xFFFFFBEB),
    warningHover: Color(0xFFFBBF24),
    error: Color(0xFFDC2626),
    errorBg: Color(0xFFFEF2F2),
    errorHover: Color(0xFFEF4444),
    info: Color(0xFF2563EB),
    infoBg: Color(0xFFEFF6FF),
    infoHover: Color(0xFF60A5FA),
    textPrimary: Color(0xFF1A1A2E),
    textSecondary: Color(0xFF6B7280),
    textDisabled: Color(0xFF9CA3AF),
    textOnColor: Color(0xFFFFFFFF),
    neutralHoverOverlay: Color(0x081A1A2E), // ink @ ~3%
    neutralPressedOverlay: Color(0x0F1A1A2E), // ink @ ~6%
    neutralSelectedBg: Color(0xFFFAFAF9),
    disabledBg: Color(0xFFF4F3EE),
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
      secondaryMuted: c(secondaryMuted, other.secondaryMuted),
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
