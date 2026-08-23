import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sugar_baselines.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../auth/login_screen.dart';
import 'favorite_stores_screen.dart';
import 'my_comments_screen.dart';
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
    final commentCount = ref.watch(myCommentsProvider).valueOrNull?.length;
    final favCount = ref.watch(favoriteStoresProvider).valueOrNull?.length;

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

        // 슈가포인트 히어로 카드
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _PointsCard(),
        ),
        const SizedBox(height: 12),

        // 메뉴
        _MenuTile(
          icon: Icons.favorite_border_rounded,
          label: '즐겨찾기 매장',
          trailing: favCount == null ? null : '$favCount',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FavoriteStoresScreen()),
          ),
        ),
        _MenuTile(
          icon: Icons.rate_review_outlined,
          label: '작성한 리뷰',
          trailing: reviewCount == null ? null : '$reviewCount',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MyReviewsScreen()),
          ),
        ),
        _MenuTile(
          icon: Icons.chat_bubble_outline_rounded,
          label: '작성한 댓글',
          trailing: commentCount == null ? null : '$commentCount',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MyCommentsScreen()),
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

/// 슈가포인트 — 다크 잉크 카드 위 라임 펀치 숫자.
/// 1P = 일반 제품 대비 아낀 설탕 1g. 각설탕(3g) 환산으로 체감시킨다.
class _PointsCard extends ConsumerWidget {
  const _PointsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myPointsProvider);
    final points = async.valueOrNull;
    final cubes = points == null ? null : sugarCubesFor(points);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        color: CubedColors.inkCard,
        borderRadius: BorderRadius.circular(CubedFx.radiusHero),
        boxShadow: CubedFx.shadowLift,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('슈가포인트',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: Colors.white70)),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: points == null ? '—' : '$points',
                        style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                            height: 1.1,
                            color: CubedColors.lime)),
                    const TextSpan(
                        text: ' P',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: CubedColors.lime)),
                  ]),
                ),
                const SizedBox(height: 6),
                Text(
                  async.hasError
                      ? '포인트를 불러오지 못했어요'
                      : points == null
                          ? '아낀 설탕을 계산하고 있어요'
                          : points == 0
                              ? '저당 제품을 기록하면 아낀 설탕만큼 쌓여요'
                              : '설탕 ${points}g 아꼈어요 · 각설탕 약 $cubes개',
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const _SugarCubeStack(),
        ],
      ),
    );
  }
}

/// 각설탕 스택 장식 — CUBED 아이덴티티의 미니 큐브 3개.
class _SugarCubeStack extends StatelessWidget {
  const _SugarCubeStack();

  Widget _cube(double size, double alpha, double angle) => Transform.rotate(
        angle: angle,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: CubedColors.lime.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(size * 0.28),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(right: 0, top: 2, child: _cube(26, 0.25, 0.35)),
          Positioned(left: 2, bottom: 0, child: _cube(20, 0.45, -0.25)),
          _cube(34, 1, 0.12),
        ],
      ),
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
