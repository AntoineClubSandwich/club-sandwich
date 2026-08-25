import 'package:flutter/widgets.dart';

/// Corner radius scale for the Club Sandwich design system — "Bento Soft
/// Modern"'s generous, finer-grained rounding (vs. the old 4-step scale).
/// NOTE: this is a rename, not an addition — `sm`/`md`/`lg` map to
/// different pixel values than before. Every call site was re-pointed in
/// the same change that introduced this scale; do not reuse an old
/// mental mapping (old `sm`=12 is now `lg`).
abstract final class DsRadius {
  static const double xs = 6; // small badges/icon chips
  static const double sm = 8; // inputs, small controls
  static const double md = 10; // buttons, nav items
  static const double lg = 12; // cards
  static const double xl = 16; // large surfaces
  static const double xxl = 20; // dialogs/sheets
  static const double pill = 999;

  static const BorderRadius xsRadius = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smRadius = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlRadius = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlRadius = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(pill),
  );
}
