/// 제품 코멘트 (product_comments)
class Comment {
  final int id;
  final String productId;
  final String userId;
  final String? nickname;
  final String body;
  final DateTime createdAt;

  const Comment({
    required this.id,
    required this.productId,
    required this.userId,
    this.nickname,
    required this.body,
    required this.createdAt,
  });

  factory Comment.fromMap(Map<String, dynamic> m) => Comment(
        id: (m['id'] as num).toInt(),
        productId: m['product_id'] as String,
        userId: m['user_id'] as String,
        nickname: m['nickname'] as String?,
        body: m['body'] as String? ?? '',
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// 좋아요 상태 + 개수
class LikeInfo {
  final int count;
  final bool liked;
  const LikeInfo({required this.count, required this.liked});
}
