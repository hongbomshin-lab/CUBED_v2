import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/my_review.dart';
import 'models/store.dart';
import 'models/store_review.dart';

/// 매장 데이터 접근 (stores + store_photos).
class StoreRepository {
  StoreRepository(this._db);
  final SupabaseClient _db;

  static const _cols =
      '*, store_photos(image_url, is_primary, photo_type)';

  /// 현재 지도 영역(bounding box) 안의 활성 매장을 조회.
  /// [types] 가 비어 있으면 전체, 아니면 해당 store_type 만 필터.
  Future<List<Store>> storesInBounds({
    required double south,
    required double north,
    required double west,
    required double east,
    Set<StoreType> types = const {},
    int limit = 300,
  }) async {
    var query = _db
        .from('stores')
        .select(_cols)
        .eq('is_active', true)
        .gte('lat', south)
        .lte('lat', north)
        .gte('lng', west)
        .lte('lng', east);

    if (types.isNotEmpty) {
      query = query.inFilter(
        'store_type',
        types.map((t) => t.dbValue).toList(),
      );
    }

    final rows = await query.limit(limit);
    return rows.map((m) => Store.fromMap(m)).toList();
  }

  /// 이름으로 매장 검색 (부분일치, 최신 등록순). 지도 검색바용.
  Future<List<Store>> searchByName(String query, {int limit = 20}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final rows = await _db
        .from('stores')
        .select(_cols)
        .eq('is_active', true)
        .ilike('name', '%$q%')
        .limit(limit);
    return rows.map((m) => Store.fromMap(m)).toList();
  }

  /// 메뉴판 사진(압축본)을 Storage `menu-boards` 버킷에 업로드하고 public URL 반환.
  /// 경로: {folder}/{userId}/{ms}.jpg — 승인/반려 시 정리하기 쉽도록 유저별로 분리.
  /// [folder]는 기존 매장이면 storeId, 신규 매장 제보면 'new-store' 등.
  Future<String> uploadMenuBoardPhoto({
    required String folder,
    required String userId,
    required Uint8List bytes,
    required int millis,
  }) async {
    const bucket = 'menu-boards';
    final path = '$folder/$userId/$millis.jpg';
    await _db.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    return _db.storage.from(bucket).getPublicUrl(path);
  }

  /// 메뉴판 제보 등록. 사진 URL 필수 + 메모 선택. 승인 시 store_photos 자동 등록.
  Future<void> submitMenuBoardReport({
    required String storeId,
    required String reportedBy,
    required String imageUrl,
    String? note,
  }) async {
    await _db.from('menu_board_reports').insert({
      'store_id': storeId,
      'reported_by': reportedBy,
      'image_url': imageUrl,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  /// 매장 리뷰 목록 (최신순).
  Future<List<StoreReview>> reviews(String storeId, {int limit = 50}) async {
    final rows = await _db
        .from('store_reviews')
        .select()
        .eq('store_id', storeId)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map((m) => StoreReview.fromMap(m)).toList();
  }

  /// 내가 작성한 리뷰 전체 (최신순) — 매장명 포함. 마이페이지용.
  Future<List<MyReview>> myReviews(String userId, {int limit = 100}) async {
    final rows = await _db
        .from('store_reviews')
        .select('id, store_id, is_recommended, content, created_at, stores(name)')
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map((m) => MyReview.fromMap(m)).toList();
  }

  /// 내가 이 매장에 쓴 리뷰 (없으면 null) — 작성/수정 화면 프리필용.
  Future<StoreReview?> myReview(String storeId, String userId) async {
    final row = await _db
        .from('store_reviews')
        .select()
        .eq('store_id', storeId)
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : StoreReview.fromMap(row);
  }

  /// 리뷰 작성/수정 (매장당 1인 1리뷰 — UNIQUE 기준 upsert).
  /// 카운트(review_count·recommend_count)는 DB 트리거가 자동 갱신.
  Future<void> submitReview({
    required String storeId,
    required String userId,
    required bool isRecommended,
    String? content,
  }) async {
    final trimmed = content?.trim();
    await _db.from('store_reviews').upsert({
      'store_id': storeId,
      'user_id': userId,
      'is_recommended': isRecommended,
      'content': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'store_id,user_id');
  }

  /// 매장 제보 등록. 이름만 필수, 나머지는 선택(관리자가 승인 시 보완).
  /// [placeUrl] 네이버/카카오 플레이스 URL, [imageUrls] 메뉴판·외관 사진 URL.
  Future<void> submitStoreReport({
    required String reportedBy,
    required String name,
    String? placeUrl,
    List<String> imageUrls = const [],
  }) async {
    await _db.from('store_reports').insert({
      'reported_by': reportedBy,
      'name': name,
      if (placeUrl != null && placeUrl.isNotEmpty) 'naver_place_url': placeUrl,
      if (imageUrls.isNotEmpty) 'image_urls': imageUrls,
    });
  }
}
