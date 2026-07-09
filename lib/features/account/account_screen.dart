import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../auth/login_screen.dart';
import 'my_reviews_screen.dart';

/// 마이페이지 — 프로필 + 즐겨찾기/내 리뷰 진입 + 로그아웃.
/// 비로그인 시 로그인 유도 화면.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      backgroundColor: CubedColors.bg,
      appBar: AppBar(title: const Text('마이페이지')),
      body: user == null
          ? const _LoggedOut()
          : _LoggedIn(),
    );
  }
}

/// 비로그인 상태 — 로그인 버튼.
class _LoggedOut extends StatelessWidget {
  const _LoggedOut();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_circle_outlined,
                size: 64, color: CubedColors.inkSoft),
            const SizedBox(height: 16),
            const Text('로그인하고 즐겨찾기·리뷰를 관리하세요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: CubedColors.inkSoft)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: CubedColors.brand,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text('로그인 / 회원가입',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 로그인 상태 — 프로필 헤더 + 메뉴.
class _LoggedIn extends ConsumerWidget {
  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃',
                style: TextStyle(color: CubedColors.caution)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(authRepositoryProvider).signOut();
    if (context.mounted) _toast(context, '로그아웃 되었어요');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authRepositoryProvider);
    final user = ref.watch(currentUserProvider);
    final name = auth.displayName();
    final email = user?.email ?? '';
    final reviewCount = ref.watch(myReviewsProvider).valueOrNull?.length;

    return ListView(
      children: [
        // 프로필 헤더
        Container(
          color: CubedColors.surface,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: CubedColors.brand.withValues(alpha: 0.15),
              child: Text(
                name.characters.first,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: CubedColors.brand),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(email,
                        style: const TextStyle(
                            fontSize: 13, color: CubedColors.inkSoft)),
                  ],
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // 메뉴
        _MenuTile(
          icon: Icons.favorite_border_rounded,
          label: '매장 즐겨찾기',
          trailing: '준비 중',
          onTap: () => _toast(context, '즐겨찾기는 곧 제공됩니다'),
        ),
        _MenuTile(
          icon: Icons.rate_review_outlined,
          label: '작성한 리뷰',
          trailing: reviewCount == null ? null : '$reviewCount',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MyReviewsScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _MenuTile(
          icon: Icons.logout_rounded,
          label: '로그아웃',
          danger: true,
          onTap: () => _confirmSignOut(context, ref),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? CubedColors.caution : CubedColors.ink;
    return Material(
      color: CubedColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(children: [
            Icon(icon, size: 22, color: danger ? CubedColors.caution : CubedColors.inkSoft),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ),
            if (trailing != null)
              Text(trailing!,
                  style: const TextStyle(
                      fontSize: 13, color: CubedColors.inkSoft)),
            if (!danger) ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: CubedColors.inkSoft),
            ],
          ]),
        ),
      ),
    );
  }
}
