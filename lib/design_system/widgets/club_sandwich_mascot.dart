import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The official Club Sandwich mascot, vectorized from
/// `assets_source/club_sandwich_reference.png` — see
/// `assets/branding/README.md` for provenance and usage rules.
///
/// A brand/illustration element, not a functional UI icon; for icons use
/// `lib/design_system/icons/ds_icons.dart` instead.
class ClubSandwichMascot extends StatelessWidget {
  const ClubSandwichMascot({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/branding/club_sandwich_mascot_blue.svg',
      width: size,
      height: size,
      semanticsLabel: 'Mascotte Club Sandwich',
    );
  }
}
