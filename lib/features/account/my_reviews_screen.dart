import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models/my_review.dart';
import '../../providers/providers.dart';

/// 마이페이지 → 내가 작성한 리뷰 목록.
class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myReviewsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('작성한 리뷰')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text('리뷰를 불러오지 못했어요',
              style: TextStyle(color: CubedColors.inkSoft)),
        ),
        data: (reviews) {
          if (reviews.isEmpty) {
            return const _Empty();
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(myReviewsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: reviews.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _ReviewCard(review: reviews[i]),
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
            Icon(Icons.rate_review_outlined,
                size: 48, color: CubedColors.inkSoft),
            SizedBox(height: 12),
            Text('아직 작성한 리뷰가 없어요',
                style: TextStyle(color: CubedColors.inkSoft, fontSize: 14)),
          ],
        ),
      );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final MyReview review;

  String _relativeDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()}년 전';
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}개월 전';
    if (diff.inDays >= 1) return '${diff.inDays}일 전';
    if (diff.inHours >= 1) return '${diff.inHours}시간 전';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}분 전';
    return '방금 전';
  }

  @override
  Widget build(BuildContext context) {
    final rec = review.isRecommended;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CubedColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CubedColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(review.storeName,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            Text(_relativeDate(review.createdAt),
                style:
                    const TextStyle(fontSize: 11, color: CubedColors.inkSoft)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(rec ? Icons.thumb_up_rounded : Icons.thumb_down_rounded,
                size: 14, color: rec ? CubedColors.brand : CubedColors.inkSoft),
            const SizedBox(width: 5),
            Text(rec ? '추천' : '비추천',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: rec ? CubedColors.brand : CubedColors.inkSoft)),
          ]),
          if (review.content != null) ...[
            const SizedBox(height: 8),
            Text(review.content!,
                style: const TextStyle(
                    fontSize: 13, height: 1.45, color: CubedColors.ink)),
          ],
        ],
      ),
    );
  }
}
