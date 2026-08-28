import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/product_thumb.dart';
import '../../core/theme.dart';
import '../../domain/interpretation.dart';
import '../../providers/providers.dart';
import '../result/result_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchProvider(_q));
    return Scaffold(
      appBar: AppBar(title: const Text('제품 검색')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                hintText: '제품명 또는 브랜드 (예: 제로콜라, 라라스윗)',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
              data: (list) {
                if (_q.trim().isEmpty) {
                  return const Center(
                    child: Text('제품명을 입력해보세요', style: TextStyle(color: CubedColors.inkSoft)),
                  );
                }
                if (list.isEmpty) {
                  return const Center(
                    child: Text('검색 결과가 없어요', style: TextStyle(color: CubedColors.inkSoft)),
                  );
                }
                // 시안4 — 행마다 큐브 마커. 색은 rulebook 이 계산한 등급을 그대로 쓴다.
                // 기준 데이터는 앱 시작 시 캐시되므로 목록에서 동기로 해석할 수 있다.
                const tilts = [-0.12, 0.08, -0.05, 0.14, -0.09, 0.04, 0.11, -0.07];
                final refData = ref.watch(referenceProvider).valueOrNull;
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final p = list[i];
                    final grade = refData == null
                        ? null
                        : Interpretation.of(p, refData).grade;
                    final markColor = grade == null
                        ? CubedColors.line
                        : CubedColors.grade(grade);
                    return InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ResultScreen(product: p)),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: const BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: CubedColors.line)),
                        ),
                        child: Row(
                          children: [
                            Transform.rotate(
                              angle: tilts[i % tilts.length],
                              child: Container(
                                width: 13,
                                height: 13,
                                decoration: BoxDecoration(
                                  color: markColor,
                                  borderRadius: BorderRadius.circular(3.6),
                                ),
                              ),
                            ),
                            const SizedBox(width: 13),
                            ProductThumb(imageFile: p.imageFile, size: 44, radius: 12),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          height: 1.3,
                                          letterSpacing: -0.4)),
                                  const SizedBox(height: 2),
                                  Text(p.brand ?? '',
                                      style: const TextStyle(
                                          color: CubedColors.inkSoft,
                                          fontSize: 12.5)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
