import 'package:flutter/material.dart';
import 'bottom_nav_item.dart';

class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavItem> items;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      elevation: 8,
      selectedItemColor: const Color(0xFF6D5EF6),
      unselectedItemColor: Colors.black.withOpacity(0.45),
      showSelectedLabels: false,
      showUnselectedLabels: false,
      items: items
          .map(
            (e) => BottomNavigationBarItem(
              icon: Icon(e.icon),
              activeIcon: Icon(e.icon),
              label: e.label,
            ),
          )
          .toList(),
    );
  }
}

