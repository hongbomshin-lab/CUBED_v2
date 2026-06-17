/// 매장 리뷰 (store_reviews).
class StoreReview {
  final String id;
  final String storeId;
  final String userId;
  final bool isRecommended;
  final String? content;
  final DateTime createdAt;

  const StoreReview({
    required this.id,
    required this.storeId,
    required this.userId,
    required this.isRecommended,
    this.content,
    required this.createdAt,
  });

  factory StoreReview.fromMap(Map<String, dynamic> m) => StoreReview(
        id: m['id'] as String,
        storeId: m['store_id'] as String,
        userId: m['user_id'] as String,
        isRecommended: (m['is_recommended'] as bool?) ?? false,
        content: (m['content'] as String?)?.trim().isEmpty ?? true
            ? null
            : (m['content'] as String).trim(),
        createdAt:
            DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}
