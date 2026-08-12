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
}
