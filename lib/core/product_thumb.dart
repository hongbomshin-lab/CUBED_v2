import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'env.dart';
import 'theme.dart';

/// 제품 대표 썸네일 (Storage product-images 버킷). 없으면 아이콘 폴백.
class ProductThumb extends StatelessWidget {
  const ProductThumb({super.key, required this.imageFile, this.size = 72, this.radius = 16});
  final String? imageFile;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = (imageFile != null && imageFile!.isNotEmpty)
        ? '${Env.imageBaseUrl}/$imageFile'
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: CubedColors.bg,
        child: url == null
            ? _fallback()
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => _fallback(),
                errorWidget: (_, __, ___) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback() => Container(
        decoration: BoxDecoration(
          color: CubedColors.bg,
          border: Border.all(color: CubedColors.line),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: const Icon(Icons.image_outlined, color: CubedColors.inkSoft),
      );
}
