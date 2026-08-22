import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'feature_flags.dart';

/// 단순 위경도 좌표.
class LatLng {
  final double lat;
  final double lng;
  const LatLng(this.lat, this.lng);
}

/// 위치 캐시 + 권한/현재위치 해석.
///
/// - SharedPreferences key: `jodangmap_location`, value: {lat, lng, savedAt(ms)}
/// - 캐시 유효기간 24시간
/// - 권한 거부/실패 시 서울 중심 기본값
class LocationService {
  static const _key = 'jodangmap_location';
  static const _ttl = Duration(hours: 24);

  /// 위치 확인 불가 시 기본 중심 좌표
  static const fallback = LatLng(37.58045239, 126.9971964);

  /// 캐시된 위치 (유효할 때만). 없거나 만료면 null.
  static Future<LatLng?> readCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt =
          DateTime.fromMillisecondsSinceEpoch((m['savedAt'] as num).toInt());
      if (DateTime.now().difference(savedAt) > _ttl) return null;
      return LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeCache(LatLng loc) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'lat': loc.lat,
        'lng': loc.lng,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  /// 권한 요청 후 사용자 현재 위치를 취득.
  /// 권한 거부 / 위치서비스 꺼짐 / 실패 시 null (지도는 서울 기본값 유지).
  /// 성공 시 캐시에 저장.
  static Future<LatLng?> currentPosition() async {
    // 데모 모드에서는 GPS 를 건너뛰고 고정 좌표를 쓴다 (IR 시연용).
    // 서울에서 실행해도 전주 매장이 '내 주변'으로 잡히게 하기 위함.
    if (FeatureFlags.useDemoLocation) {
      return const LatLng(FeatureFlags.demoLat, FeatureFlags.demoLng);
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition();
      final loc = LatLng(pos.latitude, pos.longitude);
      // 서비스 지역(한국) 밖 좌표는 확인 불가로 간주 → null (에뮬레이터 미국 GPS 방지)
      if (!_inKorea(loc)) return null;
      await writeCache(loc);
      return loc;
    } catch (_) {
      return null;
    }
  }

  /// 대략적 한국 영역 (위도 33~39, 경도 124~132)
  static bool _inKorea(LatLng l) =>
      l.lat >= 33 && l.lat <= 39 && l.lng >= 124 && l.lng <= 132;

  /// 두 좌표 간 거리(m). 사람이 읽기 좋은 문자열로 포맷.
  /// 두 좌표 사이 거리(m). 반경 필터에 쓴다.
  static double distanceMeters(LatLng from, LatLng to) =>
      Geolocator.distanceBetween(from.lat, from.lng, to.lat, to.lng);

  static String formatDistance(LatLng from, LatLng to) {
    final meters =
        Geolocator.distanceBetween(from.lat, from.lng, to.lat, to.lng);
    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }
}
