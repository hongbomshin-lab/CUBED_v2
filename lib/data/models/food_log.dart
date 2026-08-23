/// 먹은 기록 (product_logs 테이블) — 제품 스냅샷 1건.
/// product_id가 null이면 촬영(OCR) 제품, 아니면 DB 제품.
class FoodLog {
  final String id;
  final DateTime eatenOn; // 날짜만 의미 (로컬 기준, 스펙 §6)
  final String? productId;
  final String name;
  final String? brand;
  final String? category;
  final String? grade; // 'low' | 'mid' | 'caution' 스냅샷
  final String? imagePath; // submission-images 폴더 uuid
  final int points; // 아낀 설탕 g (기록 시점 계산 스냅샷)

  const FoodLog({
    required this.id,
    required this.eatenOn,
    this.productId,
    required this.name,
    this.brand,
    this.category,
    this.grade,
    this.imagePath,
    this.points = 0,
  });

  /// 로컬 날짜 → 'yyyy-MM-dd' (eaten_on 컬럼 키)
  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// 이 기록이 해당 제품과 같은 항목인지 — dedup 인덱스
  /// coalesce(product_id, lower(name)) 와 동일 규칙.
  bool matches({String? productId, required String name}) {
    if (productId != null) return this.productId == productId;
    return this.productId == null &&
        this.name.toLowerCase() == name.toLowerCase();
  }

  factory FoodLog.fromMap(Map<String, dynamic> m) => FoodLog(
        id: m['id'] as String,
        eatenOn: DateTime.parse(m['eaten_on'] as String),
        productId: m['product_id'] as String?,
        name: m['name'] as String? ?? '',
        brand: m['brand'] as String?,
        category: m['category'] as String?,
        grade: m['grade'] as String?,
        imagePath: m['image_path'] as String?,
        points: (m['points'] as num?)?.toInt() ?? 0,
      );

  /// insert용 맵 (id·created_at은 DB 기본값 사용)
  static Map<String, dynamic> insertMap({
    required String userId,
    required DateTime eatenOn,
    String? productId,
    required String name,
    String? brand,
    String? category,
    String? grade,
    String? imagePath,
    int points = 0,
  }) =>
      {
        'user_id': userId,
        'eaten_on': dateKey(eatenOn),
        'product_id': productId,
        'name': name,
        'brand': brand,
        'category': category,
        'grade': grade,
        'image_path': imagePath,
        'points': points,
      };
}
