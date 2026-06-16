import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/providers.dart';

/// 메뉴판 제보 바텀시트.
/// 사진 URL(필수) + 메모(선택). 관리자 승인 시 store_photos(menu_board)로 등록.
class MenuBoardReportSheet extends ConsumerStatefulWidget {
  const MenuBoardReportSheet({
    super.key,
    required this.storeId,
    required this.storeName,
  });
  final String storeId;
  final String storeName;

  @override
  ConsumerState<MenuBoardReportSheet> createState() =>
      _MenuBoardReportSheetState();
}

class _MenuBoardReportSheetState extends ConsumerState<MenuBoardReportSheet> {
  final _imageUrl = TextEditingController();
  final _note = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _imageUrl.dispose();
    _note.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    final url = _imageUrl.text.trim();
    if (url.isEmpty) {
      _toast('메뉴판 사진 URL을 입력해 주세요');
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _toast('로그인이 필요해요');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(storeRepositoryProvider).submitMenuBoardReport(
            storeId: widget.storeId,
            reportedBy: user.id,
            imageUrl: url,
            note: _note.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      _toast('메뉴판 제보 감사해요! 검토 후 등록됩니다');
    } catch (e) {
      _toast('제보 전송에 실패했어요. 잠시 후 다시 시도해 주세요');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 8,
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
          const SizedBox(height: 12),
          Text('${widget.storeName} 메뉴판 제보',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('메뉴판 사진 URL을 등록하면 검토 후 매장 사진에 추가돼요.',
              style: TextStyle(fontSize: 13, color: CubedColors.inkSoft)),
          const SizedBox(height: 20),

          const _Label('메뉴판 사진 URL', required: true),
          const SizedBox(height: 6),
          _Input(
            controller: _imageUrl,
            hint: '예) https://... (이미지 주소)',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 14),
          const _Label('메모'),
          const SizedBox(height: 6),
          _Input(
            controller: _note,
            hint: '당류·가격 등 참고사항 (선택)',
            maxLines: 2,
          ),
          const SizedBox(height: 22),

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
                  : const Text('제보하기',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.required = false});
  final String text;
  final bool required;
  @override
  Widget build(BuildContext context) => Row(children: [
        Text(text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        if (required)
          const Text('  *', style: TextStyle(color: CubedColors.brand)),
      ]);
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: CubedColors.inkSoft, fontSize: 13),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        filled: true,
        fillColor: CubedColors.bg,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CubedColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CubedColors.brand, width: 1.5),
        ),
      ),
    );
  }
}
