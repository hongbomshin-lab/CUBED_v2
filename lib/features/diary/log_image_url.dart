import '../../core/env.dart';
import '../../data/models/food_log.dart';

/// 먹은 기록 썸네일 URL 분기 (스펙 §5).
/// - DB 제품: product-images 공개 URL. 규칙 products.image_file = "{product_id}.png"
///   (이미지 없는 제품은 404 → 위젯 errorWidget 폴백)
/// - 촬영 제품: submission-images authenticated URL (Authorization 헤더 필요)
/// - 둘 다 없으면 null → placeholder
({String url, bool needsAuth})? logImageUrl(FoodLog log) {
  if (log.productId != null) {
    return (
      url: '${Env.imageBaseUrl}/${log.productId}.png',
      needsAuth: false,
    );
  }
  final path = log.imagePath;
  if (path != null && path.isNotEmpty) {
    return (
      url:
          '${Env.supabaseUrl}/storage/v1/object/authenticated/submission-images/$path/full.jpg',
      needsAuth: true,
    );
  }
  return null;
}
