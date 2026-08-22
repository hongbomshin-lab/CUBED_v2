import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_lang.dart';

/// 메뉴 정보 화면의 표시 언어 상태.
///
/// 우선순위: 저장된 사용자 선택 > 기기 언어 > 한국어.
/// 첫 프레임에 깜빡이지 않도록 저장값을 먼저 동기 반영하고, 이후 선택 시 저장한다.
class LocaleController extends StateNotifier<AppLang> {
  LocaleController() : super(AppLang.fromDevice()) {
    _restore();
  }

  static const _prefsKey = 'menu_display_lang';

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = AppLang.fromCode(prefs.getString(_prefsKey));
    // 저장된 선택이 있으면 그것이 최우선(기기 언어보다 사용자 의사가 우선).
    if (saved != null && saved != state) state = saved;
  }

  Future<void> select(AppLang lang) async {
    if (lang == state) return;
    state = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, lang.code);
  }
}
