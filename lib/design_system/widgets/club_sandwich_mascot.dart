import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Which color variant of the mascot to render — see
/// `assets/branding/README.md` for the exact hex values and usage rules.
/// These are the only two official variants; do not add a third without
/// going through the same trace-from-reference process documented there.
enum MascotColor { blue, orange }

/// The official Club Sandwich mascot, vectorized from
/// `assets_source/club_sandwich_reference.png` — see
/// `assets/branding/README.md` for provenance and usage rules.
///
/// A brand/illustration element, not a functional UI icon; for icons use
/// `lib/design_system/icons/ds_icons.dart` instead.
class ClubSandwichMascot extends StatelessWidget {
  const ClubSandwichMascot({
    super.key,
    this.size = 96,
    this.color = MascotColor.blue,
  });

  final double size;
  final MascotColor color;

  @override
  Widget build(BuildContext context) {
    final asset = switch (color) {
      MascotColor.blue => 'assets/branding/club_sandwich_mascot_blue.svg',
      MascotColor.orange => 'assets/branding/club_sandwich_mascot_orange.svg',
    };
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      semanticsLabel: 'Mascotte Club Sandwich',
    );
  }
}
