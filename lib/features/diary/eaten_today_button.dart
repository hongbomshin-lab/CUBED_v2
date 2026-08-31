import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../core/rulebook.dart';
import '../../core/sugar_baselines.dart';
import '../../core/theme.dart';
import '../../data/models/product.dart';
import '../../providers/providers.dart';
import '../auth/login_screen.dart';

/// '오늘 이거 먹었어요' 토글 — DB 제품/촬영 제품 공용. 카카오 로그인 필요.
class EatenTodayButton extends ConsumerWidget {
  const EatenTodayButton({
    super.key,
    required this.product,
    required this.grade,
    this.submissionImagePath,
  });
  final Product product;
  final Grade grade;
  final String? submissionImagePath;

  /// 촬영 제품(ocr-temp)은 product_id 없이 스냅샷으로만 기록 (스펙 §6)
  String? get _productId =>
      product.productId == 'ocr-temp' ? null : product.productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (productId: _productId, name: product.name);
    final user = ref.watch(currentUserProvider);
    final today = ref.watch(todayLogProvider(key));
    final logged = today.valueOrNull != null;
    final busy = today.isLoading;
    final rule =
        sugarBaselineFor(category: product.category, name: product.name);
    final points = sugarPointsFor(
      category: product.category,
      name: product.name,
      sugar: product.sugar,
    );

    Future<void> onTap() async {
      if (user == null) {
        // 로그인 후 사용자가 다시 버튼을 누른다 (자동 재시도 없음, 스펙 §9)
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }
      // 위젯이 await 중 dispose돼도 무효화가 동작하도록 컨테이너를 미리 캡처
      final container = ProviderScope.containerOf(context, listen: false);
      try {
        final logId = await ref.read(foodLogRepositoryProvider).toggleToday(
              productId: _productId,
              name: product.name,
              brand: product.brand,
              category: product.category,
              grade: grade.name,
              imagePath: submissionImagePath,
              points: points,
            );
        final added = logId != null;
        // 적립은 서버가 한다 — 앱은 '이 기록으로 적립해 달라'만 요청하고
        // 금액은 넘기지 않는다. 서버가 products.sugar 로 직접 계산한다.
        // 취소는 회수하지 않는다(토글마다 ±가 반복되면 원장이 지저분해진다).
        var awarded = 0;
        if (added) {
          final repo = container.read(pointsRepositoryProvider);
          try {
            // 적립은 미션(서버)이 정한다 — 그램 비례 auto-award 는 제거했다.
            // 저당 인증(일)·주 5회 기록 미션이 발동하고 실제 적립액을 돌려준다.
            final awards = await repo.fire('product_log',
                data: {
                  'grade': grade.name,
                  if (product.brand != null) 'brand': product.brand!,
                },
                refId: logId);
            awarded = awards.fold(0, (s, a) => s + a.reward);
          } catch (e) {
            debugPrint('적립 실패: $e'); // 기록 자체는 성공했으므로 막지 않는다
          }
          container.invalidate(serverBalanceProvider);
          container.invalidate(serverLedgerProvider);
          container.invalidate(dailyRoomProvider);
        }
        if (context.mounted) {
          if (added && awarded > 0) {
            // awarded=미션 적립 포인트, points=아낀 당류(g) — 둘은 다르다.
            await _showEarnedDialog(context, awarded, points, rule?.basis);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(added ? '오늘 먹은 기록에 추가했어요' : '기록을 취소했어요'),
              duration: const Duration(seconds: 1),
            ));
          }
        }
      } on PostgrestException catch (e) {
        // 동시 중복(unique 충돌)은 이미 기록된 것으로 간주 (스펙 §9)
        if (e.code != '23505' && context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('기록 실패: ${e.message}')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('기록 실패: $e')));
        }
      } finally {
        container.invalidate(todayLogProvider(key));
        container.invalidate(monthLogsProvider); // 달력 전체 갱신
        container.invalidate(myPointsProvider); // 마이페이지 포인트 갱신
      }
    }

    final label = logged ? '오늘 먹었어요 ✓' : '오늘 이거 먹었어요';
    final icon = logged ? Icons.check_circle_rounded : Icons.restaurant_rounded;
    final iconWidget = Icon(icon, size: 20);
    final labelWidget = Text(label,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15));

    final button = SizedBox(
      width: double.infinity,
      child: logged
          ? FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: CubedColors.brand,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: busy ? null : onTap,
              icon: iconWidget,
              label: labelWidget,
            )
          : OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: CubedColors.brand,
                side: const BorderSide(color: CubedColors.brand),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: busy ? null : onTap,
              icon: iconWidget,
              label: labelWidget,
            ),
    );

    if (points <= 0) return button;
    // 왜 기록하는지 먼저 보이게 — 일반 제품 대비 아끼는 당류를 문장으로
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.eco_rounded,
                size: 15, color: CubedColors.brandDeep),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                logged
                    ? '설탕 ${points}g을 아꼈어요'
                    : '${rule?.basis ?? '일반 제품'}보다 당류 ${points}g 덜 먹어요',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: CubedColors.brandDeep),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        button,
      ],
    );
  }

  /// 적립 팝업 — 아낀 당류만큼 포인트 적립을 알린다.
  /// [points] 는 이번에 적립된 **미션 포인트**, [savedG] 는 표시용 **아낀 당류(g)**.
  Future<void> _showEarnedDialog(
      BuildContext context, int points, int savedG, String? basis) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: CubedColors.inkCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CubedFx.radiusHero)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SugarCubeStack(size: 56),
              const SizedBox(height: 16),
              Text('+${points}P',
                  style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: CubedColors.lime)),
              const SizedBox(height: 8),
              const Text('저당 기록 완료!',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              if (savedG > 0) ...[
                const SizedBox(height: 6),
                Text('${basis ?? '일반 제품'}보다 설탕 ${savedG}g을 덜 먹었어요',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.white70)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: CubedColors.lime,
                    foregroundColor: CubedColors.ink,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('좋아요',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
