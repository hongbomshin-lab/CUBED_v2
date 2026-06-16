import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// 핫딜 탭 — Step 6에서 구현 (hot_deals 테이블 + 바코드 조회).
class HotDealsScreen extends StatelessWidget {
  const HotDealsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('핫딜',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: CubedColors.brand,
                        letterSpacing: -0.5,
                      )),
              const SizedBox(height: 6),
              const Text('제로·저당 제품 최저가 모음',
                  style: TextStyle(color: CubedColors.inkSoft, fontSize: 15)),
              const Spacer(),
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department_rounded,
                        size: 56, color: CubedColors.inkSoft),
                    SizedBox(height: 16),
                    Text('핫딜 기능을 준비 중이에요',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    SizedBox(height: 8),
                    Text('바코드로 저당 제품 핫딜을 한눈에 확인할 수 있어요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: CubedColors.inkSoft, fontSize: 13)),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
