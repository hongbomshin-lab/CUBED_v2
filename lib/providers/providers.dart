import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../data/models/comment.dart';
import '../data/models/product.dart';
import '../data/product_repository.dart';
import '../data/social_repository.dart';
import '../domain/interpretation.dart';
import '../features/chat/chat_service.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final repositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(ref.watch(supabaseProvider)),
);

/// AI 채팅 서비스 (Edge Function 'chat' 호출)
final chatServiceProvider = Provider<ChatService>(
  (ref) => ChatService(ref.watch(supabaseProvider)),
);

final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => SocialRepository(ref.watch(supabaseProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseProvider)),
);

/// 로그인 상태 스트림 (로그인/로그아웃 시 UI 갱신 + 소셜 데이터 무효화)
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseProvider);
  return client.auth.onAuthStateChange;
});

/// 현재 로그인 사용자 (없으면 null)
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider); // 인증 변화 시 재평가
  return ref.watch(supabaseProvider).auth.currentUser;
});

/// 제품 좋아요 상태 (수 + 내 좋아요)
final likeInfoProvider =
    FutureProvider.family<LikeInfo, String>((ref, productId) async {
  return ref.watch(socialRepositoryProvider).likeInfo(productId);
});

/// 제품 코멘트 목록
final commentsProvider =
    FutureProvider.family<List<Comment>, String>((ref, productId) async {
  return ref.watch(socialRepositoryProvider).comments(productId);
});

/// 앱 시작 시 1회 로드되는 기준 데이터(감미료·카테고리·조합규칙). 캐시됨.
final referenceProvider = FutureProvider<ReferenceData>(
  (ref) => ref.watch(repositoryProvider).loadReference(),
);

/// 바코드 → 제품 조회 결과
final lookupByBarcodeProvider =
    FutureProvider.family<Product?, String>((ref, barcode) async {
  return ref.watch(repositoryProvider).findByBarcode(barcode);
});

/// 제품 → 해석 결과 (기준 데이터 의존)
final interpretationProvider =
    FutureProvider.family<Interpretation, Product>((ref, product) async {
  final refData = await ref.watch(referenceProvider.future);
  return Interpretation.of(product, refData);
});

/// 제품 → 더 나은 대안 추천 (킬러 피처)
final alternativesProvider =
    FutureProvider.family<List<Interpretation>, Product>((ref, product) async {
  if (product.category == null) return const [];
  final refData = await ref.watch(referenceProvider.future);
  final repo = ref.watch(repositoryProvider);
  final current = Interpretation.of(product, refData);
  final cands = await repo.alternativesIn(product.category!, product.productId);
  return rankAlternatives(cands, refData, current.grade);
});

/// 이름 검색
final searchProvider =
    FutureProvider.family<List<Product>, String>((ref, q) async {
  if (q.trim().isEmpty) return const [];
  return ref.watch(repositoryProvider).searchByName(q.trim());
});
