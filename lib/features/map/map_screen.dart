import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location_cache.dart';
import '../../core/theme.dart';
import '../../data/models/store.dart';
import '../../providers/providers.dart';
import '../auth/login_screen.dart';
import '../franchise/franchise_browser.dart';
import '../report/store_report_sheet.dart';
import 'widgets/store_detail_sheet.dart';

/// 저당맵 화면 모드: 매장 지도 / 프랜차이즈 메뉴 당류.
enum _MapMode { store, menu }

/// 저당맵 — 네이버 지도 + store_type 필터 + 매장 마커.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  NaverMapController? _controller;

  final Set<StoreType> _selected = {};
  bool _fetching = false;
  Timer? _debounce;

  /// store_type 별 마커 아이콘 캐시 (위젯→이미지 변환은 비싸서 1회만)
  final Map<StoreType, NOverlayImage> _iconCache = {};

  // 검색 상태
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  List<Store> _searchResults = const [];
  bool _searchOpen = false;

  // 화면 모드 (지도 / 메뉴 당류)
  _MapMode _mode = _MapMode.store;

  // 위치 확인 불가 시 기본 중심 (LocationService.fallback 과 동일)
  static const _fallbackCenter = NLatLng(37.58045239, 126.9971964);

  @override
  void dispose() {
    _debounce?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// 검색어 입력 → 디바운스 후 이름 부분일치 검색.
  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _searchResults = const [];
        _searchOpen = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results =
            await ref.read(storeRepositoryProvider).searchByName(q);
        if (!mounted) return;
        setState(() {
          _searchResults = results;
          _searchOpen = true;
        });
      } catch (e) {
        debugPrint('검색 실패: $e');
      }
    });
  }

  void _clearSearch() {
    FocusScope.of(context).unfocus();
    _searchCtrl.clear();
    setState(() {
      _searchResults = const [];
      _searchOpen = false;
    });
  }

  /// 검색 결과 탭 → 해당 매장으로 카메라 이동 + 상세 시트 표시.
  Future<void> _onSearchResultTap(Store s) async {
    FocusScope.of(context).unfocus();
    setState(() => _searchOpen = false);
    final c = _controller;
    if (c != null) {
      await c.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(s.lat, s.lng),
          zoom: 16,
        ),
      );
    }
    if (!mounted) return;
    _onMarkerTap(s);
  }

  /// 위치 권한 요청 → 허용 시 사용자 위치로 카메라 이동 + provider 갱신.
  /// 거부/실패 시 서울 기본값 유지.
  Future<void> _moveToUserLocation() async {
    final loc = await LocationService.currentPosition();
    final c = _controller;
    if (!mounted || c == null || loc == null) return;
    ref.read(userLocationProvider.notifier).state = loc;
    await c.updateCamera(
      NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(loc.lat, loc.lng),
        zoom: 15,
      ),
    );
  }

  void _scheduleFetch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _fetchStores);
  }

  Future<void> _fetchStores() async {
    final c = _controller;
    if (c == null || _fetching) return;
    setState(() => _fetching = true);
    try {
      final bounds = await c.getContentBounds();
      final stores = await ref.read(storeRepositoryProvider).storesInBounds(
            south: bounds.southLatitude,
            north: bounds.northLatitude,
            west: bounds.westLongitude,
            east: bounds.eastLongitude,
            types: _selected,
          );
      if (!mounted) return;
      await _renderMarkers(c, stores);
    } catch (e) {
      debugPrint('매장 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  /// store_type별 커스텀 마커 아이콘(위젯 렌더링) — 캐시 활용.
  Future<NOverlayImage> _iconFor(StoreType type) async {
    final cached = _iconCache[type];
    if (cached != null) return cached;
    final img = await NOverlayImage.fromWidget(
      widget: _MarkerPin(color: type.markerColor, icon: type.icon),
      size: const Size(40, 48),
      context: context,
    );
    _iconCache[type] = img;
    return img;
  }

  Future<void> _renderMarkers(NaverMapController c, List<Store> stores) async {
    await c.clearOverlays(type: NOverlayType.marker);
    final markers = <NMarker>{};
    for (final s in stores) {
      final marker = NMarker(
        id: s.id,
        position: NLatLng(s.lat, s.lng),
        icon: await _iconFor(s.type),
        size: const Size(40, 48),
        caption: NOverlayCaption(
          text: s.name,
          textSize: 12,
          color: CubedColors.ink,
          haloColor: Colors.white,
        ),
      );
      marker.setOnTapListener((_) => _onMarkerTap(s));
      markers.add(marker);
    }
    if (!mounted) return;
    await c.addOverlayAll(markers);
  }

  Future<void> _onReportStore() async {
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
      builder: (_) => const StoreReportSheet(),
    );
  }

  void _onMarkerTap(Store s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CubedColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StoreDetailSheet(store: s),
    );
  }

  void _toggleFilter(StoreType? type) {
    setState(() {
      if (type == null) {
        _selected.clear();
      } else if (_selected.contains(type)) {
        _selected.remove(type);
      } else {
        _selected.add(type);
      }
    });
    _fetchStores();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 매장 제보 버튼은 지도 모드에서만.
      floatingActionButton: _mode == _MapMode.store
          ? FloatingActionButton.extended(
              heroTag: 'report',
              backgroundColor: CubedColors.brand,
              foregroundColor: Colors.white,
              onPressed: _onReportStore,
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text('매장 제보',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ModeToggle(
              mode: _mode,
              onChanged: (m) => setState(() => _mode = m),
            ),
            // IndexedStack으로 두 모드를 모두 살려두어 지도 상태(카메라·마커) 보존.
            Expanded(
              child: IndexedStack(
                index: _mode.index,
                children: [
                  _storeView(),
                  const FranchiseBrowser(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 매장 지도 모드 본문 (검색 + store_type 필터 + 지도).
  Widget _storeView() {
    return Column(
      children: [
        _SearchBar(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          onClear: _clearSearch,
        ),
        _FilterBar(selected: _selected, onTap: _toggleFilter),
        Expanded(
          child: Stack(
            children: [
              NaverMap(
                options: const NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target: _fallbackCenter,
                    zoom: 11,
                  ),
                  locale: Locale('ko'),
                  locationButtonEnable: true,
                ),
                onMapReady: (c) {
                  _controller = c;
                  _moveToUserLocation();
                  _fetchStores();
                },
                onCameraIdle: _scheduleFetch,
              ),
              if (_fetching)
                const Positioned(
                  top: 12,
                  right: 12,
                  child: _FetchingChip(),
                ),
              // 검색 결과 오버레이
              if (_searchOpen)
                Positioned(
                  top: 0,
                  left: 12,
                  right: 12,
                  child: _SearchResults(
                    results: _searchResults,
                    userLoc: ref.watch(userLocationProvider),
                    onTap: _onSearchResultTap,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 지도 / 메뉴 당류 모드 전환 세그먼트.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});
  final _MapMode mode;
  final ValueChanged<_MapMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CubedColors.bg,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Container(
        height: 40,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: CubedColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CubedColors.line),
        ),
        child: Row(children: [
          _seg('매장 지도', Icons.map_rounded, _MapMode.store),
          _seg('메뉴 정보', Icons.local_cafe_rounded, _MapMode.menu),
        ]),
      ),
    );
  }

  Widget _seg(String label, IconData icon, _MapMode m) {
    final selected = mode == m;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(m),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? CubedColors.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? Colors.white : CubedColors.inkSoft),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : CubedColors.inkSoft)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 상단 검색바.
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CubedColors.bg,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: CubedColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: CubedColors.line),
        ),
        child: Row(children: [
          const Icon(Icons.search_rounded, size: 20, color: CubedColors.inkSoft),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: '저당 매장 이름 검색',
                hintStyle: TextStyle(color: CubedColors.inkSoft, fontSize: 14),
              ),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => value.text.isEmpty
                ? const SizedBox.shrink()
                : GestureDetector(
                    onTap: onClear,
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: CubedColors.inkSoft),
                  ),
          ),
        ]),
      ),
    );
  }
}

/// 검색 결과 리스트 (지도 위 오버레이).
class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.results,
    required this.userLoc,
    required this.onTap,
  });
  final List<Store> results;
  final LatLng? userLoc;
  final void Function(Store) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: results.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('검색 결과가 없어요',
                    style:
                        TextStyle(color: CubedColors.inkSoft, fontSize: 13)),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: results.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: CubedColors.line),
              itemBuilder: (_, i) {
                final s = results[i];
                final dist = userLoc != null
                    ? LocationService.formatDistance(
                        userLoc!, LatLng(s.lat, s.lng))
                    : null;
                return InkWell(
                  onTap: () => onTap(s),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    child: Row(children: [
                      Icon(s.type.icon, size: 18, color: s.type.markerColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(s.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: CubedColors.inkSoft)),
                          ],
                        ),
                      ),
                      if (dist != null) ...[
                        const SizedBox(width: 8),
                        Text(dist,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: CubedColors.brand)),
                      ],
                    ]),
                  ),
                );
              },
            ),
    );
  }
}

/// 커스텀 지도 마커 — 색상 원형 배지 + 흰 아이콘 + 물방울 꼬리.
class _MarkerPin extends StatelessWidget {
  const _MarkerPin({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 48,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          // 아래쪽 꼬리(삼각형)
          Transform.translate(
            offset: const Offset(0, -4),
            child: CustomPaint(
              size: const Size(12, 8),
              painter: _PinTailPainter(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinTailPainter extends CustomPainter {
  _PinTailPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinTailPainter old) => old.color != color;
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onTap});
  final Set<StoreType> selected;
  final void Function(StoreType? type) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: CubedColors.bg,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: [
          _Chip(
            label: '전체',
            color: CubedColors.ink,
            active: selected.isEmpty,
            onTap: () => onTap(null),
          ),
          for (final t in StoreType.values)
            _Chip(
              label: t.label,
              color: t.markerColor,
              active: selected.contains(t),
              onTap: () => onTap(t),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? color : CubedColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? color : CubedColors.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : CubedColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

class _FetchingChip extends StatelessWidget {
  const _FetchingChip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 8),
        Text('불러오는 중', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
