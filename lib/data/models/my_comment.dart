/// 마이페이지 "작성한 댓글" 항목 — product_comments + 제품명(products.name) 조인 결과.
class MyComment {
  final int id;
  final String productId;
  final String productName;
  final String? brand;
  final String body;
  final DateTime createdAt;

  const MyComment({
    required this.id,
    required this.productId,
    required this.productName,
    this.brand,
    required this.body,
    required this.createdAt,
  });

  factory MyComment.fromMap(Map<String, dynamic> m) {
    final product = m['products'];
    String name = '(삭제된 제품)';
    String? brand;
    if (product is Map) {
      name = product['name'] as String? ?? name;
      brand = product['brand'] as String?;
    } else if (product is List && product.isNotEmpty && product.first is Map) {
      final p = product.first as Map;
      name = p['name'] as String? ?? name;
      brand = p['brand'] as String?;
    }
    return MyComment(
      id: (m['id'] as num).toInt(),
      productId: m['product_id'] as String,
      productName: name,
      brand: brand,
      body: m['body'] as String? ?? '',
      createdAt:
          DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
