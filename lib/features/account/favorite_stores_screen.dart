import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models/store.dart';
import '../../providers/providers.dart';
import '../map/widgets/store_detail_sheet.dart';

/// 마이페이지 → 즐겨찾기한 매장 목록. 탭하면 매장 상세 바텀시트.
class FavoriteStoresScreen extends ConsumerWidget {
  const FavoriteStoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(favoriteStoresProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('즐겨찾기 매장')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text('목록을 불러오지 못했어요',
              style: TextStyle(color: CubedColors.inkSoft)),
        ),
        data: (stores) {
          if (stores.isEmpty) return const _Empty();
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(favoriteStoresProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: stores.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _StoreCard(
                store: stores[i],
                onTap: () => showStoreDetailSheet(context, stores[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border_rounded,
                size: 48, color: CubedColors.inkSoft),
            SizedBox(height: 12),
            Text('아직 즐겨찾기한 매장이 없어요',
                style: TextStyle(color: CubedColors.inkSoft, fontSize: 14)),
            SizedBox(height: 4),
            Text('저당맵에서 하트를 눌러 담아보세요',
                style: TextStyle(color: CubedColors.inkSoft, fontSize: 12)),
          ],
        ),
      );
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store, required this.onTap});
  final Store store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photo = store.primaryPhoto;
    return Material(
      color: CubedColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: photo != null
                    ? CachedNetworkImage(
                        imageUrl: photo.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: CubedColors.line),
                        errorWidget: (_, __, ___) =>
                            Container(color: CubedColors.line),
                      )
                    : Container(
                        color: CubedColors.bg,
                        child: const Icon(Icons.store_rounded,
                            color: CubedColors.inkSoft),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(store.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(store.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: CubedColors.inkSoft)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: CubedColors.inkSoft),
          ]),
        ),
      ),
    );
  }
}
