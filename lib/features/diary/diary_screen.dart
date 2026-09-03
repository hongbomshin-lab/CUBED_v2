import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/rulebook.dart';
import '../../core/theme.dart';
import '../../data/models/food_log.dart';
import '../../providers/providers.dart';
import '../auth/login_screen.dart';
import 'log_image_url.dart';

/// 먹은 기록 달력 — 월 뷰 + 선택일 리스트. 보기·스와이프 삭제 전용 (스펙 §3).
class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});
  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  late DateTime _focused;
  late DateTime _selected;
  late final DateTime _lastDay;

  /// 낙관적 삭제 — provider 재조회 전 즉시 숨겨 Dismissible 재출현(assert)을 방지
  final Set<String> _removedIds = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focused = now;
    _selected = DateTime(now.year, now.month, now.day);
    _lastDay = now.add(const Duration(days: 366));
  }

  ({int year, int month}) get _monthKey =>
      (year: _focused.year, month: _focused.month);

  Future<void> _remove(FoodLog log) async {
    // 위젯이 await 중 dispose돼도 무효화가 동작하도록 컨테이너를 미리 캡처
    // (eaten_today_button.dart와 동일 패턴)
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _removedIds.add(log.id)); // 낙관적 숨김
    try {
      await ref.read(foodLogRepositoryProvider).removeLog(log.id);
    } catch (e) {
      if (mounted) {
        setState(() => _removedIds.remove(log.id)); // 롤백
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
      return;
    }
    // 기록이 속한 달을 무효화 — await 중 달력을 넘겼어도 정확한 달을 갱신
    container.invalidate(
        monthLogsProvider((year: log.eatenOn.year, month: log.eatenOn.month)));
    container.invalidate(myPointsProvider); // 삭제된 기록의 포인트 반영
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const _LoginNeeded();

    final logs = ref.watch(monthLogsProvider(_monthKey));
    final byDay = <String, List<FoodLog>>{};
    for (final log in logs.valueOrNull ?? const <FoodLog>[]) {
      if (_removedIds.contains(log.id)) continue;
      byDay.putIfAbsent(FoodLog.dateKey(log.eatenOn), () => []).add(log);
    }
    final dayLogs = byDay[FoodLog.dateKey(_selected)] ?? const <FoodLog>[];

    return Scaffold(
      appBar: AppBar(title: const Text('내가 먹은 기록')),
      body: Column(
        children: [
          TableCalendar<FoodLog>(
            firstDay: DateTime(2026, 1, 1),
            lastDay: _lastDay,
            focusedDay: _focused,
            selectedDayPredicate: (d) => isSameDay(d, _selected),
            eventLoader: (d) => byDay[FoodLog.dateKey(d)] ?? const [],
            onDaySelected: (sel, foc) => setState(() {
              _selected = sel;
              _focused = foc;
            }),
            onPageChanged: (foc) => setState(() => _focused = foc),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextFormatter: (date, _) => '${date.year}년 ${date.month}월',
              titleTextStyle:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            calendarBuilders: CalendarBuilders(
              dowBuilder: (context, day) {
                const names = ['월', '화', '수', '목', '금', '토', '일'];
                return Center(
                    child: Text(names[day.weekday - 1],
                        style: const TextStyle(
                            fontSize: 12, color: CubedColors.inkSoft)));
              },
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                  color: CubedColors.brand.withValues(alpha: 0.25),
                  shape: BoxShape.circle),
              selectedDecoration: const BoxDecoration(
                  color: CubedColors.brand, shape: BoxShape.circle),
              markerDecoration: const BoxDecoration(
                  color: CubedColors.brand, shape: BoxShape.circle),
              markersMaxCount: 3,
              outsideDaysVisible: false,
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, color: CubedColors.line),
          Expanded(
            child: logs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('기록을 불러오지 못했어요',
                      style: TextStyle(color: CubedColors.inkSoft)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(monthLogsProvider(_monthKey)),
                    child: const Text('다시 시도'),
                  ),
                ]),
              ),
              data: (_) => dayLogs.isEmpty
                  ? const Center(
                      child: Text('이 날은 기록이 없어요',
                          style: TextStyle(color: CubedColors.inkSoft)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: dayLogs.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: CubedColors.line),
                      itemBuilder: (_, i) => _LogTile(
                        log: dayLogs[i],
                        onDelete: () => _remove(dayLogs[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log, required this.onDelete});
  final FoodLog log;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: CubedColors.caution.withValues(alpha: 0.12),
        child: const Icon(Icons.delete_outline_rounded,
            color: CubedColors.caution),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
        leading: _LogThumb(log: log),
        title:
            Text(log.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          log.brand ?? (log.productId == null ? '사진으로 분석한 제품' : ''),
          style: const TextStyle(color: CubedColors.inkSoft, fontSize: 12),
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _GradeBadge(grade: log.grade),
            // log.points 는 '아낀 당류(g)' 값이다(포인트 아님). 포인트는 미션이 정하고
            // 잔액·포인트 내역에서 본다. 여기선 아낀 설탕 양을 그대로 보여준다.
            if (log.points > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('설탕 −${log.points}g',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: CubedColors.brandDeep)),
              ),
          ],
        ),
      ),
    );
  }
}

/// product-images(공개) / submission-images(인증 헤더) / placeholder 분기
class _LogThumb extends ConsumerWidget {
  const _LogThumb({required this.log});
  final FoodLog log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final src = logImageUrl(log);
    Widget fallback() => Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: CubedColors.bg,
            border: Border.all(color: CubedColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.photo_camera_outlined,
              size: 20, color: CubedColors.inkSoft),
        );
    if (src == null) return fallback();

    final token = ref.watch(supabaseProvider).auth.currentSession?.accessToken;
    final headers = src.needsAuth && token != null
        ? {'Authorization': 'Bearer $token'}
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 44,
        height: 44,
        child: CachedNetworkImage(
          imageUrl: src.url,
          httpHeaders: headers,
          fit: BoxFit.cover,
          placeholder: (_, __) => fallback(),
          errorWidget: (_, __, ___) => fallback(),
        ),
      ),
    );
  }
}

/// 기록 시점 등급 스냅샷 뱃지 (낮음/중간/주의)
class _GradeBadge extends StatelessWidget {
  const _GradeBadge({required this.grade});
  final String? grade;

  @override
  Widget build(BuildContext context) {
    Grade? g;
    if (grade != null) {
      try {
        g = Grade.values.byName(grade!);
      } catch (_) {
        g = null;
      }
    }
    if (g == null) return const SizedBox.shrink();
    final c = CubedColors.grade(g);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(g.ko,
          style:
              TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class _LoginNeeded extends StatelessWidget {
  const _LoginNeeded();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내가 먹은 기록')),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('로그인하면 먹은 기록을 볼 수 있어요',
              style: TextStyle(color: CubedColors.inkSoft)),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: CubedColors.brand),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('로그인'),
          ),
        ]),
      ),
    );
  }
}
