import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/providers.dart';
import 'menu_photo_field.dart';

/// 메뉴판 제보 바텀시트.
/// 사진 촬영/선택(압축·업로드) 또는 URL 입력 — 둘 중 하나만 있어도 제보 가능.
/// 관리자 승인 시 store_photos(menu_board)로 등록.
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

  /// 압축까지 끝낸 업로드 대상 사진(메모리). 선택 전엔 null.
  Uint8List? _photo;
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

  bool get _canSubmit =>
      _photo != null || _imageUrl.text.trim().isNotEmpty;

  Future<void> _submit() async {
    final photo = _photo;
    final typedUrl = _imageUrl.text.trim();
    if (photo == null && typedUrl.isEmpty) {
      _toast('메뉴판 사진을 등록하거나 URL을 입력해 주세요');
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _toast('로그인이 필요해요');
      return;
    }
    setState(() => _submitting = true);
    try {
      final repo = ref.read(storeRepositoryProvider);
      // 사진이 있으면 업로드해서 URL 확보, 없으면 입력한 URL 사용.
      String imageUrl;
      if (photo != null) {
        final millis = DateTime.now().millisecondsSinceEpoch;
        imageUrl = await repo.uploadMenuBoardPhoto(
          folder: widget.storeId,
          userId: user.id,
          bytes: photo,
          millis: millis,
        );
      } else {
        imageUrl = typedUrl;
      }
      await repo.submitMenuBoardReport(
        storeId: widget.storeId,
        reportedBy: user.id,
        imageUrl: imageUrl,
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
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            24,
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
          const Text('사진을 등록하거나 URL을 입력하면 검토 후 매장 사진에 추가돼요.',
              style: TextStyle(fontSize: 13, color: CubedColors.inkSoft)),
          const SizedBox(height: 20),

          const _Label('메뉴판 사진'),
          const SizedBox(height: 6),
          MenuPhotoField(
            photo: _photo,
            onChanged: (bytes) => setState(() => _photo = bytes),
          ),
          const SizedBox(height: 14),

          const _Label('메뉴판 사진 URL (선택)'),
          const SizedBox(height: 6),
          _Input(
            controller: _imageUrl,
            hint: '예) https://... (이미지 주소)',
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() {}),
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
              onPressed: (_submitting || !_canSubmit) ? null : _submit,
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
    this.onChanged,
  });
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
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
