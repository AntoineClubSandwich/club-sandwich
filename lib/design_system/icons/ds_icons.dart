import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Single import point for icons used across the Club Sandwich design
/// system. `Ds*` components should import this file rather than
/// `package:lucide_icons_flutter/lucide_icons.dart` directly, so the
/// underlying icon package can be swapped later without touching every
/// component file.
abstract final class DsIcons {
  // Actions
  static const IconData check = LucideIcons.check;
  static const IconData close = LucideIcons.x;
  static const IconData plus = LucideIcons.plus;
  static const IconData minus = LucideIcons.minus;
  static const IconData search = LucideIcons.search;
  static const IconData filter = LucideIcons.filter;
  static const IconData download = LucideIcons.download;
  static const IconData upload = LucideIcons.upload;
  static const IconData eye = LucideIcons.eye;
  static const IconData eyeOff = LucideIcons.eyeOff;
  static const IconData logOut = LucideIcons.logOut;
  static const IconData settings = LucideIcons.settings;

  // Navigation
  static const IconData home = LucideIcons.home;
  static const IconData layoutDashboard = LucideIcons.layoutDashboard;
  static const IconData chevronDown = LucideIcons.chevronDown;
  static const IconData chevronLeft = LucideIcons.chevronLeft;
  static const IconData chevronRight = LucideIcons.chevronRight;
  static const IconData moreHorizontal = LucideIcons.moreHorizontal;
  static const IconData moreVertical = LucideIcons.moreVertical;

  // Feedback / status
  static const IconData circleCheck = LucideIcons.circleCheck;
  static const IconData circleAlert = LucideIcons.circleAlert;
  static const IconData circleX = LucideIcons.circleX;
  static const IconData triangleAlert = LucideIcons.triangleAlert;
  static const IconData info = LucideIcons.info;
  static const IconData loaderCircle = LucideIcons.loaderCircle;
  static const IconData bell = LucideIcons.bell;
  static const IconData dot = LucideIcons.dot;

  // People & organisations
  static const IconData user = LucideIcons.user;
  static const IconData users = LucideIcons.users;
  static const IconData users2 = LucideIcons.users2;
  static const IconData building = LucideIcons.building;
  static const IconData building2 = LucideIcons.building2;

  // Domain (maraudes)
  static const IconData calendar = LucideIcons.calendar;
  static const IconData clock = LucideIcons.clock;
  static const IconData mapPin = LucideIcons.mapPin;
  static const IconData mail = LucideIcons.mail;
  static const IconData scale = LucideIcons.scale;
  static const IconData route = LucideIcons.route;
  static const IconData truck = LucideIcons.truck;
  static const IconData utensils = LucideIcons.utensils;
  static const IconData heart = LucideIcons.heart;
  static const IconData fileDown = LucideIcons.fileDown;

  // Metrics & achievement
  static const IconData trendingUp = LucideIcons.trendingUp;
  static const IconData trendingDown = LucideIcons.trendingDown;
  static const IconData trophy = LucideIcons.trophy;
  static const IconData award = LucideIcons.award;
  static const IconData star = LucideIcons.star;
}
