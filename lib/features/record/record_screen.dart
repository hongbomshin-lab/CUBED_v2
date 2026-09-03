import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../core/product_thumb.dart';
import '../../core/rulebook.dart';
import '../../core/sugar_baselines.dart';
import '../../core/theme.dart';
import '../../data/models/product.dart';
import '../../providers/providers.dart';
import '../auth/login_screen.dart';

/// 저당 기록 페이지 — 먹은 저당 제품을 검색·선택해 기록하면 미션 포인트가 쌓인다.
///
/// 적립 금액은 서버(미션)가 정한다. 이 화면은 '무엇을 먹었다'만 서버에 알린다.
/// 실제 DB 제품을 골라야 기록되므로(검증), 근거 없는 적립이 불가능하다.
class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchProvider(_q));

    return Scaffold(
      backgroundColor: CubedColors.bg,
      appBar: AppBar(title: const Text('저당 기록')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('먹은 저당 제품을 검색해 기록하면 포인트가 쌓여요',
                  style: TextStyle(fontSize: 13, color: CubedColors.inkSoft)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                hintText: '제품명 또는 브랜드 (예: 제로콜라, 라라스윗)',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
              data: (list) {
                if (_q.trim().isEmpty) {
                  return const _Hint('먹은 저당 제품을 검색해보세요');
                }
                if (list.isEmpty) {
                  return const _Hint('검색 결과가 없어요');
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: list.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: CubedColors.line),
                  itemBuilder: (_, i) {
                    final p = list[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      leading: ProductThumb(
                          imageFile: p.imageFile, size: 44, radius: 12),
                      title: Text(p.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${p.brand ?? ''} · ${p.category ?? ''}'),
                      trailing: const Icon(Icons.add_circle_outline_rounded,
                          color: CubedColors.brand),
                      onTap: () => _showRecordSheet(p),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRecordSheet(Product product) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CubedColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RecordSheet(product: product),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Center(
        child: Text(text, style: const TextStyle(color: CubedColors.inkSoft)),
      );
}

/// 기록 확인 시트 — 등급 + 아낀 당류를 보여주고 '기록하기'.
class _RecordSheet extends ConsumerStatefulWidget {
  const _RecordSheet({required this.product});
  final Product product;

  @override
  ConsumerState<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends ConsumerState<_RecordSheet> {
  Product get product => widget.product;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final interp = ref.watch(interpretationProvider(product));
    // '아낀 당류'는 표시용 — 포인트는 서버 미션이 정한다.
    final savedG = sugarPointsFor(
      category: product.category,
      name: product.name,
      sugar: product.sugar,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: 20 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: CubedColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 제품
            Row(children: [
              ProductThumb(imageFile: product.imageFile, size: 56, radius: 14),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product.brand != null)
                      Text(product.brand!,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: CubedColors.inkSoft)),
                    const SizedBox(height: 2),
                    Text(product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              interp.when(
                loading: () => const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (_, __) => const SizedBox.shrink(),
                data: (it) => _GradeBadge(it.grade),
              ),
            ]),

            const SizedBox(height: 18),

            // 아낀 당류 (표시만)
            if (savedG > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CubedColors.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  const Icon(Icons.local_florist_rounded,
                      size: 18, color: CubedColors.brand),
                  const SizedBox(width: 10),
                  Text('이 선택으로 아낀 당류 약 ${savedG}g',
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: CubedColors.brandDeep)),
                ]),
              ),

            const SizedBox(height: 14),

            // 기록 버튼 — 실제 적립은 기록 후 서버 미션 결과로 안내
            interp.when(
              loading: () => const _DisabledButton('불러오는 중…'),
              error: (_, __) => _RecordButton(onTap: () => _record(Grade.mid)),
              data: (it) => _RecordButton(
                busy: _busy,
                onTap: () => _record(it.grade),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '저당 제품을 기록하면 미션 포인트가 쌓여요. 적립 금액은 서버가 정합니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: CubedColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _record(Grade grade) async {
    if (_busy) return;
    if (ref.read(currentUserProvider) == null) {
      Navigator.of(context).pop();
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    setState(() => _busy = true);
    final container = ProviderScope.containerOf(context, listen: false);
    final foodRepo = container.read(foodLogRepositoryProvider);
    final pointsRepo = container.read(pointsRepositoryProvider);
    // '아낀 당류' 표시값을 로그에 함께 저장(포인트 아님 — diary에서 g로 보여준다).
    final savedG = sugarPointsFor(
      category: product.category,
      name: product.name,
      sugar: product.sugar,
    );

    try {
      // 이미 오늘 기록했으면 지우지 않고 안내만 (기록 페이지에서 실수 삭제 방지).
      final existing =
          await foodRepo.todayLogFor(productId: _productId, name: product.name);
      if (existing != null) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('오늘 이미 기록한 제품이에요'),
              duration: Duration(seconds: 2)));
        }
        return;
      }

      final logId = await foodRepo.toggleToday(
        productId: _productId,
        name: product.name,
        brand: product.brand,
        category: product.category,
        grade: grade.name,
        points: savedG,
      );

      var awarded = 0;
      if (logId != null) {
        final awards = await pointsRepo.fire('product_log',
            data: {
              'grade': grade.name,
              if (product.brand != null) 'brand': product.brand!,
            },
            refId: logId);
        awarded = awards.fold(0, (s, a) => s + a.reward);
      }

      container.invalidate(monthLogsProvider);
      container.invalidate(myPointsProvider);
      container.invalidate(serverBalanceProvider);
      container.invalidate(serverLedgerProvider);
      container.invalidate(dailyRoomProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(awarded > 0
              ? '기록 완료 · +${awarded}P'
              : '기록 완료 — 오늘 저당 미션은 이미 채웠어요'),
          duration: const Duration(seconds: 2),
        ));
      }
    } on PostgrestException catch (e) {
      if (mounted && e.code != '23505') {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('기록 실패: ${e.message}')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('기록 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 촬영 제품(ocr-temp)은 product_id 없이 스냅샷으로만 (eaten_today_button 과 동일).
  String? get _productId =>
      product.productId == 'ocr-temp' ? null : product.productId;
}

class _GradeBadge extends StatelessWidget {
  const _GradeBadge(this.grade);
  final Grade grade;
  @override
  Widget build(BuildContext context) {
    final color = switch (grade) {
      Grade.low => CubedColors.low,
      Grade.mid => CubedColors.mid,
      Grade.caution => CubedColors.caution,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('당 ${grade.ko}',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.onTap, this.busy = false});
  final VoidCallback onTap;
  final bool busy;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: CubedColors.ink,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: busy ? null : onTap,
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('기록하기',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      );
}

class _DisabledButton extends StatelessWidget {
  const _DisabledButton(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: CubedColors.line,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: null,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      );
}
