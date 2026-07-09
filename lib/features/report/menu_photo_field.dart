import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';

/// 메뉴판 사진 선택·압축·미리보기 공용 위젯.
/// 촬영/갤러리 선택 → 가로 1440px·품질 70 압축 → 부모에 압축본(bytes) 전달.
/// 부모가 [photo]를 보관하고, 변경 시 [onChanged]로 통지받는다(null이면 삭제).
class MenuPhotoField extends StatefulWidget {
  const MenuPhotoField({
    super.key,
    required this.photo,
    required this.onChanged,
  });

  final Uint8List? photo;
  final ValueChanged<Uint8List?> onChanged;

  @override
  State<MenuPhotoField> createState() => _MenuPhotoFieldState();
}

class _MenuPhotoFieldState extends State<MenuPhotoField> {
  final _picker = ImagePicker();
  bool _picking = false;

  /// 압축 후에도 이 크기를 넘으면 거부 (초고해상도/악성 방어).
  static const _maxBytes = 800 * 1024; // 800 KB

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pick(ImageSource source) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1440,
        imageQuality: 85, // picker 1차 축소. 정밀 압축은 아래에서.
      );
      if (picked == null) return;

      final raw = await picked.readAsBytes();
      final compressed = await FlutterImageCompress.compressWithList(
        raw,
        minWidth: 1440,
        minHeight: 1440,
        quality: 70,
        format: CompressFormat.jpeg,
      );

      if (compressed.length > _maxBytes) {
        _toast('사진 용량이 너무 커요. 더 낮은 해상도로 다시 시도해 주세요');
        return;
      }
      widget.onChanged(compressed);
    } catch (e) {
      _toast('사진을 불러오지 못했어요. 다시 시도해 주세요');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _showPickSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: CubedColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: CubedColors.brand),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: CubedColors.brand),
              title: const Text('갤러리에서 선택'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pick(source);
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    if (photo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.memory(photo, fit: BoxFit.cover),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => widget.onChanged(null),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.close_rounded,
                        size: 18, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return InkWell(
      onTap: _picking ? null : _showPickSheet,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: CubedColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CubedColors.line),
        ),
        child: Center(
          child: _picking
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add_a_photo_rounded,
                        size: 28, color: CubedColors.inkSoft),
                    SizedBox(height: 8),
                    Text('사진 촬영 / 갤러리에서 선택',
                        style:
                            TextStyle(fontSize: 13, color: CubedColors.inkSoft)),
                  ],
                ),
        ),
      ),
    );
  }
}
