/// 앱 기능 온/오프 스위치.
///
/// 코드는 지우지 않고 UI 노출만 제어할 때 사용한다.
/// 나중에 다시 켜려면 해당 플래그를 `true`로 바꾸기만 하면 된다.
class FeatureFlags {
  FeatureFlags._();

  /// 바코드 스캔(제품 바코드 → 조회) 기능.
  ///
  /// 관련 코드(ScanScreen, mobile_scanner 의존성, findByBarcode,
  /// CaptureScreen.prefillBarcode)는 모두 그대로 유지되며, 이 플래그가
  /// `false`인 동안 홈 화면 진입점만 숨겨진다. 재도입 시 `true`로 변경.
  static const bool barcodeScan = false;

  /// 데모용 위치 고정 (IR 시연).
  ///
  /// 저당맵의 프랜차이즈 표시는 '내 위치 반경 500m' 기준이라, 서울에서 실행하면
  /// 전주 매장이 하나도 안 잡힌다. 이 플래그가 `true`인 동안 GPS 대신
  /// [demoLat]/[demoLng] 를 사용자 위치로 쓴다.
  ///
  /// 시연이 끝나면 `false` 로만 바꾸면 실제 GPS 로 돌아간다.
  ///
  /// 지금은 꺼져 있다 — 실제 현재 위치를 쓴다.
  /// 다시 시연할 때 `true` 로만 바꾸면 되도록 좌표는 남겨 둔다.
  static const bool useDemoLocation = false;

  /// 전주 신시가지(홍산로 일대) — 저당 전문 매장과 프랜차이즈가 함께 몰려 있어
  /// 시연에서 두 종류가 같이 보인다.
  static const double demoLat = 35.8156;
  static const double demoLng = 127.1064;
}
