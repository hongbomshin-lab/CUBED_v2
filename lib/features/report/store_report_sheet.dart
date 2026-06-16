import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/providers.dart';

/// 매장 제보 바텀시트.
/// 이름(필수) + 네이버/카카오 URL(선택) + 사진 URL(선택, 여러 개) 만 받고,
/// 주소·좌표·타입은 관리자가 승인 시 대시보드에서 보완한다.
class StoreReportSheet extends ConsumerStatefulWidget {
  const StoreReportSheet({super.key});

  @override
  ConsumerState<StoreReportSheet> createState() => _StoreReportSheetState();
}

class _StoreReportSheetState extends ConsumerState<StoreReportSheet> {
  final _name = TextEditingController();
  final _placeUrl = TextEditingController();
  final _photoUrls = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _placeUrl.dispose();
    _photoUrls.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast('가게 이름을 입력해 주세요');
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _toast('로그인이 필요해요');
      return;
    }

    // 사진 URL: 줄바꿈/쉼표로 구분된 여러 개 허용
    final photos = _photoUrls.text
        .split(RegExp(r'[\n,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    setState(() => _submitting = true);
    try {
      await ref.read(storeRepositoryProvider).submitStoreReport(
            reportedBy: user.id,
            name: name,
            placeUrl: _placeUrl.text.trim(),
            imageUrls: photos,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      _toast('제보해 주셔서 감사해요! 검토 후 등록됩니다');
    } catch (e) {
      _toast('제보 전송에 실패했어요. 잠시 후 다시 시도해 주세요');
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: _Handle()),
          const SizedBox(height: 8),
          const Text('저당 매장 제보',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('가게 이름만 있어도 제보할 수 있어요. 검토 후 지도에 등록됩니다.',
              style: TextStyle(fontSize: 13, color: CubedColors.inkSoft)),
          const SizedBox(height: 20),

          _Field(
            label: '가게 이름',
            required: true,
            controller: _name,
            hint: '예) 제로카페 홍대점',
          ),
          const SizedBox(height: 14),
          _Field(
            label: '네이버/카카오 플레이스 URL',
            controller: _placeUrl,
            hint: '예) https://naver.me/...  (선택)',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 14),
          _Field(
            label: '메뉴판·가게 외관 사진 URL',
            controller: _photoUrls,
            hint: '여러 개면 줄바꿈으로 구분 (선택)',
            maxLines: 3,
            keyboardType: TextInputType.url,
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
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
          if (required)
            const Text('  *', style: TextStyle(color: CubedColors.brand)),
        ]),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: CubedColors.inkSoft, fontSize: 13),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        ),
      ],
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
