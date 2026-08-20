import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/i18n/app_lang.dart';

/// 프랜차이즈 번역 사전 (franchise_translations).
///
/// 건수가 언어당 약 1,000건뿐이라 메뉴마다 조회하지 않고 통째로 받아 메모리 맵으로 쓴다.
/// 번역이 없으면 원문을 그대로 돌려준다(신규 크롤 메뉴가 아직 번역 전인 경우 대비).
class TranslationDict {
  const TranslationDict(this.lang, this._map);

  final AppLang lang;
  final Map<String, String> _map; // 'kind|source' → value

  static const empty = TranslationDict(AppLang.ko, {});

  String of(String kind, String? source) {
    final src = source?.trim() ?? '';
    if (src.isEmpty || !lang.needsTranslation) return src;
    return _map['$kind|$src'] ?? src;
  }

  String menu(String? s) => of('menu', s);
  String brand(String? s) => of('brand', s);
  String size(String? s) => of('size', s);
  String category(String? s) => of('category', s);
}

class TranslationRepository {
  TranslationRepository(this._db);
  final SupabaseClient _db;

  /// 해당 언어의 번역을 전부 로드. ko 는 원문을 쓰므로 조회하지 않는다.
  /// PostgREST 기본 1000행 상한이 있어 range 로 페이지 순회한다.
  Future<TranslationDict> load(AppLang lang) async {
    if (!lang.needsTranslation) return const TranslationDict(AppLang.ko, {});

    const page = 1000;
    final map = <String, String>{};
    for (var from = 0;; from += page) {
      final rows = await _db
          .from('franchise_translations')
          .select('kind, source, value')
          .eq('lang', lang.code)
          .range(from, from + page - 1);
      for (final r in rows) {
        map['${r['kind']}|${r['source']}'] = r['value'] as String;
      }
      if (rows.length < page) break;
    }
    return TranslationDict(lang, map);
  }
}
