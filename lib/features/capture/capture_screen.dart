import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../ocr/ocr_service.dart';
import '../result/result_screen.dart';
import 'capture_controller.dart';

/// 사진 분석: 진입 즉시 전면 1장 촬영 → 빠른 매칭, 미등록 확정 시에만 3장 플로우.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key, this.prefillBarcode});
  final String? prefillBarcode;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  @override
  void initState() {
    super.initState();
    // 진입 즉시 카메라부터 — 1단계에서는 슬롯 화면을 보여주지 않는다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(captureControllerProvider);
      if (state.images.isEmpty && !state.quickChecked) {
        _pick(context, ref, CaptureSlot.full, ImageSource.camera);
      }
    });
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    CaptureSlot slot,
    ImageSource source,
  ) async {
    // maxHeight 필수: CLOVA 비전은 긴 변 2240px 초과 이미지를 40063으로 거부한다.
    // maxWidth만 걸면 세로로 긴 사진(갤러리 스크린샷 등)의 높이가 한도를 넘는다.
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 80,
    );
    if (file == null) {
      // 1단계(전면샷 전) 카메라 취소 = 촬영 자체를 그만둔 것 → 화면 닫기
      final st = ref.read(captureControllerProvider);
      if (slot == CaptureSlot.full &&
          !st.quickChecked &&
          st.images.isEmpty &&
          context.mounted &&
          Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }
    final bytes = await file.readAsBytes();
    ref.read(captureControllerProvider.notifier).setImage(slot, bytes);
    // 전면샷 단계면 등록 제품 빠른 매칭부터 — 매칭되면 나머지 2장 생략
    if (slot == CaptureSlot.full &&
        !ref.read(captureControllerProvider).quickChecked &&
        context.mounted) {
      _tryQuickMatch(context, ref, bytes);
    }
  }

  /// 전면 1장 빠른 매칭 (비치명). 매칭되면 즉시 결과 화면,
  /// 실패하면 quickChecked로 전환해 나머지 2장 슬롯을 연다.
  Future<void> _tryQuickMatch(
      BuildContext context, WidgetRef ref, Uint8List bytes) async {
    final ctrl = ref.read(captureControllerProvider.notifier);
    if (ref.read(captureControllerProvider).quickMatching) return;
    ctrl.setQuickMatching(true);
    try {
      final result = await OcrService(ref.read(supabaseProvider))
          .quickMatch(fullB64: base64Encode(bytes));
      if (result != null && context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (_) => ResultScreen(
                  product: result.product,
                  priceCatalogKey: result.priceCatalogKey,
                  priceCatalogName: result.priceCatalogName)),
        );
        return;
      }
    } catch (e) {
      debugPrint('quickMatch 예외(비치명): $e'); // 3장 플로우로 전환
    }
    if (context.mounted) ctrl.markQuickChecked();
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final ctrl = ref.read(captureControllerProvider.notifier);
    final imgs = ref.read(captureControllerProvider).images;
    ctrl.setSubmitting(true);
    try {
      final service = OcrService(ref.read(supabaseProvider));
      final result = await service.parseAndSubmit(
        fullB64: base64Encode(imgs[CaptureSlot.full]!),
        ingredientsB64: base64Encode(imgs[CaptureSlot.ingredients]!),
        nutritionB64: base64Encode(imgs[CaptureSlot.nutrition]!),
        barcode: widget.prefillBarcode,
      );
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => ResultScreen(
                product: result.product,
                submissionImagePath: result.imagePath,
                priceCatalogKey: result.priceCatalogKey,
                priceCatalogName: result.priceCatalogName)),
      );
    } catch (e) {
      ctrl.setError('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(captureControllerProvider);
    // 1단계(카메라·빠른 매칭): 슬롯 화면 없이 진행 상태만.
    // 2단계(quickChecked): 미등록 확정 → 3장 플로우.
    if (!state.quickChecked && !state.submitting) {
      return Scaffold(
        appBar: AppBar(title: const Text('사진으로 분석')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: CubedColors.brand),
              const SizedBox(height: 16),
              Text(
                  state.quickMatching
                      ? '등록된 제품인지 확인 중…\n맞으면 바로 결과로 이동해요'
                      : '카메라를 여는 중…',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: CubedColors.inkSoft, height: 1.5)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('사진으로 분석')),
      body: state.submitting
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: CubedColors.brand),
                  SizedBox(height: 16),
                  Text('AI가 3장을 읽고 분석하고 있어요…',
                      style: TextStyle(color: CubedColors.inkSoft)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('등록되지 않은 제품이에요',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('원재료명·영양성분표까지 3장이 모이면 AI가 분석해요.',
                    style: TextStyle(color: CubedColors.inkSoft, height: 1.5)),
                const SizedBox(height: 16),
                for (final slot in CaptureSlot.values)
                  _SlotCard(
                    slot: slot,
                    index: slot.index + 1,
                    bytes: state.images[slot],
                    onCamera: () => _pick(context, ref, slot, ImageSource.camera),
                    onGallery: () => _pick(context, ref, slot, ImageSource.gallery),
                    onRemove: () =>
                        ref.read(captureControllerProvider.notifier).removeImage(slot),
                  ),
                if (state.error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: CubedColors.caution.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(state.error!, style: const TextStyle(color: CubedColors.caution)),
                  ),
                ],
                if (state.quickChecked) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: CubedColors.brand,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed:
                        state.isComplete ? () => _submit(context, ref) : null,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(state.isComplete
                        ? '분석·제보하기'
                        : '3장을 모두 촬영해주세요 (${state.count}/3)'),
                  ),
                ],
              ],
            ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.index,
    required this.bytes,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });
  final CaptureSlot slot;
  final int index;
  final Uint8List? bytes;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final done = bytes != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CubedColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: done ? CubedColors.brand : CubedColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: done ? CubedColors.brand : CubedColors.line,
                child: done
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text('$index', style: const TextStyle(color: CubedColors.ink, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Text(slot.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 6),
          Text(slot.hint, style: const TextStyle(color: CubedColors.inkSoft, fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          if (done)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(bytes!, height: 140, width: double.infinity, fit: BoxFit.cover),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCamera,
                  icon: const Icon(Icons.photo_camera_rounded, size: 18),
                  label: Text(done ? '다시 촬영' : '카메라'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGallery,
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: const Text('앨범'),
                ),
              ),
              if (done) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, color: CubedColors.inkSoft),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
