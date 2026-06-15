import 'package:supabase_flutter/supabase_flutter.dart';

/// 이메일/비밀번호/닉네임 직접 가입·로그인.
class AuthRepository {
  AuthRepository(this._db);
  final SupabaseClient _db;

  User? get currentUser => _db.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

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
