import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import 'admin_providers.dart';

class ProductBrowserScreen extends ConsumerStatefulWidget {
  const ProductBrowserScreen({super.key});
  @override
  ConsumerState<ProductBrowserScreen> createState() => _ProductBrowserScreenState();
}

class _ProductBrowserScreenState extends ConsumerState<ProductBrowserScreen> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final results = ref.watch(productSearchProvider(_q));
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12),
        child: TextField(
          decoration: const InputDecoration(hintText: '제품명 검색', prefixIcon: Icon(Icons.search)),
          onSubmitted: (v) => setState(() => _q = v.trim()))),
      Expanded(child: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = list[i];
            final verified = (p['verified'] as bool?) ?? false;
            return ListTile(
              title: Text((p['name'] as String?) ?? ''),
              subtitle: Text('${p['brand'] ?? ''} · ${p['category'] ?? ''} · ${p['source_type'] ?? ''}'),
              trailing: Switch(
                value: verified,
                activeThumbColor: CubedColors.brand,
                onChanged: (v) async {
                  await ref.read(adminServiceProvider).setVerified(p['product_id'] as String, v);
                  ref.invalidate(productSearchProvider(_q));
                }),
            );
          },
        ),
      )),
    ]);
  }
}
