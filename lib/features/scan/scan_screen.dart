import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../capture/capture_screen.dart';
import '../result/result_screen.dart';

/// 바코드 스캔 → 제품 조회. 없으면 OCR 폴백 안내.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});
  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture cap) async {
    if (_busy) return;
    if (cap.barcodes.isEmpty) return;
    final code = cap.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;
    setState(() => _busy = true);
    await _controller.stop();

    final product = await ref.read(repositoryProvider).findByBarcode(code);
    if (!mounted) return;

    if (product != null) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ResultScreen(product: product)),
      );
    } else {
      _showNotFound(code);
    }
  }

  void _showNotFound(String code) {
    showModalBottomSheet(
      context: context,
      backgroundColor: CubedColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('등록되지 않은 제품이에요',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 8),
            Text('바코드 $code 는 아직 DB에 없어요.\n영양성분·원재료 부분을 사진 찍으면 인식해서 분석해드릴게요.',
                style: const TextStyle(color: CubedColors.inkSoft, height: 1.5)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: CubedColors.brand,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => CaptureScreen(prefillBarcode: code)),
                  );
                },
                icon: const Icon(Icons.center_focus_strong_rounded),
                label: const Text('사진으로 분석하기'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() => _busy = false);
                  _controller.start();
                },
                child: const Text('다시 스캔'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('바코드 스캔', style: TextStyle(color: Colors.white)),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // 스캔 프레임 가이드
          Center(
            child: Container(
              width: 260,
              height: 170,
              decoration: BoxDecoration(
                border: Border.all(color: CubedColors.brand, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          if (_busy)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('바코드를 프레임 안에 맞춰주세요',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
