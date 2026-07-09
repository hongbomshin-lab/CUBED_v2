import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../account/account_screen.dart';
import '../home/home_screen.dart';
import '../hotdeals/hot_deals_screen.dart';
import '../map/map_screen.dart';

/// 앱 최상위 셸 — 하단 4탭(제품분석 / 저당맵 / 핫딜 / 마이).
/// IndexedStack으로 탭 전환 시 상태(지도 위치 등) 보존.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    MapScreen(),
    HotDealsScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: CubedColors.surface,
        indicatorColor: CubedColors.brand.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics_rounded, color: CubedColors.brand),
            label: '제품분석',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded, color: CubedColors.brand),
            label: '저당맵',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department_rounded,
                color: CubedColors.brand),
            label: '핫딜',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon:
                Icon(Icons.person_rounded, color: CubedColors.brand),
            label: '마이',
          ),
        ],
      ),
    );
  }
}
