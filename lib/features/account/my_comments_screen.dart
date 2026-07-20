import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models/my_comment.dart';
import '../../providers/providers.dart';

/// 마이페이지 → 내가 작성한 (제품) 댓글 목록.
class MyCommentsScreen extends ConsumerWidget {
  const MyCommentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myCommentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('작성한 댓글')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text('댓글을 불러오지 못했어요',
              style: TextStyle(color: CubedColors.inkSoft)),
        ),
        data: (comments) {
          if (comments.isEmpty) return const _Empty();
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(myCommentsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: comments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _CommentCard(comment: comments[i]),
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
            Icon(Icons.chat_bubble_outline_rounded,
                size: 48, color: CubedColors.inkSoft),
            SizedBox(height: 12),
            Text('아직 작성한 댓글이 없어요',
                style: TextStyle(color: CubedColors.inkSoft, fontSize: 14)),
          ],
        ),
      );
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment});
  final MyComment comment;

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
    final title = comment.brand != null && comment.brand!.isNotEmpty
        ? '${comment.brand}  ${comment.productName}'
        : comment.productName;
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
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: CubedColors.brand)),
            ),
            Text(_relativeDate(comment.createdAt),
                style:
                    const TextStyle(fontSize: 11, color: CubedColors.inkSoft)),
          ]),
          const SizedBox(height: 8),
          Text(comment.body,
              style: const TextStyle(
                  fontSize: 13, height: 1.45, color: CubedColors.ink)),
        ],
      ),
    );
  }
}
