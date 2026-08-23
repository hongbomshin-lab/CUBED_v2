import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/feature_flags.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../auth/login_screen.dart';
import '../capture/capture_screen.dart';
import '../chat/chat_screen.dart';
import '../diary/diary_screen.dart';
import '../scan/scan_screen.dart';
import '../search/search_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 기준 데이터 프리로드(앱 시작 시 캐시)
    final refData = ref.watch(referenceProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Reveal(
              child: Row(
                children: [
                  const _Wordmark(),
                  const Spacer(),
                  refData.when(
                    data: (_) => const _DataBadge(ok: true),
                    loading: () => const _DataBadge(ok: null),
                    error: (_, __) => const _DataBadge(ok: false),
                  ),
                  const SizedBox(width: 8),
                  const _AccountChip(),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Reveal(
              delayMs: 40,
              child: Text('제로·저당, 진짜인지\n3초 만에 확인',
                  style: Theme.of(context).textTheme.headlineMedium),
            ),
            const SizedBox(height: 8),
            const Reveal(
              delayMs: 60,
              child: Text('라벨 뒤에 숨은 당알코올 함정까지 읽어드려요',
                  style: TextStyle(color: CubedColors.inkSoft, fontSize: 14.5)),
            ),
            const SizedBox(height: 24),

            // 바코드 스캔 (FeatureFlags.barcodeScan 으로 노출 제어)
            if (FeatureFlags.barcodeScan) ...[
              Reveal(
                delayMs: 80,
                child: _HeroCard(
                  chipLabel: '바코드 스캔',
                  title: '바코드를 비추면 끝',
                  subtitle: '제품 바코드로 혈당 영향·함정을 바로 분석해요',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ScanScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 메인 CTA — 사진 촬영 → 분석 (등록 제품은 1장, 미등록만 3장)
            Reveal(
              delayMs: 90,
              child: _HeroCard(
                chipLabel: 'AI 사진 분석',
                title: '사진 찍고 3초',
                subtitle: '앞면 한 장이면 끝 — 미등록 제품만 3장 촬영',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CaptureScreen()),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Reveal(
              delayMs: 130,
              child: Row(
                children: [
                  Expanded(
                    child: _MiniCard(
                      icon: Icons.search_rounded,
                      iconColor: CubedColors.brandDeep,
                      title: '이름으로 검색',
                      subtitle: '408개 제품',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniCard(
                      icon: Icons.forum_rounded,
                      iconColor: CubedColors.brand,
                      title: 'AI에게 묻기',
                      subtitle: '혈당·당류 무엇이든',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ChatScreen()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Reveal(
              delayMs: 170,
              child: _WideCard(
                icon: Icons.calendar_month_rounded,
                title: '내가 먹은 기록',
                subtitle: '날짜별로 먹은 제품을 돌아봐요',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DiaryScreen()),
                ),
              ),
            ),

            const SizedBox(height: 30),
            const Reveal(
              delayMs: 210,
              child: Text('이렇게 도와드려요',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      letterSpacing: -0.4)),
            ),
            const SizedBox(height: 14),
            const Reveal(
              delayMs: 240,
              child: Column(children: [
                _HelpTile(
                  icon: Icons.report_gmailerrorred_rounded,
                  color: CubedColors.caution,
                  text: '‘무설탕’인데 혈당 올리는 당알코올 함정을 잡아내요',
                ),
                _HelpTile(
                  icon: Icons.auto_awesome_rounded,
                  color: CubedColors.brand,
                  text: '대체당 조합에 맞춘 맞춤 메시지를 보여줘요',
                ),
                _HelpTile(
                  icon: Icons.swap_horiz_rounded,
                  color: CubedColors.mid,
                  text: '주의 제품엔 같은 칸의 더 나은 대안을 추천해요',
                ),
              ]),
            ),

            // 스토어 정책: 건강 정보 면책 + 개인정보처리방침 링크
            const SizedBox(height: 28),
            const Text(
              'ZERO DOT의 혈당 영향 등급과 AI 답변은 참고용 정보이며 의학적 조언이 아닙니다. '
              '질환이 있는 경우 전문가와 상담하세요.',
              style: TextStyle(
                  color: CubedColors.inkSoft, fontSize: 11, height: 1.5),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => launchUrl(Uri.parse(kPrivacyPolicyUrl),
                    mode: LaunchMode.externalApplication),
                child: const Text('개인정보처리방침',
                    style: TextStyle(
                        color: CubedColors.inkSoft,
                        fontSize: 11,
                        decoration: TextDecoration.underline)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 개인정보처리방침 공개 URL (docs/privacy-policy.md → GitHub Pages 호스팅).
/// 스토어 등록 시 Play Console·App Store Connect에도 동일 URL을 입력한다.
const kPrivacyPolicyUrl =
    'https://hongbomshin-lab.github.io/CUBED_v2/privacy-policy';

/// "ZERO DOT" 워드마크 — 브랜드 도트(●)가 시그니처.
class _Wordmark extends StatelessWidget {
  const _Wordmark();
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('ZERO DOT',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: CubedColors.ink,
            )),
        const SizedBox(width: 4),
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(
            color: CubedColors.brand,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

class _AccountChip extends ConsumerWidget {
  const _AccountChip();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authStateProvider);
    final auth = ref.read(authRepositoryProvider);
    final loggedIn = auth.isLoggedIn;

    Future<void> onTap() async {
      if (loggedIn) {
        await showModalBottomSheet(
          context: context,
          builder: (_) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 12),
              ListTile(
                leading:
                    const Icon(Icons.person_rounded, color: CubedColors.brand),
                title: Text(auth.displayName(),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('카카오 로그인됨'),
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('로그아웃'),
                onTap: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              // 스토어 정책상 앱 내 계정 삭제 필수 (Apple 5.1.1(v)·Google Play)
              ListTile(
                leading: const Icon(Icons.person_off_rounded,
                    color: CubedColors.caution),
                title: const Text('회원 탈퇴',
                    style: TextStyle(color: CubedColors.caution)),
                onTap: () => _confirmDeleteAccount(context, ref),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        );
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: CubedColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: CubedColors.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(loggedIn ? Icons.person_rounded : Icons.login_rounded,
              size: 14,
              color: loggedIn ? CubedColors.brandDeep : CubedColors.inkSoft),
          const SizedBox(width: 4),
          Text(loggedIn ? auth.displayName() : '로그인',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color:
                      loggedIn ? CubedColors.brandDeep : CubedColors.inkSoft)),
        ]),
      ),
    );
  }
}

/// 회원 탈퇴 확인 → Edge Function 호출 → 계정·데이터 삭제.
Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('회원 탈퇴'),
      content:
          const Text('계정과 함께 먹은 기록·좋아요 등 모든 데이터가 삭제되며 되돌릴 수 없어요.\n정말 탈퇴하시겠어요?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child:
              const Text('탈퇴하기', style: TextStyle(color: CubedColors.caution)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    await ref.read(authRepositoryProvider).deleteAccount();
    if (context.mounted) navigator.pop(); // 계정 시트 닫기
    messenger.showSnackBar(
      const SnackBar(content: Text('탈퇴가 완료되었습니다. 그동안 이용해주셔서 감사합니다.')),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('탈퇴 처리에 실패했어요: $e')),
    );
  }
}

class _DataBadge extends StatelessWidget {
  const _DataBadge({required this.ok});
  final bool? ok;
  @override
  Widget build(BuildContext context) {
    final (c, t) = switch (ok) {
      true => (CubedColors.low, 'DB 연결됨'),
      false => (CubedColors.caution, 'DB 오류'),
      _ => (CubedColors.inkSoft, '연결 중'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(t,
            style:
                TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// 다크 잉크 히어로 카드 — 라임 도트 그리드 + 라임 액션 버튼.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.chipLabel,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String chipLabel, title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CubedFx.radiusHero),
        boxShadow: CubedFx.shadowLift,
      ),
      child: Material(
        color: CubedColors.inkCard,
        borderRadius: BorderRadius.circular(CubedFx.radiusHero),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _DotGridPainter()),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: CubedColors.lime,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(chipLabel,
                              style: const TextStyle(
                                  color: CubedColors.ink,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800)),
                        ),
                        const Spacer(),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: CubedColors.lime,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_forward_rounded,
                              color: CubedColors.ink, size: 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 6),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 13.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 히어로 카드 배경 — 은은한 라임 도트 그리드 (ZERO DOT 모티프).
class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = CubedColors.lime.withValues(alpha: 0.09);
    for (double y = 12; y < size.height; y += 20) {
      for (double x = 12; x < size.width; x += 20) {
        canvas.drawCircle(Offset(x, y), 1.4, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CubedFx.radiusCard),
        boxShadow: CubedFx.shadowCard,
      ),
      child: Material(
        color: CubedColors.surface,
        borderRadius: BorderRadius.circular(CubedFx.radiusCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(height: 14),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: -0.2)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        color: CubedColors.inkSoft, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WideCard extends StatelessWidget {
  const _WideCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CubedFx.radiusCard),
        boxShadow: CubedFx.shadowCard,
      ),
      child: Material(
        color: CubedColors.surface,
        borderRadius: BorderRadius.circular(CubedFx.radiusCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: CubedColors.brandDeep.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: CubedColors.brandDeep, size: 23),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: -0.2)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: const TextStyle(
                              color: CubedColors.inkSoft, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: CubedColors.inkSoft, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  const _HelpTile({
    required this.icon,
    required this.color,
    required this.text,
  });
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(text,
                  style: const TextStyle(fontSize: 14, height: 1.45)),
            ),
          ),
        ],
      ),
    );
  }
}
