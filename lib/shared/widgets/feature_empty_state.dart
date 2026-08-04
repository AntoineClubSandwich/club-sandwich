import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:flutter/material.dart';

class FeatureEmptyState extends StatelessWidget {
  const FeatureEmptyState({
    required this.title,
    required this.message,
    required this.icon,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppEmptyState(title: title, message: message, icon: icon),
    );
  }
}
