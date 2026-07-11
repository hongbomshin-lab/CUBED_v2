import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../core/rulebook.dart';
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
        final added = await ref.read(foodLogRepositoryProvider).toggleToday(
              productId: _productId,
              name: product.name,
              brand: product.brand,
              category: product.category,
              grade: grade.name,
              imagePath: submissionImagePath,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(added ? '오늘 먹은 기록에 추가했어요' : '기록을 취소했어요'),
            duration: const Duration(seconds: 1),
          ));
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
      }
    }

    final label = logged ? '오늘 먹었어요 ✓' : '오늘 이거 먹었어요';
    final icon = logged ? Icons.check_circle_rounded : Icons.restaurant_rounded;
    final iconWidget = Icon(icon, size: 20);
    final labelWidget = Text(label,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15));

    return SizedBox(
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
  }
}
