import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/product.dart';
import '../../data/models/sweetener.dart';

/// OCR 파싱 결과 → 메모리상 Product (DB 저장 안 함; 해석은 동일 엔진 사용)
class OcrResult {
  final Product product;
  final List<String> unknownSweeteners;
  final String? rawText;
  const OcrResult({required this.product, this.unknownSweeteners = const [], this.rawText});
}

class OcrService {
  OcrService(this._db);
  final SupabaseClient _db;

  /// 이미지(base64)를 Edge Function 'ocr-parse'에 보내 구조화 영양정보로 변환.
  /// Edge Function이 Claude API를 호출해 task_common 규칙대로 파싱한다.
  Future<OcrResult> parseImage({
    required String imageBase64,
    String? barcode,
  }) async {
    final res = await _db.functions.invoke('ocr-parse', body: {
      'image': imageBase64,
      'barcode': barcode,
    });
    if (res.status != 200 || res.data == null) {
      throw Exception('OCR 분석 실패 (status ${res.status})');
    }
    final data = res.data is String ? jsonDecode(res.data as String) : res.data as Map;
    final m = Map<String, dynamic>.from(data as Map);

    final swList = ((m['sweeteners'] as List?) ?? const [])
        .asMap()
        .entries
        .map((e) => ProductSweetener(
              slug: (e.value as Map)['slug'] as String,
              amountG: ((e.value as Map)['amount_g'] as num?)?.toDouble(),
              sortOrder: e.key,
            ))
        .toList();

    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    final product = Product(
      productId: 'ocr-temp',
      name: (m['name'] as String?) ?? '촬영한 제품',
      brand: m['brand'] as String?,
      category: m['category'] as String?,
      servingSize: d(m['serving_size']),
      unit: (m['unit'] as String?) ?? 'g',
      kcal: d(m['kcal']),
      carb: d(m['carb']),
      sugar: d(m['sugar']),
      protein: d(m['protein']),
      fat: d(m['fat']),
      sodiumMg: (m['sodium_mg'] as num?)?.toDouble(),
      fiber: d(m['fiber']),
      sugarAlcohol: d(m['sugar_alcohol']),
      rareSugarG: d(m['rare_sugar_g']),
      ingredientsRaw: m['ingredients_raw'] as String?,
      sweetenerCount: swList.length,
      barcode: barcode,
      verified: false,
      sourceType: 'OCR제보',
      notes: m['notes'] as String?,
      sweeteners: swList,
    );

    return OcrResult(
      product: product,
      unknownSweeteners: ((m['unknown_sweeteners'] as List?) ?? const []).cast<String>(),
      rawText: m['ingredients_raw'] as String?,
    );
  }
}
