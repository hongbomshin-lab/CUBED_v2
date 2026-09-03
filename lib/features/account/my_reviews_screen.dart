import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models/my_review.dart';
import '../../providers/providers.dart';
import '../review/review_sheet.dart';

/// 마이페이지 → 내가 작성한 리뷰 목록.
/// 카드를 탭하면 수정, 왼쪽으로 밀면 삭제. (수정/삭제 모두 본인 것만 — RLS)
class MyReviewsScreen extends ConsumerStatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  ConsumerState<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends ConsumerState<MyReviewsScreen> {
  /// 낙관적 삭제 — provider 재조회 전 즉시 숨겨 Dismissible 재출현(assert)을 방지.
  final Set<String> _removedIds = {};

  Future<void> _edit(MyReview review) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CubedColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          ReviewSheet(storeId: review.storeId, storeName: review.storeName),
    );
    if (changed == true) {
      ref.invalidate(myReviewsProvider);
      ref.invalidate(storeReviewsProvider(review.storeId));
    }
  }

  Future<bool> _confirmDelete(MyReview review) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('리뷰를 삭제할까요?'),
        content: Text('${review.storeName}에 남긴 리뷰가 지워져요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: CubedColors.caution),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _delete(MyReview review) async {
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _removedIds.add(review.id)); // 낙관적 숨김
    try {
      await ref.read(storeRepositoryProvider).deleteReview(review.id);
      container.invalidate(myReviewsProvider);
      container.invalidate(storeReviewsProvider(review.storeId));
    } catch (e) {
      if (!mounted) return;
      setState(() => _removedIds.remove(review.id)); // 롤백
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('삭제에 실패했어요')));
    }
  }

  @override
  Widget build(BuildContext context) {
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
          final visible =
              reviews.where((r) => !_removedIds.contains(r.id)).toList();
          if (visible.isEmpty) {
            return const _Empty();
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(myReviewsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: visible.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 2, left: 2),
                    child: Text('탭하여 수정 · 왼쪽으로 밀어 삭제',
                        style: TextStyle(
                            fontSize: 12, color: CubedColors.inkSoft)),
                  );
                }
                final review = visible[i - 1];
                return Dismissible(
                  key: ValueKey(review.id),
                  direction: DismissDirection.endToStart,
                  background: _DeleteBg(),
                  confirmDismiss: (_) => _confirmDelete(review),
                  onDismissed: (_) => _delete(review),
                  child: _ReviewCard(
                    review: review,
                    onTap: () => _edit(review),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _DeleteBg extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: CubedColors.caution,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.delete_rounded, color: Colors.white, size: 20),
          SizedBox(width: 6),
          Text('삭제',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
        ]),
      );
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
  const _ReviewCard({required this.review, required this.onTap});
  final MyReview review;
  final VoidCallback onTap;

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
    return Material(
      color: CubedColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
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
                    style: const TextStyle(
                        fontSize: 11, color: CubedColors.inkSoft)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: CubedColors.inkSoft),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Icon(rec ? Icons.thumb_up_rounded : Icons.thumb_down_rounded,
                    size: 14,
                    color: rec ? CubedColors.brand : CubedColors.inkSoft),
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
        ),
      ),
    );
  }
}
