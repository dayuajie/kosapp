import 'package:flutter/material.dart';

class BottomNavItem {
  final String id;
  final IconData icon;
  final String label;
  final Widget page;

  const BottomNavItem({
    required this.id,
    required this.icon,
    required this.label,
    required this.page,
  });
}

