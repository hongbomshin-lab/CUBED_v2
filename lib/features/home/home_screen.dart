import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../auth/login_screen.dart';
import '../chat/chat_screen.dart';
import '../ocr/ocr_screen.dart';
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
            Row(
              children: [
                Text('CUBED',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: CubedColors.brand,
                          letterSpacing: -0.5,
                        )),
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
            const SizedBox(height: 6),
            const Text('제로·저당, 진짜인지 3초 만에 확인',
                style: TextStyle(color: CubedColors.inkSoft, fontSize: 15)),
            const SizedBox(height: 24),

            // 메인 CTA — 바코드 스캔
            _BigAction(
              icon: Icons.qr_code_scanner_rounded,
              title: '바코드 스캔',
              subtitle: '제품 바코드를 비추면 혈당 영향·함정을 분석해요',
              color: CubedColors.brand,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ScanScreen()),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _SmallAction(
                    icon: Icons.center_focus_strong_rounded,
                    title: '사진으로 찾기',
                    subtitle: 'OCR 인식',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OcrScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SmallAction(
                    icon: Icons.search_rounded,
                    title: '이름으로 검색',
                    subtitle: '408개 제품',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // AI 도우미 진입 — 제품·혈당·당류를 대화로 질문
            _ChatAction(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              ),
            ),

            const SizedBox(height: 28),
            const Text('이렇게 도와드려요',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            const _Bullet('🔴', '‘무설탕’인데 혈당 올리는 당알코올 함정을 잡아내요'),
            const _Bullet('🟢', '대체당 조합에 맞춘 맞춤 메시지를 보여줘요'),
            const _Bullet('🔁', '주의 제품엔 같은 칸의 더 나은 대안을 추천해요'),
          ],
        ),
      ),
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
          backgroundColor: CubedColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.person_rounded, color: CubedColors.brand),
                title: Text(auth.displayName(), style: const TextStyle(fontWeight: FontWeight.w700)),
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: loggedIn ? CubedColors.brand.withValues(alpha: 0.1) : CubedColors.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CubedColors.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(loggedIn ? Icons.person_rounded : Icons.login_rounded,
              size: 14, color: loggedIn ? CubedColors.brand : CubedColors.inkSoft),
          const SizedBox(width: 4),
          Text(loggedIn ? auth.displayName() : '로그인',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: loggedIn ? CubedColors.brand : CubedColors.inkSoft)),
        ]),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(t, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.82)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: CubedColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CubedColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: CubedColors.brand, size: 26),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: CubedColors.inkSoft, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ChatAction extends StatelessWidget {
  const _ChatAction({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: CubedColors.brand.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CubedColors.brand.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CubedColors.brand.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.forum_rounded, color: CubedColors.brand, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI에게 물어보기',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  SizedBox(height: 2),
                  Text('제품·혈당·당류를 대화로 물어보세요',
                      style: TextStyle(color: CubedColors.inkSoft, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: CubedColors.brand, size: 14),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.emoji, this.text);
  final String emoji, text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4))),
        ],
      ),
    );
  }
}
