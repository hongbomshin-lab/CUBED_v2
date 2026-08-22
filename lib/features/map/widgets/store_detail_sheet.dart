import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/location_cache.dart';
import '../../../core/i18n/app_lang.dart';
import '../../../core/i18n/ui_strings.dart';
import '../../../core/theme.dart';
import '../../../data/models/store.dart';
import '../../../data/models/store_menu.dart';
import '../../../data/translation_repository.dart';
import '../../../data/models/store_review.dart';
import '../../../providers/providers.dart';
import '../../auth/login_screen.dart';
import '../../report/menu_board_report_sheet.dart';
import '../../review/review_sheet.dart';

/// 매장 상세 바텀시트를 표준 스타일로 띄운다. (지도 마커·즐겨찾기 목록 공용)
Future<void> showStoreDetailSheet(BuildContext context, Store store) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: CubedColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => StoreDetailSheet(store: store),
  );
}

/// 마커 탭 시 표시하는 매장 상세 바텀시트.
class StoreDetailSheet extends ConsumerStatefulWidget {
  const StoreDetailSheet({super.key, required this.store});
  final Store store;

  @override
  ConsumerState<StoreDetailSheet> createState() => _StoreDetailSheetState();
}

class _StoreDetailSheetState extends ConsumerState<StoreDetailSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  Store get s => widget.store;

  List<StorePhoto> get _gallery =>
      s.photos.where((p) => p.photoType != 'menu_board').toList();
  List<StorePhoto> get _menuBoards =>
      s.photos.where((p) => p.photoType == 'menu_board').toList();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 일반 웹 링크 열기 (네이버 플레이스 등).
  Future<void> _launchWeb(String url) async {
    final uri = Uri.parse(url);
    try {
      final ok =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _toast('링크를 열 수 없어요');
    } catch (_) {
      _toast('링크를 열 수 없어요');
    }
  }

  /// 전화 걸기 → 기기 전화앱(다이얼러)으로 연결.
  /// 다이얼러 없는 기기(태블릿/에뮬레이터)면 번호 복사 안내.
  Future<void> _launchPhone(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: digits);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _toast('이 기기에서 전화를 걸 수 없어요 ($phone)');
      }
    } catch (_) {
      _toast('전화 연결에 실패했어요 ($phone)');
    }
  }

  /// 인스타그램 열기:
  /// 1) 인스타 앱 설치 시 앱으로(instagram://user?username=핸들)
  /// 2) 미설치 시 웹(https://instagram.com/핸들)
  /// 3) 핸들 추출 실패 등 코너케이스는 원본 URL 웹으로 폴백.
  Future<void> _launchInstagram(String url) async {
    final handle = _instagramHandle(url);
    if (handle == null) {
      await _launchWeb(url);
      return;
    }
    final appUri = Uri.parse('instagram://user?username=$handle');
    final webUri = Uri.parse('https://instagram.com/$handle');
    try {
      if (await canLaunchUrl(appUri)) {
        final ok = await launchUrl(appUri);
        if (ok) return;
      }
    } catch (_) {
      // 앱 실행 실패 → 웹 폴백
    }
    try {
      final ok =
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
      if (!ok) _toast('인스타그램을 열 수 없어요');
    } catch (_) {
      _toast('인스타그램을 열 수 없어요');
    }
  }

  /// instagram.com URL 또는 핸들 문자열에서 핸들만 추출.
  String? _instagramHandle(String url) {
    final m = RegExp(r'instagram\.com/([A-Za-z0-9_.]+)').firstMatch(url);
    if (m != null) return m.group(1)!.replaceAll(RegExp(r'\.+$'), '');
    // URL이 아니라 핸들만 저장된 경우
    final bare = url.trim().replaceAll('@', '');
    if (RegExp(r'^[A-Za-z0-9_.]+$').hasMatch(bare)) return bare;
    return null;
  }

  Future<void> _toggleFavorite(bool currentlyFav) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    final repo = ref.read(storeRepositoryProvider);
    try {
      if (currentlyFav) {
        await repo.removeFavorite(user.id, s.id);
      } else {
        await repo.addFavorite(user.id, s.id);
      }
      ref.invalidate(favoriteIdsProvider);
      ref.invalidate(favoriteStoresProvider);
    } catch (_) {
      _toast('즐겨찾기 처리에 실패했어요');
    }
  }

  Future<void> _onWriteReview() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CubedColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ReviewSheet(storeId: s.id, storeName: s.name),
    );
    // 리뷰 제출 후 바텀시트는 유지 (Step 5에서 카운트 실시간 반영 고려)
  }

  Future<void> _onReportMenuBoard() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CubedColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MenuBoardReportSheet(storeId: s.id, storeName: s.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = s.primaryPhoto;
    final userLoc = ref.watch(userLocationProvider);
    final distance = userLoc != null
        ? LocationService.formatDistance(userLoc, LatLng(s.lat, s.lng))
        : null;

    final menuLang = ref.watch(menuLangProvider);

    // 리뷰 목록(실시간) — 작성/수정 후 카운트·목록 즉시 반영.
    final reviewsAsync = ref.watch(storeReviewsProvider(s.id));
    final liveReviews = reviewsAsync.valueOrNull;
    final reviewCount = liveReviews?.length ?? s.reviewCount;
    final recommendCount = liveReviews != null
        ? liveReviews.where((r) => r.isRecommended).length
        : s.recommendCount;
    final rate =
        reviewCount == 0 ? null : ((recommendCount / reviewCount) * 100).round();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scroll) => Column(
        children: [
          // 드래그 핸들
          const _Handle(),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: EdgeInsets.zero,
              children: [
                // 대표 사진
                if (primary != null)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: primary.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: CubedColors.line),
                      errorWidget: (_, __, ___) => Container(color: CubedColors.line),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 매장명 + 유형 뱃지 + 즐겨찾기
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(ref.watch(dictProvider).store(s.name),
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(width: 8),
                          _TypeBadge(type: s.type, lang: menuLang),
                          const SizedBox(width: 4),
                          _FavoriteButton(
                            isFavorite: ref
                                    .watch(favoriteIdsProvider)
                                    .valueOrNull
                                    ?.contains(s.id) ??
                                false,
                            onTap: _toggleFavorite,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 추천율 + 리뷰 수 + 현재 위치 기준 거리
                      Row(children: [
                        const Icon(Icons.thumb_up_rounded,
                            size: 15, color: CubedColors.brand),
                        const SizedBox(width: 4),
                        Text(
                          rate != null
                              ? uiText('reviewSummary', menuLang)
                                  .replaceFirst('{rate}', '$rate')
                                  .replaceFirst('{n}', '$reviewCount')
                              : uiText('noReview', menuLang),
                          style: const TextStyle(
                              fontSize: 13, color: CubedColors.inkSoft),
                        ),
                        if (distance != null) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.near_me_rounded,
                              size: 14, color: CubedColors.brand),
                          const SizedBox(width: 3),
                          Text(
                            distance,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: CubedColors.brand),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 12),

                      // 주소
                      _InfoRow(
                          icon: Icons.location_on_rounded, text: s.address),
                      if (s.phone != null)
                        _InfoRow(
                          icon: Icons.phone_rounded,
                          text: s.phone!,
                          onTap: () => _launchPhone(s.phone!),
                        ),
                      if (s.hours != null)
                        _InfoRow(
                            icon: Icons.access_time_rounded, text: s.hours!),

                      // 외부 링크 버튼
                      if (s.instagramUrl != null || s.naverPlaceUrl != null) ...[
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, children: [
                          if (s.naverPlaceUrl != null)
                            _LinkButton(
                              label: '네이버 플레이스',
                              icon: Icons.map_outlined,
                              color: const Color(0xFF03C75A),
                              onTap: () => _launchWeb(s.naverPlaceUrl!),
                            ),
                          if (s.instagramUrl != null)
                            _LinkButton(
                              label: '인스타그램',
                              icon: Icons.camera_alt_outlined,
                              color: const Color(0xFFE1306C),
                              onTap: () => _launchInstagram(s.instagramUrl!),
                            ),
                        ]),
                      ],

                      const SizedBox(height: 16),
                      const Divider(color: CubedColors.line),

                      // 대표 메뉴 — 탭에 묻히지 않도록 탭 위에 둔다.
                      _MenuSection(storeId: s.id),
                    ],
                  ),
                ),

                // 사진·메뉴판 탭
                TabBar(
                  controller: _tabs,
                  labelColor: CubedColors.ink,
                  unselectedLabelColor: CubedColors.inkSoft,
                  indicatorColor: CubedColors.brand,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                  tabs: [
                    Tab(text: '사진 (${_gallery.length})'),
                    Tab(text: '메뉴판 (${_menuBoards.length})'),
                  ],
                ),
                SizedBox(
                  height: 200,
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _PhotoGrid(photos: _gallery),
                      _PhotoGrid(photos: _menuBoards),
                    ],
                  ),
                ),

                // 리뷰 목록
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(color: CubedColors.line),
                      const SizedBox(height: 4),
                      Text('리뷰 $reviewCount',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      reviewsAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (_, __) => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('리뷰를 불러오지 못했어요',
                              style: TextStyle(
                                  color: CubedColors.inkSoft, fontSize: 13)),
                        ),
                        data: (reviews) => reviews.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Text('아직 리뷰가 없어요. 첫 리뷰를 남겨보세요!',
                                    style: TextStyle(
                                        color: CubedColors.inkSoft,
                                        fontSize: 13)),
                              )
                            : Column(
                                children: [
                                  for (final r in reviews) _ReviewTile(review: r),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),

                // 액션 버튼
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      20, 16, 20, 32 + MediaQuery.viewPaddingOf(context).bottom),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _onReportMenuBoard,
                        icon: const Icon(Icons.camera_alt_rounded, size: 16),
                        label: const Text('메뉴판 제보'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CubedColors.inkSoft,
                          side: const BorderSide(color: CubedColors.line),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _onWriteReview,
                        icon: const Icon(Icons.rate_review_rounded, size: 16),
                        label: const Text('리뷰 쓰기'),
                        style: FilledButton.styleFrom(
                          backgroundColor: CubedColors.brand,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: CubedColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
}

/// 매장 대표 메뉴 — 저당 메뉴(당류 강조) + 시그니처 메뉴.
/// 자료가 없는 매장에서는 섹션 자체를 감춘다(빈 껍데기를 보여주지 않는다).
class _MenuSection extends ConsumerWidget {
  const _MenuSection({required this.storeId});
  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(storeMenusProvider(storeId));
    final menus = async.valueOrNull ?? const <StoreMenu>[];
    if (menus.isEmpty) return const SizedBox.shrink();
    final lang = ref.watch(menuLangProvider);
    final dict = ref.watch(dictProvider);

    final lowSugar = menus.where((m) => m.isLowSugar).toList();
    final signature = menus.where((m) => !m.isLowSugar).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Text(uiText('featuredMenu', lang),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (lowSugar.isNotEmpty) ...[
          _MenuGroupLabel(
            icon: Icons.eco_rounded,
            label: uiText('lowSugarMenu', lang),
            color: CubedColors.brand,
          ),
          for (final m in lowSugar)
            _MenuTile(menu: m, dict: dict, lang: lang),
        ],
        if (signature.isNotEmpty) ...[
          if (lowSugar.isNotEmpty) const SizedBox(height: 10),
          _MenuGroupLabel(
            icon: Icons.star_rounded,
            label: uiText('signatureMenu', lang),
            color: const Color(0xFFE0A100),
          ),
          for (final m in signature)
            _MenuTile(menu: m, dict: dict, lang: lang),
        ],
        const SizedBox(height: 14),
        const Divider(color: CubedColors.line),
      ],
    );
  }
}

class _MenuGroupLabel extends StatelessWidget {
  const _MenuGroupLabel({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.menu,
    required this.dict,
    required this.lang,
  });
  final StoreMenu menu;
  final TranslationDict dict;
  final AppLang lang;

  @override
  Widget build(BuildContext context) {
    // 보조 정보(칼로리·가격·기준량)는 있는 것만 이어 붙인다.
    final sub = <String>[
      if (menu.serving != null) menu.serving!,
      if (menu.calories != null) '${_fmt(menu.calories!)} kcal',
      if (menu.priceWon != null) '${_won(menu.priceWon!)}원',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(dict.storeMenu(menu.name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                  if (menu.isEstimated) ...[
                    const SizedBox(width: 6),
                    _TinyBadge(text: uiText('estimated', lang)),
                  ],
                ]),
                if (sub.isNotEmpty || menu.note != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      sub.join(' · '),
                      if (menu.note != null) dict.menuNote(menu.note!),
                    ]
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: CubedColors.inkSoft),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          // 당류 — 미공개면 수치 대신 안내 문구(추정값을 지어내지 않는다).
          if (menu.sugarUnknown)
            Text(uiText('sugarUnknown', lang),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: CubedColors.inkSoft))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${uiText('sugar', lang)} ',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _sugarColor(menu.sugarG!))),
                Text(_fmt(menu.sugarG!),
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        color: _sugarColor(menu.sugarG!))),
                Text('g',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _sugarColor(menu.sugarG!))),
              ],
            ),
        ],
      ),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  static String _won(int v) =>
      v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  /// 저당맵 기준과 같은 색 구간 (프랜차이즈 메뉴 카드와 일관).
  static Color _sugarColor(double g) {
    if (g <= 5) return CubedColors.brand;
    if (g <= 15) return const Color(0xFFE0A100);
    return const Color(0xFFD9534F);
  }
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: CubedColors.bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: CubedColors.line),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: CubedColors.inkSoft)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tappable = onTap != null;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 15, color: tappable ? CubedColors.brand : CubedColors.inkSoft),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: tappable ? CubedColors.brand : CubedColors.inkSoft,
                  fontWeight: tappable ? FontWeight.w700 : FontWeight.w400)),
        ),
        if (tappable)
          const Icon(Icons.chevron_right_rounded,
              size: 16, color: CubedColors.brand),
      ]),
    );
    if (!tappable) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      );
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final StoreReview review;

  String _relativeDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()}년 전';
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}개월 전';
    if (diff.inDays >= 1) return '${diff.inDays}일 전';
    if (diff.inHours >= 1) return '${diff.inHours}시간 전';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}분 전';
    return '방금 전';
  }

  @override
  Widget build(BuildContext context) {
    final rec = review.isRecommended;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CubedColors.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(rec ? Icons.thumb_up_rounded : Icons.thumb_down_rounded,
                size: 14,
                color: rec ? CubedColors.brand : CubedColors.inkSoft),
            const SizedBox(width: 5),
            Text(rec ? '추천' : '비추천',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: rec ? CubedColors.brand : CubedColors.inkSoft)),
            const Spacer(),
            Text(_relativeDate(review.createdAt),
                style: const TextStyle(
                    fontSize: 11, color: CubedColors.inkSoft)),
          ]),
          if (review.content != null) ...[
            const SizedBox(height: 8),
            Text(review.content!,
                style: const TextStyle(
                    fontSize: 13, height: 1.45, color: CubedColors.ink)),
          ],
        ],
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.isFavorite, required this.onTap});
  final bool isFavorite;
  final ValueChanged<bool> onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        onPressed: () => onTap(isFavorite),
        icon: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isFavorite ? CubedColors.caution : CubedColors.inkSoft,
          size: 24,
        ),
        tooltip: isFavorite ? '즐겨찾기 해제' : '즐겨찾기',
      );
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type, required this.lang});
  final StoreType type;
  final AppLang lang;

  /// StoreType.label 은 한국어 고정이라 표시 언어로 갈아끼운다.
  static const _typeKeys = {
    StoreType.cafe: 'typeCafe',
    StoreType.restaurant: 'typeRestaurant',
    StoreType.zeroStore: 'typeZeroStore',
    StoreType.delivery: 'typeDelivery',
  };
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: type.markerColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(uiText(_typeKeys[type]!, lang),
            style: TextStyle(
                color: type.markerColor,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      );
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos});
  final List<StorePhoto> photos;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const Center(
        child: Text('사진이 없어요',
            style: TextStyle(color: CubedColors.inkSoft, fontSize: 13)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      scrollDirection: Axis.horizontal,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: photos.length,
      itemBuilder: (_, i) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: photos[i].imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: CubedColors.line),
          errorWidget: (_, __, ___) => Container(color: CubedColors.line),
        ),
      ),
    );
  }
}
