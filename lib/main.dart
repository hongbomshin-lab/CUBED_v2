import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'core/theme.dart';
import 'features/shell/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    // ignore: deprecated_member_use
    anonKey: Env.supabaseAnonKey,
  );
  // 저당맵: 네이버 지도 SDK 초기화. clientId가 비어 있으면 onAuthFailed로 떨어지지만 앱은 정상 구동.
  // 웹(프리뷰)에서는 SDK 미지원이라 건너뛴다.
  if (!kIsWeb) {
    await FlutterNaverMap().init(
      clientId: Env.naverMapClientId,
      onAuthFailed: (ex) => debugPrint('네이버맵 인증 실패: $ex'),
    );
  }
  // 인증은 이메일 로그인. 비로그인 사용자는 조회만 가능, 좋아요·코멘트는 로그인 후.
  runApp(const ProviderScope(child: CubedApp()));
}

class CubedApp extends StatelessWidget {
  const CubedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZERO DOT',
      debugShowCheckedModeBanner: false,
      theme: buildCubedTheme(),
      // 전역: 빈 곳을 탭하면 키보드/포커스 해제. TextField·버튼 등은 자식이
      // 탭을 먼저 가져가므로 영향 없고, 여백을 탭할 때만 포커스가 풀린다.
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const MainShell(),
    );
  }
}
