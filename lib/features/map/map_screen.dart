import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location_cache.dart';
import '../../core/theme.dart';
import '../../data/models/store.dart';
import '../../providers/providers.dart';
import '../auth/login_screen.dart';
import '../report/store_report_sheet.dart';
import 'widgets/store_detail_sheet.dart';

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

  // 위치 확인 불가 시 기본 중심 (LocationService.fallback 과 동일)
  static const _fallbackCenter = NLatLng(37.58045239, 126.9971964);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'report',
            backgroundColor: CubedColors.brand,
            foregroundColor: Colors.white,
            onPressed: _onReportStore,
            icon: const Icon(Icons.add_location_alt_rounded),
            label: const Text('매장 제보',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'myloc',
            backgroundColor: Colors.white,
            foregroundColor: CubedColors.brand,
            onPressed: _moveToUserLocation,
            child: const Icon(Icons.my_location_rounded),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
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
                ],
              ),
            ),
          ],
        ),
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
