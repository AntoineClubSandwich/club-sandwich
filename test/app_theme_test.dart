import 'package:club_sandwich/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le thème utilise les couleurs Club Sandwich', () {
    final theme = AppTheme.light;

    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.colorScheme.secondary, AppColors.secondary);
    expect(theme.colorScheme.tertiary, AppColors.accent);
    expect(theme.cardTheme.elevation, 0);
    expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    expect(theme.dialogTheme.shape, isA<RoundedRectangleBorder>());
  });
}
