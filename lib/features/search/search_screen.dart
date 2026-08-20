import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/product_thumb.dart';
import '../../core/theme.dart';
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
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: CubedColors.line),
                  itemBuilder: (_, i) {
                    final p = list[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      leading: ProductThumb(imageFile: p.imageFile, size: 44, radius: 12),
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${p.brand ?? ''} · ${p.category ?? ''}'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ResultScreen(product: p)),
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
