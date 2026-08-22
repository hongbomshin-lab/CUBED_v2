import 'dart:math' as math;
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/location_cache.dart';
import 'models/franchise_drink.dart';
import 'models/my_review.dart';
import 'models/store.dart';
import 'models/store_menu.dart';
import 'models/store_review.dart';

/// 매장 데이터 접근 (stores + store_photos).
class StoreRepository {
  StoreRepository(this._db);
  final SupabaseClient _db;

  static const _cols =
      '*, store_photos(image_url, is_primary, photo_type)';

  /// 현재 지도 영역(bounding box) 안의 활성 매장을 조회.
  /// [types] 가 비어 있으면 전체, 아니면 해당 store_type 만 필터.
  ///
  /// 프랜차이즈는 항상 제외한다 — 같은 stores 테이블에 있지만 저당맵의
  /// 주인공이 아니고, 표시 여부·반경을 franchiseStoresNear 로 따로 통제한다.
  /// (이걸 빼면 '전체' 필터에 프랜차이즈 191곳이 딸려와 토글이 무의미해진다)
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
    } else {
      query = query.neq('store_type', StoreType.franchise.dbValue);
    }

    final rows = await query.limit(limit);
    return rows.map((m) => Store.fromMap(m)).toList();
  }

  /// 내 위치 반경 [radiusM] 안의 프랜차이즈 카페.
  ///
  /// 전주만 해도 200곳 가까이라 전부 그리면 저당 전문 매장이 묻힌다.
  /// 위경도 박스로 1차 좁힌 뒤 실제 거리로 거른다(박스는 원의 외접 사각형).
  Future<List<Store>> franchiseStoresNear({
    required LatLng center,
    double radiusM = 500,
    int limit = 200,
  }) async {
    // 위도 1도 ≈ 111km. 경도는 위도가 올라갈수록 좁아지므로 cos 보정.
    final dLat = radiusM / 111000;
    final dLng = radiusM / (111000 * math.cos(center.lat * math.pi / 180));

    final rows = await _db
        .from('stores')
        .select(_cols)
        .eq('is_active', true)
        .eq('store_type', 'franchise')
        .gte('lat', center.lat - dLat)
        .lte('lat', center.lat + dLat)
        .gte('lng', center.lng - dLng)
        .lte('lng', center.lng + dLng)
        .limit(limit);

    return rows
        .map((m) => Store.fromMap(m))
        .where((s) =>
            LocationService.distanceMeters(center, LatLng(s.lat, s.lng)) <=
            radiusM)
        .toList();
  }

  /// 이 브랜드에서 당류가 낮은 메뉴 [limit]개 (당류 미상은 제외).
  /// 프랜차이즈 매장 상세에서 '여기선 이걸 드세요'로 보여준다.
  Future<List<FranchiseDrink>> lowSugarMenusFor(
    String brand, {
    int limit = 5,
  }) async {
    final rows = await _db
        .from('franchise_drinks')
        .select()
        .eq('brand', brand)
        .not('sugar_g', 'is', null)
        .order('sugar_g', ascending: true)
        .limit(limit * 4); // 같은 메뉴의 사이즈 변형을 걷어내려고 넉넉히 받는다

    // 같은 기본명(온도·사이즈 변형)은 당류가 가장 낮은 것 하나만 남긴다.
    final seen = <String>{};
    final out = <FranchiseDrink>[];
    for (final m in rows) {
      final d = FranchiseDrink.fromMap(m);
      if (seen.add(d.baseName)) out.add(d);
      if (out.length >= limit) break;
    }
    return out;
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

  /// 매장 대표 메뉴 (저당 + 시그니처). 저당 메뉴를 먼저, 그 안에서 sort_order 순.
  Future<List<StoreMenu>> menus(String storeId) async {
    final rows = await _db
        .from('store_menus')
        .select()
        .eq('store_id', storeId)
        .order('kind', ascending: true) // low_sugar < signature (사전순)
        .order('sort_order', ascending: true);
    return rows.map((m) => StoreMenu.fromMap(m)).toList();
  }

  /// 내가 즐겨찾기한 store_id 집합 (하트 상태 표시용).
  Future<Set<String>> favoriteStoreIds(String userId) async {
    final rows = await _db
        .from('store_favorites')
        .select('store_id')
        .eq('user_id', userId);
    return rows.map((m) => m['store_id'] as String).toSet();
  }

  /// 내가 즐겨찾기한 매장 목록 (최신순) — 매장 상세 표시용.
  Future<List<Store>> favoriteStores(String userId) async {
    final rows = await _db
        .from('store_favorites')
        .select('stores(*, store_photos(image_url, is_primary, photo_type))')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows
        .map((m) => m['stores'])
        .whereType<Map<String, dynamic>>()
        .map((s) => Store.fromMap(s))
        .toList();
  }

  /// 즐겨찾기 추가 (이미 있으면 무시).
  Future<void> addFavorite(String userId, String storeId) async {
    await _db.from('store_favorites').upsert(
      {'user_id': userId, 'store_id': storeId},
      onConflict: 'user_id,store_id',
      ignoreDuplicates: true,
    );
  }

  /// 즐겨찾기 삭제.
  Future<void> removeFavorite(String userId, String storeId) async {
    await _db
        .from('store_favorites')
        .delete()
        .match({'user_id': userId, 'store_id': storeId});
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
