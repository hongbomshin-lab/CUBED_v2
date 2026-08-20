import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sugar_profile.dart';
import '../../../core/theme.dart';
import '../../../providers/providers.dart';

/// 당류 프로필 온보딩/수정 바텀시트 — 통합 질문 1개 + 선택 입력(체중·식사 횟수).
/// 저장하면 sugarProfileProvider가 갱신되어 열려 있는 결과 화면 히어로가 즉시 교체된다.
Future<void> showSugarProfileSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _SugarProfileSheet(),
  );
}

class _SugarProfileSheet extends ConsumerStatefulWidget {
  const _SugarProfileSheet();
  @override
  ConsumerState<_SugarProfileSheet> createState() => _SugarProfileSheetState();
}

class _SugarProfileSheetState extends ConsumerState<_SugarProfileSheet> {
  SugarGoal? _goal;
  int? _meals;
  late final TextEditingController _weight;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(sugarProfileProvider);
    _goal = existing?.goal;
    _meals = existing?.mealsPerDay;
    _weight = TextEditingController(
        text: existing?.weightKg == null
            ? ''
            : existing!.weightKg! == existing.weightKg!.roundToDouble()
                ? existing.weightKg!.toInt().toString()
                : existing.weightKg!.toString());
  }

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final profile = SugarProfile(
      goal: _goal!,
      weightKg: double.tryParse(_weight.text.trim()),
      mealsPerDay: _meals,
    );
    await ref.read(sugarProfileProvider.notifier).save(profile);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('당, 얼마나 조심해야 할까요?',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('답에 맞춰 스캔 결과에 내 기준 당류 판정이 표시돼요.',
                  style: TextStyle(color: CubedColors.inkSoft, fontSize: 13)),
              const SizedBox(height: 16),
              _GoalCard(
                emoji: '🩸',
                label: '혈당 관리 중이에요',
                selected: _goal == SugarGoal.bloodSugar,
                onTap: () => setState(() => _goal = SugarGoal.bloodSugar),
              ),
              _GoalCard(
                emoji: '⚖️',
                label: '체중 관리 중이에요',
                selected: _goal == SugarGoal.weight,
                onTap: () => setState(() => _goal = SugarGoal.weight),
              ),
              _GoalCard(
                emoji: '🌿',
                label: '그냥 건강하게 먹고 싶어요',
                selected: _goal == SugarGoal.general,
                onTap: () => setState(() => _goal = SugarGoal.general),
              ),
              const SizedBox(height: 18),
              const Text('더 정확하게 (선택)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 10),
              TextField(
                controller: _weight,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '체중 (kg)',
                  hintText: '비워두면 2000kcal 기준',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('하루 식사 횟수',
                      style: TextStyle(color: CubedColors.inkSoft, fontSize: 13)),
                  const Spacer(),
                  for (final n in [2, 3, 4])
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text('$n끼'),
                        selected: (_meals ?? 3) == n,
                        selectedColor:
                            CubedColors.brand.withValues(alpha: 0.15),
                        onSelected: (_) => setState(() => _meals = n),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: CubedColors.brand,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: _goal == null ? null : _save,
                  child: const Text('내 기준으로 판정 시작',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard(
      {required this.emoji,
      required this.label,
      required this.selected,
      required this.onTap});
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? CubedColors.brand.withValues(alpha: 0.08)
              : CubedColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? CubedColors.brand : CubedColors.line,
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 15)),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  size: 20, color: CubedColors.brand),
          ],
        ),
      ),
    );
  }
}
