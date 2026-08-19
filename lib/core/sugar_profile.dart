import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 당류 개인화 목표 — 온보딩 통합 질문 1문항의 답.
enum SugarGoal { bloodSugar, weight, general }

/// 당류 개인화 프로필 — SharedPreferences JSON 1키, 서버 미동기화.
/// 이후 개인화(다른 영양소 기준 등)를 얹을 수 있는 확장 지점.
class SugarProfile {
  final SugarGoal goal;
  final double? weightKg; // null = 기본 2000kcal 가정
  final int? mealsPerDay; // null = 3끼

  const SugarProfile({required this.goal, this.weightKg, this.mealsPerDay});

  static const _key = 'sugar_profile';

  Map<String, dynamic> toJson() => {
        'goal': goal.name,
        'weightKg': weightKg,
        'mealsPerDay': mealsPerDay,
      };

  factory SugarProfile.fromJson(Map<String, dynamic> m) => SugarProfile(
        goal: SugarGoal.values.asNameMap()[m['goal']] ?? SugarGoal.general,
        weightKg: (m['weightKg'] as num?)?.toDouble(),
        mealsPerDay: (m['mealsPerDay'] as num?)?.toInt(),
      );

  /// 저장된 프로필. 없거나 깨졌으면 null(= 미설정).
  static Future<SugarProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return SugarProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(SugarProfile p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(p.toJson()));
  }
}
