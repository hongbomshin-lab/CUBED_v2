import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/product.dart';

class ProductRecognitionResult {
  const ProductRecognitionResult({
    required this.matched,
    required this.confidence,
    required this.reason,
    this.product,
  });

  final bool matched;
  final double confidence;
  final String reason;
  final Product? product;

  factory ProductRecognitionResult.fromMap(Map<String, dynamic> map) {
    final rawProduct = map['product'];
    return ProductRecognitionResult(
      matched: map['matched'] as bool? ?? false,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      reason: map['reason'] as String? ?? '',
      product: rawProduct is Map
          ? Product.fromMap(Map<String, dynamic>.from(rawProduct))
          : null,
    );
  }
}

class ProductRecognitionService {
  ProductRecognitionService(this._db);
  final SupabaseClient _db;

  Future<ProductRecognitionResult> recognize(String imageBase64) async {
    final response = await _db.functions.invoke(
      'recognize-product',
      body: {'image': imageBase64},
    );
    final data = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    if (data is! Map) throw Exception('제품 인식 응답이 올바르지 않아요');
    final map = Map<String, dynamic>.from(data);
    if (response.status != 200 || map['error'] != null) {
      throw Exception(map['error'] ?? '제품 인식에 실패했어요');
    }
    return ProductRecognitionResult.fromMap(map);
  }
}
