import 'dart:ui' as ui;

/// 저당맵 메뉴 정보에서 지원하는 표시 언어.
enum AppLang {
  ko('ko', '한국어', '한'),
  en('en', 'English', 'EN'),
  ja('ja', '日本語', '日'),
  zh('zh', '中文', '中');

  const AppLang(this.code, this.label, this.short);

  /// franchise_translations.lang 값(ko 는 원문이라 조회하지 않는다)
  final String code;

  /// 선택 목록에 보여줄 이름(각 언어 원어 표기)
  final String label;

  /// 접힌 버튼에 보여줄 1~2자 표기
  final String short;

  bool get needsTranslation => this != AppLang.ko;

  static AppLang? fromCode(String? code) {
    if (code == null) return null;
    for (final l in AppLang.values) {
      if (l.code == code) return l;
    }
    return null;
  }

  /// 기기 언어 기반 초기값 — 첫 실행(저장된 선택 없음)에만 쓴다.
  /// 한국어면 ko, 지원 언어면 그 언어, 그 외에는 en.
  static AppLang fromDevice() {
    final code = ui.PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    return fromCode(code) ?? AppLang.en;
  }
}
