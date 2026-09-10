import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// 댓글 수정 바텀시트 — 수정된 내용을 반환(취소/무변경/빈값이면 null).
///
/// 컨트롤러 생명주기를 State가 관리해 시트가 닫힐 때 안전하게 dispose 한다
/// (다이얼로그 종료 직후 수동 dispose 시 나던 프레임워크 assertion 회피).
Future<String?> showCommentEditSheet(
  BuildContext context, {
  required String initial,
  String? productName,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: CubedColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CommentEditSheet(initial: initial, productName: productName),
  );
}

/// 댓글 삭제 확인 다이얼로그 — 삭제하려면 true.
Future<bool> confirmDeleteComment(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('댓글을 삭제할까요?'),
      content: const Text('이 댓글이 지워지며 되돌릴 수 없어요.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소')),
        TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: CubedColors.caution),
            child: const Text('삭제')),
      ],
    ),
  );
  return ok == true;
}

class _CommentEditSheet extends StatefulWidget {
  const _CommentEditSheet({required this.initial, this.productName});
  final String initial;
  final String? productName;

  @override
  State<_CommentEditSheet> createState() => _CommentEditSheetState();
}

class _CommentEditSheetState extends State<_CommentEditSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
  }

  void _onChanged() {
    final d = _ctrl.text.trim().isNotEmpty && _ctrl.text.trim() != widget.initial;
    if (d != _dirty) setState(() => _dirty = d);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    Navigator.of(context).pop(t);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: CubedColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('댓글 수정',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (widget.productName != null && widget.productName!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(widget.productName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: CubedColors.inkSoft)),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            maxLength: 500,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: '맛·후기·꿀조합을 남겨보세요',
              hintStyle:
                  const TextStyle(color: CubedColors.inkSoft, fontSize: 13),
              filled: true,
              fillColor: CubedColors.bg,
              contentPadding: const EdgeInsets.all(14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: CubedColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: CubedColors.brand, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: CubedColors.brand,
                disabledBackgroundColor: CubedColors.line,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: _dirty ? _save : null,
              child: const Text('저장',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
