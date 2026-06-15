import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/providers.dart';

/// 로그인/회원가입 화면 — 카카오 또는 이메일.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _register = false; // false=로그인, true=회원가입
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _nick = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    _nick.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    final email = _email.text.trim();
    final pw = _pw.text;
    final nick = _nick.text.trim();
    if (email.isEmpty || pw.isEmpty || (_register && nick.isEmpty)) {
      setState(() => _error = '모든 항목을 입력해주세요');
      return;
    }
    if (pw.length < 6) {
      setState(() => _error = '비밀번호는 6자 이상이어야 해요');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authRepositoryProvider);
      if (_register) {
        final res = await auth.signUpWithEmail(email: email, password: pw, nickname: nick);
        if (res.session == null && mounted) {
          // 이메일 확인이 켜져 있는 경우
          setState(() {
            _busy = false;
            _error = '가입 확인 메일을 보냈어요. 메일의 링크를 눌러 인증 후 로그인해주세요.';
            _register = false;
          });
          return;
        }
      } else {
        await auth.signInWithEmail(email: email, password: pw);
      }
      // 성공 → authState 리스너가 pop
    } catch (e) {
      final msg = e.toString();
      setState(() {
        _busy = false;
        _error = msg.contains('Invalid login')
            ? '이메일 또는 비밀번호가 올바르지 않아요'
            : msg.contains('already registered')
                ? '이미 가입된 이메일이에요'
                : '오류: $msg';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 로그인 성공 시 자동으로 닫기
    ref.listen(currentUserProvider, (prev, next) {
      if (next != null && mounted) Navigator.of(context).pop(true);
    });

    return Scaffold(
      appBar: AppBar(title: Text(_register ? '회원가입' : '로그인')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          const SizedBox(height: 8),
          const Text('CUBED',
              style: TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w900, color: CubedColors.brand, letterSpacing: -1)),
          const SizedBox(height: 6),
          const Text('로그인하고 좋아요·코멘트를 남겨보세요',
              style: TextStyle(color: CubedColors.inkSoft, fontSize: 14)),
          const SizedBox(height: 28),

          if (_register) ...[
            _field(_nick, '닉네임', Icons.badge_outlined),
            const SizedBox(height: 12),
          ],
          _field(_email, '이메일', Icons.mail_outline_rounded, keyboard: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _field(_pw, '비밀번호 (6자 이상)', Icons.lock_outline_rounded, obscure: true),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CubedColors.caution.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_error!, style: const TextStyle(color: CubedColors.caution, fontSize: 13)),
            ),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: CubedColors.brand,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: _busy ? null : _submitEmail,
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_register ? '회원가입' : '로그인',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => setState(() { _register = !_register; _error = null; }),
              child: Text(_register ? '이미 계정이 있어요 — 로그인' : '계정이 없어요 — 회원가입',
                  style: const TextStyle(color: CubedColors.inkSoft, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon,
      {bool obscure = false, TextInputType? keyboard}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: CubedColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: CubedColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: CubedColors.line),
        ),
      ),
    );
  }
}
