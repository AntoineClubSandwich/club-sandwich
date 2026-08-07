import 'package:club_sandwich/design_system/tokens/ds_colors.dart';
import 'package:club_sandwich/design_system/tokens/ds_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le thème utilise les couleurs Club Sandwich', () {
    final theme = DsTheme.light;
    const colors = DsColorTokens.light;

    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, colors.primary);
    expect(theme.colorScheme.secondary, colors.secondary);
    expect(theme.cardTheme.elevation, 0);
    expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    expect(theme.dialogTheme.shape, isA<RoundedRectangleBorder>());
  });
}
