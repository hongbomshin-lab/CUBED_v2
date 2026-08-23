import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'mission_models.dart';

/// 미션 정의를 읽어 온다.
///
/// 지금은 에셋(assets/missions.json)에서 읽는다 — CSV → 스크립트로 생성한 파일이다.
/// 나중에 missions 테이블이 생기면 이 클래스의 [load] 만 Supabase 조회로 바꾸면
/// 나머지 코드는 손대지 않아도 된다. 미션 정의를 앱 코드에 두지 않으려는 구조다.
class MissionRepository {
  const MissionRepository();

  Future<List<Mission>> load() async {
    final raw = await rootBundle.loadString('assets/missions.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list
        .map(Mission.fromMap)
        .where((m) => m.active)
        .toList()
      ..sort((a, b) => a.sort.compareTo(b.sort));
  }
}
