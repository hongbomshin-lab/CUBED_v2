import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/feature_flags.dart';
import '../../core/motion.dart';
import '../../core/sugar_cube.dart';
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
            const SizedBox(height: 26),

            // 헤드라인 — 문구는 그대로, 조판만 키운다
            const Reveal(
              delayMs: 40,
              child: Text('제로·저당, 진짜인지\n3초 만에 확인',
                  style: TextStyle(
                      color: CubedColors.ink,
                      fontSize: 29,
                      height: 1.24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.3)),
            ),
            const SizedBox(height: 9),
            const Reveal(
              delayMs: 60,
              child: Text('라벨 뒤에 숨은 당알코올 함정까지 읽어드려요',
                  style: TextStyle(color: CubedColors.inkSoft, fontSize: 14)),
            ),

            const SizedBox(height: 30),

            // 히어로 — 큐브가 면 밖으로 걸친다
            Reveal(
              delayMs: 90,
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CaptureScreen()),
                ),
                child: SizedBox(
                  height: 196,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: CubedColors.inkCard,
                            borderRadius:
                                BorderRadius.circular(CubedFx.radiusHero),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: const CubeScatter(),
                        ),
                      ),
                      // 큐브 더미가 카드 위로 튀어나온다
                      Positioned(
                        right: -12,
                        top: -18,
                        child: Transform.rotate(
                          angle: 0.14,
                          child: const SugarCubeStack(size: 88),
                        ),
                      ),
                      Positioned(
                        left: 22,
                        top: 24,
                        right: 110,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: CubedColors.lime,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Text('AI 사진 분석',
                                  style: TextStyle(
                                      color: CubedColors.inkCard,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.2)),
                            ),
                            const SizedBox(height: 26),
                            const Text('사진 찍고 3초',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 23,
                                    height: 1.24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.0)),
                            const SizedBox(height: 9),
                            const Text('앞면 한 장이면 끝 —\n미등록 제품만 3장 촬영',
                                style: TextStyle(
                                    color: Color(0xFF9FB6A8),
                                    fontSize: 12.5,
                                    height: 1.45)),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 20,
                        bottom: 18,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: CubedColors.lime,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_forward_rounded,
                              size: 21, color: CubedColors.inkCard),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // 기능 — 크기를 일부러 고르지 않게 둔다
            Reveal(
              delayMs: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _CubeTile(
                      glyph: CubeGlyph.find,
                      title: '이름으로 검색',
                      sub: '408개 제품',
                      tall: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        _CubeTile(
                          glyph: CubeGlyph.ask,
                          title: '물어보기',
                          sub: '',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ChatScreen()),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _CubeTile(
                          glyph: CubeGlyph.log,
                          title: '먹은 기록',
                          sub: '',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const DiaryScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 34),
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

/// 개인정보처리방침 공개 URL (Notion 공개 페이지 호스팅).
/// 스토어 등록 시 Play Console·App Store Connect에도 동일 URL을 입력한다.
const kPrivacyPolicyUrl =
    'https://atlantic-whale-582.notion.site/ZERO-DOT-3ba28df6a5b981808860f00eb355ab05';

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

/// 큐브 픽토그램이 붙은 기능 타일. 높이를 두 종류로 둔다.
class _CubeTile extends StatelessWidget {
  const _CubeTile({
    required this.glyph,
    required this.title,
    required this.sub,
    required this.onTap,
    this.tall = false,
  });
  final CubeGlyph glyph;
  final String title, sub;
  final VoidCallback onTap;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CubedFx.radiusCard),
      child: Container(
        height: tall ? 168 : 78,
        padding: const EdgeInsets.fromLTRB(16, 15, 14, 14),
        decoration: BoxDecoration(
          color: CubedColors.surface,
          borderRadius: BorderRadius.circular(CubedFx.radiusCard),
          boxShadow: CubedFx.shadowCard,
        ),
        child: tall
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CubeBadge(glyph: glyph, size: 48, tilt: -0.08),
                  const Spacer(),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6)),
                  if (sub.isNotEmpty)
                    Text(sub,
                        style: const TextStyle(
                            color: CubedColors.inkSoft, fontSize: 12.5)),
                ],
              )
            : Row(
                children: [
                  CubeBadge(glyph: glyph, size: 34, tilt: 0.07),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4)),
                  ),
                ],
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
