import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/providers.dart';

/// 리뷰 작성·수정 바텀시트.
/// 👍/👎(필수) + 내용(선택, 최대 500자). 매장당 1인 1리뷰(upsert).
class ReviewSheet extends ConsumerStatefulWidget {
  const ReviewSheet({super.key, required this.storeId, required this.storeName});
  final String storeId;
  final String storeName;

  @override
  ConsumerState<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<ReviewSheet> {
  final _content = TextEditingController();
  bool? _recommend; // null=미선택, true=추천, false=비추천
  bool _loading = true;
  bool _submitting = false;
  bool _editing = false; // 기존 리뷰 수정 여부

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final mine =
          await ref.read(storeRepositoryProvider).myReview(widget.storeId, user.id);
      if (!mounted) return;
      if (mine != null) {
        _recommend = mine.isRecommended;
        _content.text = mine.content ?? '';
        _editing = true;
      }
    } catch (_) {
      // 무시 — 새 작성으로 진행
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    if (_recommend == null) {
      _toast('추천 또는 비추천을 선택해 주세요');
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _toast('로그인이 필요해요');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(storeRepositoryProvider).submitReview(
            storeId: widget.storeId,
            userId: user.id,
            isRecommended: _recommend!,
            content: _content.text,
          );
      // 리뷰 목록 갱신
      ref.invalidate(storeReviewsProvider(widget.storeId));
      if (!mounted) return;
      Navigator.of(context).pop(true);
      _toast(_editing ? '리뷰를 수정했어요' : '리뷰를 등록했어요');
    } catch (e) {
      _toast('리뷰 저장에 실패했어요. 잠시 후 다시 시도해 주세요');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 8,
      ),
      child: _loading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: _Handle()),
                const SizedBox(height: 8),
                Text(widget.storeName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(_editing ? '내 리뷰 수정' : '이 매장 어떠셨나요?',
                    style: const TextStyle(
                        fontSize: 13, color: CubedColors.inkSoft)),
                const SizedBox(height: 18),

                // 추천 / 비추천
                Row(children: [
                  Expanded(
                    child: _ChoiceButton(
                      icon: Icons.thumb_up_rounded,
                      label: '추천',
                      selected: _recommend == true,
                      color: CubedColors.brand,
                      onTap: () => setState(() => _recommend = true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ChoiceButton(
                      icon: Icons.thumb_down_rounded,
                      label: '비추천',
                      selected: _recommend == false,
                      color: CubedColors.inkSoft,
                      onTap: () => setState(() => _recommend = false),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),

                // 내용 (선택)
                TextField(
                  controller: _content,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: '메뉴·당류·맛 등 자유롭게 남겨주세요 (선택)',
                    hintStyle: const TextStyle(
                        color: CubedColors.inkSoft, fontSize: 13),
                    filled: true,
                    fillColor: CubedColors.bg,
                    contentPadding: const EdgeInsets.all(12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: CubedColors.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: CubedColors.brand, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: CubedColors.brand,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_editing ? '리뷰 수정' : '리뷰 등록',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : CubedColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : CubedColors.line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? color : CubedColors.inkSoft, size: 26),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: selected ? color : CubedColors.inkSoft)),
        ]),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();
  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: CubedColors.line,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}
