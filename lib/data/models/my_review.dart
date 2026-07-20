/// 마이페이지 "작성한 리뷰" 항목 — store_reviews + 매장명(stores.name) 조인 결과.
class MyReview {
  final String id;
  final String storeId;
  final String storeName;
  final bool isRecommended;
  final String? content;
  final DateTime createdAt;

  const MyReview({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.isRecommended,
    this.content,
    required this.createdAt,
  });

  factory MyReview.fromMap(Map<String, dynamic> m) {
    // 조인 형태: stores 가 map 또는 (예외적으로) list 로 올 수 있어 모두 방어.
    final store = m['stores'];
    String name = '(삭제된 매장)';
    if (store is Map && store['name'] is String) {
      name = store['name'] as String;
    } else if (store is List && store.isNotEmpty && store.first is Map) {
      name = (store.first as Map)['name'] as String? ?? name;
    }
    return MyReview(
      id: m['id'] as String,
      storeId: m['store_id'] as String,
      storeName: name,
      isRecommended: (m['is_recommended'] as bool?) ?? false,
      content: (m['content'] as String?)?.trim().isEmpty ?? true
          ? null
          : (m['content'] as String).trim(),
      createdAt:
          DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
