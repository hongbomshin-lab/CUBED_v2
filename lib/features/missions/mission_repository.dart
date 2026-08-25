import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

import '../../data/points_repository.dart';
import 'mission_models.dart';

/// 미션 정의를 읽어 온다.
///
/// 서버(missions 테이블)가 원본이다 — 미션 추가는 DB 한 줄이고 앱 배포가 필요 없다.
/// 서버 컬럼명이 앱 모델과 달라(sort_order/is_active) 여기서 맞춰 준다.
///
/// 네트워크가 막히면 에셋(assets/missions.json)으로 폴백한다.
/// 미션 목록은 화면을 그리는 데만 쓰이고 **적립 금액은 서버가 정하므로**,
/// 폴백 값이 실제와 달라도 포인트가 잘못 나가지는 않는다.
class MissionRepository {
  const MissionRepository(this._points);
  final PointsRepository _points;

  Future<List<Mission>> load() async {
    try {
      final rows = await _points.missions();
      if (rows.isNotEmpty) return _parse(rows.map(_fromServer));
    } catch (e) {
      debugPrint('미션 정의 서버 조회 실패, 에셋으로 폴백: $e');
    }
    final raw = await rootBundle.loadString('assets/missions.json');
    return _parse((jsonDecode(raw) as List).cast<Map<String, dynamic>>());
  }

  static List<Mission> _parse(Iterable<Map<String, dynamic>> rows) =>
      rows.map(Mission.fromMap).where((m) => m.active).toList()
        ..sort((a, b) => a.sort.compareTo(b.sort));

  /// 서버 스키마 → 앱 모델 키.
  static Map<String, dynamic> _fromServer(Map<String, dynamic> r) => {
        ...r,
        'sort': r['sort_order'],
        'active': r['is_active'],
      };
}
