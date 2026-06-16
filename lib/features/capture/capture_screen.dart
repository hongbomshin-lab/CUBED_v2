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

/// 미등록 제품 제보: 전체샷·원재료·영양성분 3장 가이드 촬영 → 분석.
class CaptureScreen extends ConsumerWidget {
  const CaptureScreen({super.key, this.prefillBarcode});
  final String? prefillBarcode;

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    CaptureSlot slot,
    ImageSource source,
  ) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 80,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    ref.read(captureControllerProvider.notifier).setImage(slot, bytes);
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
        barcode: prefillBarcode,
      );
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ResultScreen(product: result.product)),
      );
    } catch (e) {
      ctrl.setError('$e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(captureControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('사진으로 분석 (3장)')),
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
                const Text('아래 3장을 모두 촬영하면 분석돼요',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('전체샷으로 카테고리를, 원재료·영양성분으로 대체당과 혈당 영향을 분석해요.',
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
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: CubedColors.brand,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: state.isComplete ? () => _submit(context, ref) : null,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(state.isComplete ? '분석·제보하기' : '3장을 모두 촬영해주세요 (${state.count}/3)'),
                ),
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
