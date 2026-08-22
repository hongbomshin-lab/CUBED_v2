import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/product.dart';
import '../../data/models/sweetener.dart';

/// OCR 파싱 결과 → 메모리상 Product (DB 저장 안 함; 해석은 동일 엔진 사용)
class OcrResult {
  final Product product;
  final String? priceCatalogKey;
  final String? priceCatalogName;
  final double? priceMatchConfidence;
  final List<String> unknownSweeteners;
  final String? rawText;
  final String? imagePath; // submission-images 폴더 uuid (서버 저장 실패 시 null)
  const OcrResult(
      {required this.product,
      this.priceCatalogKey,
      this.priceCatalogName,
      this.priceMatchConfidence,
      this.unknownSweeteners = const [],
      this.rawText,
      this.imagePath});

  /// 파싱 결과 맵 → OcrResult (순수 변환; 네트워크 무관). ocr-parse/submit-product 응답 공용.
  factory OcrResult.fromParsed(Map<String, dynamic> m, {String? barcode}) {
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    final swList = ((m['sweeteners'] as List?) ?? const [])
        .asMap()
        .entries
        .map((e) => ProductSweetener(
              slug: (e.value as Map)['slug'] as String,
              amountG: ((e.value as Map)['amount_g'] as num?)?.toDouble(),
              sortOrder: e.key,
            ))
        .toList();
    final parsedProduct = Product(
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
    final matched = m['matched_product'];
    final priceMatch = m['price_match'];
    final priceMatchMap = priceMatch is Map
        ? Map<String, dynamic>.from(priceMatch)
        : const <String, dynamic>{};
    final product = matched is Map
        ? Product.fromMap(Map<String, dynamic>.from(matched))
        : parsedProduct;
    return OcrResult(
      product: product,
      priceCatalogKey: priceMatchMap['catalog_product_key'] as String?,
      priceCatalogName: priceMatchMap['catalog_name'] as String?,
      priceMatchConfidence: (priceMatchMap['confidence'] as num?)?.toDouble(),
      unknownSweeteners:
          ((m['unknown_sweeteners'] as List?) ?? const []).cast<String>(),
      rawText: m['ingredients_raw'] as String?,
      imagePath: m['image_path'] as String?,
    );
  }
}

class OcrService {
  OcrService(this._db);
  final SupabaseClient _db;

  /// 3장(전체샷·원재료·영양성분, base64) + 바코드 → submit-product 호출.
  /// Edge Function이 CLOVA 멀티이미지로 파싱하고 제보를 저장한 뒤 파싱 결과를 돌려준다.
  Future<OcrResult> parseAndSubmit({
    required String fullB64,
    required String ingredientsB64,
    required String nutritionB64,
    String? barcode,
  }) async {
    final res = await _db.functions.invoke('submit-product', body: {
      'images': {
        'full': fullB64,
        'ingredients': ingredientsB64,
        'nutrition': nutritionB64,
      },
      'barcode': barcode,
    });
    if (res.status != 200 || res.data == null) {
      throw Exception('분석 실패 (status ${res.status})');
    }
    final data = res.data is String ? jsonDecode(res.data as String) : res.data;
    final m = Map<String, dynamic>.from(data as Map);
    if (m['error'] != null) throw Exception('분석 실패: ${m['error']}');
    return OcrResult.fromParsed(m, barcode: barcode);
  }

  /// 전면 1장 빠른 매칭 — 등록 제품/가격 카탈로그 매칭만 시도(파싱·제보 없음).
  /// 매칭 실패·오류 시 null → 호출부는 현행 3장 플로우로 계속.
  Future<OcrResult?> quickMatch({required String fullB64}) async {
    final res = await _db.functions.invoke('submit-product', body: {
      'quick': true,
      'images': {'full': fullB64},
    });
    if (res.status != 200 || res.data == null) {
      debugPrint('quickMatch: HTTP ${res.status} — ${res.data}');
      return null;
    }
    final data = res.data is String ? jsonDecode(res.data as String) : res.data;
    final m = Map<String, dynamic>.from(data as Map);
    final matched = m['matched_product'];
    if (matched is! Map) {
      debugPrint('quickMatch: 매칭 없음 (matched_product null)');
      return null;
    }
    final priceMatch = m['price_match'];
    final priceMatchMap = priceMatch is Map
        ? Map<String, dynamic>.from(priceMatch)
        : const <String, dynamic>{};
    return OcrResult(
      product: Product.fromMap(Map<String, dynamic>.from(matched)),
      priceCatalogKey: priceMatchMap['catalog_product_key'] as String?,
      priceCatalogName: priceMatchMap['catalog_name'] as String?,
      priceMatchConfidence: (priceMatchMap['confidence'] as num?)?.toDouble(),
    );
  }
}
