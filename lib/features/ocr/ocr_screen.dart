import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../result/result_screen.dart';
import 'ocr_service.dart';

class OcrScreen extends ConsumerStatefulWidget {
  const OcrScreen({super.key, this.prefillBarcode});
  final String? prefillBarcode;
  @override
  ConsumerState<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends ConsumerState<OcrScreen> {
  final _picker = ImagePicker();
  bool _busy = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) {
        setState(() => _busy = false);
        return;
      }
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);

      final service = OcrService(ref.read(supabaseProvider));
      final result = await service.parseImage(
        imageBase64: b64,
        barcode: widget.prefillBarcode,
      );

      // 제보 기록(선택) — 미등록 제품 DB 성장 루프
      await ref.read(repositoryProvider).submitOcr(
            barcode: widget.prefillBarcode,
            ocrText: result.rawText,
            parsed: {'name': result.product.name, 'category': result.product.category},
          );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ResultScreen(product: result.product)),
      );
    } catch (e) {
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사진으로 분석')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            const Text('영양성분표를 촬영하세요',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              '바코드가 없거나 등록되지 않은 제품이어도, 영양성분·원재료가 잘 보이게 찍으면 AI가 인식해 동일하게 분석해드려요.',
              style: TextStyle(color: CubedColors.inkSoft, height: 1.5),
            ),
            const SizedBox(height: 28),
            if (_busy) ...[
              const Center(child: CircularProgressIndicator(color: CubedColors.brand)),
              const SizedBox(height: 16),
              const Center(
                child: Text('AI가 영양성분을 읽고 있어요…',
                    style: TextStyle(color: CubedColors.inkSoft)),
              ),
            ] else ...[
              _OcrButton(
                icon: Icons.photo_camera_rounded,
                label: '카메라로 촬영',
                primary: true,
                onTap: () => _pick(ImageSource.camera),
              ),
              const SizedBox(height: 12),
              _OcrButton(
                icon: Icons.photo_library_rounded,
                label: '앨범에서 선택',
                primary: false,
                onTap: () => _pick(ImageSource.gallery),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CubedColors.caution.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(_error!, style: const TextStyle(color: CubedColors.caution)),
              ),
            ],
            const Spacer(),
            const _Tip(),
          ],
        ),
      ),
    );
  }
}

class _OcrButton extends StatelessWidget {
  const _OcrButton({
    required this.icon,
    required this.label,
    required this.primary,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: primary ? CubedColors.brand : CubedColors.surface,
        foregroundColor: primary ? Colors.white : CubedColors.ink,
        side: primary ? null : const BorderSide(color: CubedColors.line),
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
      ),
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CubedColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CubedColors.line),
      ),
      child: const Row(children: [
        Text('💡', style: TextStyle(fontSize: 16)),
        SizedBox(width: 10),
        Expanded(
          child: Text('표가 정면으로, 글자가 또렷하게 나오도록 찍으면 인식률이 높아요.',
              style: TextStyle(color: CubedColors.inkSoft, fontSize: 13, height: 1.4)),
        ),
      ]),
    );
  }
}
