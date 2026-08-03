import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/location_cache.dart';
import '../data/auth_repository.dart';
import '../data/food_log_repository.dart';
import '../data/models/comment.dart';
import '../data/models/food_log.dart';
import '../data/models/product.dart';
import '../data/models/product_price.dart';
import '../data/price_repository.dart';
import '../data/models/store_review.dart';
import '../data/product_repository.dart';
import '../data/social_repository.dart';
import '../data/store_repository.dart';
import '../domain/interpretation.dart';
import '../features/chat/chat_service.dart';

final supabaseProvider =
    Provider<SupabaseClient>((ref) => Supabase.instance.client);

final repositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(ref.watch(supabaseProvider)),
);

final priceRepositoryProvider = Provider<PriceRepository>(
  (ref) => PriceRepository(ref.watch(supabaseProvider)),
);

typedef PriceLookup = ({String? productId, String? catalogProductKey});

final productPricesProvider =
    FutureProvider.family<List<ProductPrice>, PriceLookup>((ref, lookup) {
  return ref.watch(priceRepositoryProvider).forProduct(
        productId: lookup.productId,
        catalogProductKey: lookup.catalogProductKey,
      );
});

final hotDealsProvider = FutureProvider<List<HotDealItem>>((ref) {
  return ref.watch(priceRepositoryProvider).hotDeals();
});

/// AI 채팅 서비스 (Edge Function 'chat' 호출)
final chatServiceProvider = Provider<ChatService>(
  (ref) => ChatService(ref.watch(supabaseProvider)),
);

final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => SocialRepository(ref.watch(supabaseProvider)),
);

/// 저당맵 매장 데이터 접근
final storeRepositoryProvider = Provider<StoreRepository>(
  (ref) => StoreRepository(ref.watch(supabaseProvider)),
);

/// 저당맵: 권한 허용 후 확보한 사용자 현재 위치(없으면 null).
/// 지도 중심·거리 계산의 기준점으로 사용.
final userLocationProvider = StateProvider<LatLng?>((ref) => null);

/// 매장별 리뷰 목록 (리뷰 작성/수정 후 invalidate 로 갱신).
final storeReviewsProvider =
    FutureProvider.family<List<StoreReview>, String>((ref, storeId) async {
  return ref.watch(storeRepositoryProvider).reviews(storeId);
});

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

/// 먹은 기록 데이터 접근
final foodLogRepositoryProvider = Provider<FoodLogRepository>(
  (ref) => FoodLogRepository(ref.watch(supabaseProvider)),
);

/// 월별 먹은 기록 (달력). 키는 (year, month) 레코드 — 정규화를 타입으로 강제.
final monthLogsProvider =
    FutureProvider.family<List<FoodLog>, ({int year, int month})>(
        (ref, key) async {
  ref.watch(authStateProvider); // 로그인/로그아웃 시 갱신
  return ref
      .watch(foodLogRepositoryProvider)
      .logsForMonth(DateTime(key.year, key.month, 1));
});

/// 오늘 이 제품을 기록했는지 (결과 화면 토글 버튼 상태)
final todayLogProvider =
    FutureProvider.family<FoodLog?, ({String? productId, String name})>(
        (ref, key) async {
  ref.watch(authStateProvider);
  return ref
      .watch(foodLogRepositoryProvider)
      .todayLogFor(productId: key.productId, name: key.name);
});
