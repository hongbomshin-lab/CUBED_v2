/// 매장 대표 메뉴 (store_menus) — 저당 메뉴 + 시그니처 메뉴.
class StoreMenu {
  final String id;
  final String storeId;
  final String name;

  /// 'low_sugar' | 'signature'
  final String kind;

  /// 공개된 값이 없으면 null — 앱에서 '정보 준비 중'으로 표시한다.
  final double? sugarG;
  final double? calories;
  final int? priceWon;

  /// 기준량 ('160g', '1L' 등). 없을 수 있다.
  final String? serving;
  final String? note;

  final String sourceUrl;

  /// 'official' | 'menu_board' | 'estimated'
  final String confidence;

  const StoreMenu({
    required this.id,
    required this.storeId,
    required this.name,
    required this.kind,
    this.sugarG,
    this.calories,
    this.priceWon,
    this.serving,
    this.note,
    required this.sourceUrl,
    required this.confidence,
  });

  bool get isLowSugar => kind == 'low_sugar';

  /// 당류가 공개되지 않은 메뉴 — 수치 대신 안내 문구를 보여준다.
  bool get sugarUnknown => sugarG == null;

  /// 추정값은 배지로 구분해 사용자가 신뢰도를 알 수 있게 한다.
  bool get isEstimated => confidence == 'estimated';

  static double? _d(dynamic v) => v == null ? null : (v as num).toDouble();
  static String? _s(dynamic v) {
    final s = (v as String?)?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory StoreMenu.fromMap(Map<String, dynamic> m) => StoreMenu(
        id: m['id'] as String,
        storeId: m['store_id'] as String,
        name: m['name'] as String,
        kind: m['kind'] as String,
        sugarG: _d(m['sugar_g']),
        calories: _d(m['calories']),
        priceWon: (m['price_won'] as num?)?.toInt(),
        serving: _s(m['serving']),
        note: _s(m['note']),
        sourceUrl: m['source_url'] as String,
        confidence: m['confidence'] as String,
      );
}
