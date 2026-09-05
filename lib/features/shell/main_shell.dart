import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../account/account_screen.dart';
import '../home/home_screen.dart';
import '../map/map_screen.dart';

/// 앱 최상위 셸 — 하단 3탭(제품분석 / 저당맵 / 마이).
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
    // 네이버 지도 SDK는 웹 미지원 — 웹 프리뷰에서는 안내 화면으로 대체
    if (kIsWeb) _MapUnavailable() else MapScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: _Dock(
        index: _index,
        onSelect: (i) {
          if (i != _index) HapticFeedback.selectionClick();
          setState(() => _index = i);
        },
      ),
    );
  }
}

class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('저당맵은 모바일 앱에서 이용할 수 있어요',
            style: TextStyle(color: CubedColors.inkSoft)),
      ),
    );
  }
}

/// 커스텀 하단 독 — 선택 탭은 잉크 필 + 라임 아이콘.
class _Dock extends StatelessWidget {
  const _Dock({required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: CubedColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Color(0x1410231B),
              blurRadius: 24,
              offset: Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: [
              _DockItem(
                icon: Icons.troubleshoot_rounded,
                label: '제품분석',
                selected: index == 0,
                onTap: () => onSelect(0),
              ),
              _DockItem(
                icon: Icons.map_rounded,
                label: '저당맵',
                selected: index == 1,
                onTap: () => onSelect(1),
              ),
              _DockItem(
                icon: Icons.person_rounded,
                label: '마이',
                selected: index == 2,
                onTap: () => onSelect(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Semantics(
          selected: selected,
          button: true,
          label: label,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? CubedColors.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(icon,
                    size: 22,
                    color:
                        selected ? CubedColors.lime : CubedColors.inkSoft),
              ),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? CubedColors.ink : CubedColors.inkSoft,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
