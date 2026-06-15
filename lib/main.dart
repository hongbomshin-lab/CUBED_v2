import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'core/theme.dart';
import 'features/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    // ignore: deprecated_member_use
    anonKey: Env.supabaseAnonKey,
  );
  // 인증은 이메일 로그인. 비로그인 사용자는 조회만 가능, 좋아요·코멘트는 로그인 후.
  runApp(const ProviderScope(child: CubedApp()));
}

class CubedApp extends StatelessWidget {
  const CubedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CUBED',
      debugShowCheckedModeBanner: false,
      theme: buildCubedTheme(),
      home: const HomeScreen(),
    );
  }
}
