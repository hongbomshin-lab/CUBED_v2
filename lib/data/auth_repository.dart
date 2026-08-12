import 'dart:convert' show utf8;

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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

  /// Apple 로그인 (iOS 네이티브 시트). App Store 심사 4.8 대응 —
  /// 서드파티 소셜 로그인(카카오)을 제공하면 Apple 로그인도 필수.
  /// 네이티브 시트에서 받은 identityToken을 Supabase에 넘겨 세션을 수립한다
  /// (딥링크 복귀 불필요). nonce는 리플레이 공격 방지용.
  Future<AuthResponse> signInWithApple() async {
    final rawNonce = _db.auth.generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple 로그인에서 ID 토큰을 받지 못했습니다.');
    }

    return _db.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
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

  /// 회원 탈퇴. Edge Function(delete-account)이 본인 JWT를 검증한 뒤 service role로
  /// auth 사용자를 삭제한다(사용자 데이터는 FK CASCADE로 자동 정리).
  /// 삭제 후 로컬 세션도 정리한다. 실패 시 예외를 던진다.
  Future<void> deleteAccount() async {
    final res = await _db.functions.invoke('delete-account');
    if (res.status != 200) {
      final message = switch (res.data) {
        {'error': final String msg} => msg,
        _ => '계정 삭제에 실패했습니다. 잠시 후 다시 시도해주세요.',
      };
      throw Exception(message);
    }
    // 서버에서 사용자가 이미 삭제되어 signOut이 401로 실패할 수 있으므로 로컬만 정리.
    await _db.auth.signOut(scope: SignOutScope.local);
  }

  /// 표시용 닉네임 (가입 시 저장한 메타데이터에서 추출)
  String displayName() {
    final m = currentUser?.userMetadata ?? const {};
    final name = (m['name'] ?? m['nickname'] ?? m['full_name']);
    if (name is String && name.trim().isNotEmpty) return name.trim();
    return '회원';
  }
}
