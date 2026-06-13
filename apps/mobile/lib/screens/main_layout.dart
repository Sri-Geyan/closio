import 'package:flutter/material.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'hub_screen.dart';
import 'context_nodes_screen.dart';
import 'profile_screen.dart';
import 'components/glass_container.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 1;
  final PageController _pageController = PageController(initialPage: 1);

  final List<Widget> _screens = [
    const HomeScreen(),
    const HubScreen(),
    const ContextNodesScreen(),
    const ProfileScreen(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onNavItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Allow content to flow under the floating bar
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            physics: const ClampingScrollPhysics(),
            children: _screens,
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32, // Floating slightly above the bottom
            child: _buildFloatingGlassNav(),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingGlassNav() {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(Icons.calendar_today_outlined, Icons.calendar_today, 'Calendar', 0),
          _buildNavItem(Icons.dashboard_outlined, Icons.dashboard, 'Hubs', 1),
          _buildNavItem(Icons.map_outlined, Icons.map, 'Map', 2),
          _buildNavItem(Icons.person_outline, Icons.person, 'Profile', 3),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData unselectedIcon, IconData selectedIcon, String label, int index) {
    final isSelected = _currentIndex == index;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final outlineColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.5);

    return GestureDetector(
      onTap: () => _onNavItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 16.0 : 8.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              color: isSelected ? primaryColor : outlineColor,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
