import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../data/models/comment.dart';
import '../../../providers/providers.dart';
import '../../auth/login_screen.dart';

/// 좋아요 + 코멘트 섹션 — 카카오 로그인한 사용자만 작성 가능(조회는 누구나).
class SocialSection extends ConsumerWidget {
  const SocialSection({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 로그인 상태가 바뀌면 좋아요·코멘트 갱신
    ref.listen(authStateProvider, (_, __) {
      ref.invalidate(likeInfoProvider(productId));
      ref.invalidate(commentsProvider(productId));
    });

    final user = ref.watch(currentUserProvider);
    final loggedIn = user != null;
    final like = ref.watch(likeInfoProvider(productId));
    final comments = ref.watch(commentsProvider(productId));

    Future<void> requireLogin() async {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('이 제품 어때요?',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const Spacer(),
            like.when(
              loading: () => const _LikeButton(count: 0, liked: false, busy: true),
              error: (_, __) => const SizedBox.shrink(),
              data: (info) => _LikeButton(
                count: info.count,
                liked: info.liked,
                onTap: () async {
                  if (!loggedIn) return requireLogin();
                  try {
                    await ref.read(socialRepositoryProvider).toggleLike(productId);
                    ref.invalidate(likeInfoProvider(productId));
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 입력 영역 — 로그인 여부로 분기
        if (loggedIn)
          _CommentInput(
            onSubmit: (body) async {
              try {
                final nick = ref.read(authRepositoryProvider).displayName();
                await ref.read(socialRepositoryProvider)
                    .addComment(productId, body, nickname: nick);
                ref.invalidate(commentsProvider(productId));
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
          )
        else
          _LoginPromptButton(onTap: requireLogin),

        const SizedBox(height: 12),
        comments.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('코멘트를 불러오지 못했어요: $e',
              style: const TextStyle(color: CubedColors.inkSoft, fontSize: 12)),
          data: (list) {
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('첫 코멘트를 남겨보세요!',
                    style: TextStyle(color: CubedColors.inkSoft, fontSize: 13)),
              );
            }
            return Column(
              children: list.map((c) {
                final mine = ref.read(socialRepositoryProvider).isMine(c);
                return _CommentTile(
                  comment: c,
                  mine: mine,
                  onDelete: mine
                      ? () async {
                          await ref.read(socialRepositoryProvider).deleteComment(c.id);
                          ref.invalidate(commentsProvider(productId));
                        }
                      : null,
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _LoginPromptButton extends StatelessWidget {
  const _LoginPromptButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: CubedColors.brand,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
        ),
        onPressed: onTap,
        icon: const Icon(Icons.login_rounded, size: 18),
        label: const Text('로그인하고 참여하기',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({required this.count, required this.liked, this.onTap, this.busy = false});
  final int count;
  final bool liked;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = liked ? CubedColors.caution : CubedColors.inkSoft;
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: liked ? CubedColors.caution.withValues(alpha: 0.08) : CubedColors.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: liked ? CubedColors.caution.withValues(alpha: 0.3) : CubedColors.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 18, color: c),
          const SizedBox(width: 6),
          Text('$count', style: TextStyle(color: c, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

class _CommentInput extends StatefulWidget {
  const _CommentInput({required this.onSubmit});
  final Future<void> Function(String body) onSubmit;
  @override
  State<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<_CommentInput> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty || _busy) return;
    setState(() => _busy = true);
    await widget.onSubmit(t);
    _ctrl.clear();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            maxLength: 500,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: '맛·후기·꿀조합을 남겨보세요',
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: CubedColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: CubedColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: CubedColors.line),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _busy ? null : _submit,
          style: IconButton.styleFrom(backgroundColor: CubedColors.brand),
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, size: 20),
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.mine, this.onDelete});
  final Comment comment;
  final bool mine;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CubedColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CubedColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: CubedColors.brand.withValues(alpha: 0.15),
            child: Text(
              (comment.nickname?.isNotEmpty == true ? comment.nickname![0] : '익'),
              style: const TextStyle(fontSize: 12, color: CubedColors.brand, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(comment.nickname?.isNotEmpty == true ? comment.nickname! : (mine ? '나' : '카카오회원'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(_ago(comment.createdAt),
                      style: const TextStyle(color: CubedColors.inkSoft, fontSize: 11)),
                ]),
                const SizedBox(height: 4),
                Text(comment.body, style: const TextStyle(fontSize: 14, height: 1.4)),
              ],
            ),
          ),
          if (onDelete != null)
            GestureDetector(
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.close_rounded, size: 16, color: CubedColors.inkSoft),
              ),
            ),
        ],
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '방금';
    if (d.inHours < 1) return '${d.inMinutes}분 전';
    if (d.inDays < 1) return '${d.inHours}시간 전';
    if (d.inDays < 7) return '${d.inDays}일 전';
    return '${t.year}.${t.month}.${t.day}';
  }
}
