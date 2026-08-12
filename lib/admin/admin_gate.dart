import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import 'admin_providers.dart';
import 'submission_queue_screen.dart';
import 'product_browser_screen.dart';

class AdminGate extends ConsumerWidget {
  const AdminGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(adminEmailProvider);
    if (email == null) return const _LoginScreen();
    return const AdminHome();
  }
}

class _LoginScreen extends ConsumerStatefulWidget {
  const _LoginScreen();
  @override
  ConsumerState<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<_LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  String? _err; bool _busy = false;

  Future<void> _login() async {
    setState(() { _busy = true; _err = null; });
    try {
      await ref.read(adminSupabaseProvider).auth.signInWithPassword(
        email: _email.text.trim(), password: _pw.text);
    } on AuthException catch (e) {
      setState(() => _err = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('ZERO DOT 관리자', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              TextField(controller: _email, decoration: const InputDecoration(labelText: '이메일')),
              const SizedBox(height: 12),
              TextField(controller: _pw, obscureText: true, decoration: const InputDecoration(labelText: '비밀번호')),
              if (_err != null) Padding(padding: const EdgeInsets.only(top: 12),
                child: Text(_err!, style: const TextStyle(color: CubedColors.caution))),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: CubedColors.brand, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _busy ? null : _login,
                child: Text(_busy ? '로그인 중…' : '로그인'))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 탭 2개(제보 큐 / 제품 브라우저).
class AdminHome extends ConsumerWidget {
  const AdminHome({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ZERO DOT 검수 콘솔'),
          bottom: const TabBar(tabs: [Tab(text: '제보 큐'), Tab(text: '제품')]),
          actions: [
            TextButton(onPressed: () => ref.read(adminSupabaseProvider).auth.signOut(),
              child: const Text('로그아웃')),
          ],
        ),
        body: const TabBarView(children: [SubmissionQueueScreen(), ProductBrowserScreen()]),
      ),
    );
  }
}
