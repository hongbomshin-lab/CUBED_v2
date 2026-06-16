import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

/// 카카오 OAuth로 돌아올 앱 딥링크. Supabase Auth의 Redirect URLs 허용목록에도
/// 동일하게 등록해야 한다(Authentication → URL Configuration → Redirect URLs).
const kakaoRedirect = 'cubed://login-callback';

/// 이메일/비밀번호/닉네임 직접 가입·로그인 + 카카오 OAuth.
class AuthRepository {
  AuthRepository(this._db);
  final SupabaseClient _db;

  User? get currentUser => _db.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  /// 카카오 로그인. 외부 브라우저/카카오앱으로 OAuth를 띄우고, 완료 시
  /// 딥링크(kakaoRedirect)로 복귀하면 supabase_flutter가 세션을 자동 수립한다
  /// (onAuthStateChange → authStateProvider가 UI 갱신).
  /// 웹에서는 redirectTo 없이 현재 origin으로 돌아온다.
  Future<bool> signInWithKakao() {
    return _db.auth.signInWithOAuth(
      OAuthProvider.kakao,
      redirectTo: kIsWeb ? null : kakaoRedirect,
    );
  }

  /// 회원가입 (이메일=아이디, 비밀번호, 닉네임). 이메일 확인이 꺼져 있으면 즉시 세션 수립.
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String nickname,
  }) {
    return _db.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'name': nickname.trim(), 'nickname': nickname.trim()},
    );
  }

  /// 로그인 (이메일, 비밀번호)
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _db.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<void> signOut() => _db.auth.signOut();

  /// 표시용 닉네임 (가입 시 저장한 메타데이터에서 추출)
  String displayName() {
    final m = currentUser?.userMetadata ?? const {};
    final name = (m['name'] ?? m['nickname'] ?? m['full_name']);
    if (name is String && name.trim().isNotEmpty) return name.trim();
    return '회원';
  }
}
