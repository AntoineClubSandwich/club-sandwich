import 'package:flutter/widgets.dart';

/// Corner radius scale for the Club Sandwich design system.
abstract final class DsRadius {
  static const double sm = 12;
  static const double lg = 20;
  static const double pill = 999;

  static const BorderRadius smRadius = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius lgRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(pill),
  );
}
