import '../../data/models/brand_deal.dart';

/// 포인트 적립/사용 사유.
enum PointReason {
  lowSugarLog('저당 제품 기록'),
  midSugarLog('제품 기록'),
  streakBonus('연속 기록 보너스'),
  redeem('상품 구매에 사용');

  const PointReason(this.label);
  final String label;
}

/// 원장 한 줄. 적립은 +, 사용은 −.
///
/// 잔액을 따로 저장하지 않고 이 목록의 합으로 구한다 —
/// 포인트는 돈이라 '언제 왜 얼마'가 항상 되짚어져야 한다.
class PointEntry {
  final String id;
  final DateTime at;
  final int delta;
  final PointReason reason;

  /// 무엇 때문인지 (제품명·상품명). 화면에 그대로 보여준다.
  final String? subject;

  const PointEntry({
    required this.id,
    required this.at,
    required this.delta,
    required this.reason,
    this.subject,
  });

  bool get isEarn => delta > 0;
}

/// 포인트 정책 — 적립 공식은 아직 확정 전이라 값을 여기 한 곳에 모아 둔다.
/// 나중에 로직이 정해지면 이 클래스만 고치면 된다.
class PointPolicy {
  PointPolicy._();

  /// 1P 의 원화 가치. 결제액 차감에 쓴다.
  static const int wonPerPoint = 1;

  /// 먹은 기록 1건당 적립 (제품 등급 기준).
  static const int lowSugarEarn = 30;
  static const int midSugarEarn = 10;
  static const int cautionEarn = 0;

  /// 한 주문에 쓸 수 있는 최대 비율 — 전액 포인트 결제는 막는다.
  /// (적립 로직이 확정되기 전까지 안전장치)
  static const double maxUseRatio = 0.5;

  static int earnFor(String? grade) => switch (grade) {
        'low' => lowSugarEarn,
        'mid' => midSugarEarn,
        _ => cautionEarn,
      };

  /// 이 상품에 쓸 수 있는 포인트 상한 (잔액과 비율 중 작은 쪽).
  static int usableFor(int price, int balance) {
    final byRatio = (price * maxUseRatio) ~/ 1;
    return byRatio < balance ? byRatio : balance;
  }
}

/// 포인트 상점에 걸리는 상품 — 핫딜(brand_deals)을 그대로 쓴다.
/// 가짜 상품을 만들지 않고 실제 판매중인 제품만 노출한다.
class ShopItem {
  final BrandDeal deal;
  const ShopItem(this.deal);

  String get name => deal.name;
  String get brandName => deal.brandName;
  String? get imageUrl => deal.imageUrl;
  int get price => deal.salePrice;

  /// 이 상품에 최대로 쓸 수 있는 포인트.
  int maxUsablePoints(int balance) => PointPolicy.usableFor(price, balance);
}
