import 'package:flutter/material.dart';

/// 매장 유형 — DB stores.store_type 과 1:1.
enum StoreType {
  cafe('cafe', '카페·베이커리', Color(0xFF2A7A4B), Icons.local_cafe_rounded),
  restaurant('restaurant', '음식점', Color(0xFFF57C00), Icons.restaurant_rounded),
  zeroStore('zero_store', '제로스토어', Color(0xFF1976D2), Icons.storefront_rounded),
  delivery('delivery', '배달', Color(0xFF7B1FA2), Icons.delivery_dining_rounded),
  // 프랜차이즈 카페 — 저당 전문 매장과 구분되도록 회색 계열.
  // 저당맵의 주인공은 저당 전문 매장이고, 이건 '주변에 이런 것도 있다'는 보조 정보다.
  franchise('franchise', '프랜차이즈', Color(0xFF6B7280), Icons.coffee_rounded);

  const StoreType(this.dbValue, this.label, this.markerColor, this.icon);

  /// DB에 저장되는 값 (cafe / restaurant / zero_store / delivery)
  final String dbValue;

  /// 필터칩·뱃지 표시용 라벨
  final String label;

  /// 지도 마커 색
  final Color markerColor;

  /// 마커·뱃지 아이콘
  final IconData icon;

  static StoreType fromDb(String value) =>
      StoreType.values.firstWhere((e) => e.dbValue == value,
          orElse: () => StoreType.restaurant);
}

/// 매장 사진 (store_photos 일부 컬럼).
class StorePhoto {
  final String imageUrl;
  final bool isPrimary;
  final String photoType; // exterior | interior | product | menu_board

  const StorePhoto({
    required this.imageUrl,
    required this.isPrimary,
    required this.photoType,
  });

  factory StorePhoto.fromMap(Map<String, dynamic> m) => StorePhoto(
        imageUrl: m['image_url'] as String,
        isPrimary: (m['is_primary'] as bool?) ?? false,
        photoType: (m['photo_type'] as String?) ?? 'exterior',
      );
}

/// 매장 (stores) + 조인된 사진 목록.
class Store {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String? phone;
  final String? instagramUrl;
  final String? naverPlaceUrl;
  final StoreType type;
  final String? district;
  final String? hours;
  final int reviewCount;
  final int recommendCount;
  final List<StorePhoto> photos;

  /// 프랜차이즈 브랜드명 (franchise_drinks.brand 와 같은 값).
  /// 저당 전문 매장은 null — 이 값이 있으면 상세에서 저당 메뉴를 추천한다.
  final String? brand;

  const Store({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.phone,
    this.instagramUrl,
    this.naverPlaceUrl,
    required this.type,
    this.district,
    this.hours,
    required this.reviewCount,
    required this.recommendCount,
    this.photos = const [],
    this.brand,
  });

  /// 대표 사진 (is_primary 우선, 없으면 첫 사진)
  StorePhoto? get primaryPhoto {
    if (photos.isEmpty) return null;
    return photos.firstWhere((p) => p.isPrimary, orElse: () => photos.first);
  }

  /// 추천율 0~100 (리뷰 없으면 null)
  int? get recommendRate {
    if (reviewCount == 0) return null;
    return ((recommendCount / reviewCount) * 100).round();
  }

  factory Store.fromMap(Map<String, dynamic> m) {
    final rawPhotos = (m['store_photos'] as List?) ?? const [];
    return Store(
      id: m['id'] as String,
      name: m['name'] as String,
      address: m['address'] as String,
      lat: (m['lat'] as num).toDouble(),
      lng: (m['lng'] as num).toDouble(),
      phone: m['phone'] as String?,
      instagramUrl: m['instagram_url'] as String?,
      naverPlaceUrl: m['naver_place_url'] as String?,
      type: StoreType.fromDb((m['store_type'] as String?) ?? 'restaurant'),
      district: m['district'] as String?,
      hours: m['hours'] as String?,
      reviewCount: (m['review_count'] as num?)?.toInt() ?? 0,
      recommendCount: (m['recommend_count'] as num?)?.toInt() ?? 0,
      photos: rawPhotos
          .map((e) => StorePhoto.fromMap(e as Map<String, dynamic>))
          .toList(),
      brand: m['brand'] as String?,
    );
  }
}
