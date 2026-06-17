import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/product_repository.dart'; // ReferenceData.loadReference 재사용
import 'admin_service.dart';

final adminSupabaseProvider = Provider<SupabaseClient>((_) => Supabase.instance.client);
final adminServiceProvider = Provider<AdminService>((ref) => AdminService(ref.watch(adminSupabaseProvider)));

/// 기준데이터(감미료/카테고리/조합) — 앱과 동일 경로(anon read).
final adminReferenceProvider = FutureProvider<ReferenceData>(
  (ref) => ProductRepository(ref.watch(adminSupabaseProvider)).loadReference(),
);

final adminAuthStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(adminSupabaseProvider).auth.onAuthStateChange,
);

/// 현재 사용자 이메일(없으면 null). 게이트/표시는 서버가 최종 결정 — 여긴 UX용.
final adminEmailProvider = Provider<String?>((ref) {
  ref.watch(adminAuthStateProvider);
  return ref.watch(adminSupabaseProvider).auth.currentUser?.email;
});

final pendingSubmissionsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(adminServiceProvider).listSubmissions(status: 'pending'),
);
final productSearchProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, q) => ref.watch(adminServiceProvider).listProducts(q: q),
);
