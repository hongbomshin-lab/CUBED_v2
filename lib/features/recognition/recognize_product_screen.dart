import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../capture/capture_screen.dart';
import '../result/result_screen.dart';
import 'product_recognition_service.dart';

class RecognizeProductScreen extends ConsumerStatefulWidget {
  const RecognizeProductScreen({super.key});

  @override
  ConsumerState<RecognizeProductScreen> createState() =>
      _RecognizeProductScreenState();
}

class _RecognizeProductScreenState
    extends ConsumerState<RecognizeProductScreen> {
  Uint8List? _image;
  bool _submitting = false;
  bool _notMatched = false;
  String? _message;

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 82,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _image = bytes;
      _notMatched = false;
      _message = null;
    });
  }

  Future<void> _recognize() async {
    final image = _image;
    if (image == null || _submitting) return;
    setState(() {
      _submitting = true;
      _notMatched = false;
      _message = null;
    });
    try {
      final service = ProductRecognitionService(ref.read(supabaseProvider));
      final result = await service.recognize(base64Encode(image));
      if (!mounted) return;
      if (result.matched && result.product != null) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (_) => ResultScreen(product: result.product!)),
        );
        return;
      }
      setState(() {
        _notMatched = true;
        _message = result.reason.isEmpty ? null : result.reason;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '$error'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openDetailedAnalysis() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CaptureScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사진으로 제품 찾기')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text('라라스윗 제품 앞면을 촬영해주세요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text('제품명과 맛이 한 화면에 보이면 더 정확해요.',
              style: TextStyle(color: CubedColors.inkSoft, fontSize: 13)),
          const SizedBox(height: 18),
          _PhotoArea(image: _image),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _submitting ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: Text(_image == null ? '카메라' : '다시 촬영'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _submitting ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('앨범'),
                ),
              ),
            ],
          ),
          if (_notMatched || _message != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: (_notMatched ? CubedColors.mid : CubedColors.caution)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _notMatched
                        ? Icons.search_off_rounded
                        : Icons.error_outline_rounded,
                    size: 19,
                    color: _notMatched ? CubedColors.mid : CubedColors.caution,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _notMatched
                          ? '라라스윗 제품을 찾지 못했어요.${_message == null ? '' : '\n$_message'}'
                          : _message!,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: CubedColors.brand,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            onPressed: _image == null || _submitting ? null : _recognize,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.center_focus_strong_rounded),
            label: Text(_submitting ? '제품을 찾고 있어요' : '이 제품 찾기'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _submitting ? null : _openDetailedAnalysis,
            icon: const Icon(Icons.document_scanner_outlined, size: 18),
            label: const Text('원재료·영양정보까지 직접 분석'),
          ),
        ],
      ),
    );
  }
}

class _PhotoArea extends StatelessWidget {
  const _PhotoArea({required this.image});
  final Uint8List? image;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(
          color: CubedColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: CubedColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: image == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      size: 42, color: CubedColors.inkSoft),
                  SizedBox(height: 10),
                  Text('제품 앞면 사진 1장',
                      style:
                          TextStyle(color: CubedColors.inkSoft, fontSize: 13)),
                ],
              )
            : Image.memory(image!, fit: BoxFit.contain),
      ),
    );
  }
}
