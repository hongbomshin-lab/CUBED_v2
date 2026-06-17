import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/rulebook.dart';
import '../core/theme.dart';
import '../domain/interpretation.dart';
import '../features/ocr/ocr_service.dart';
import 'admin_providers.dart';
import 'parsed_form.dart';

class SubmissionQueueScreen extends ConsumerStatefulWidget {
  const SubmissionQueueScreen({super.key});
  @override
  ConsumerState<SubmissionQueueScreen> createState() => _SubmissionQueueScreenState();
}

class _SubmissionQueueScreenState extends ConsumerState<SubmissionQueueScreen> {
  int? _selectedId;
  Map<String, dynamic>? _draft;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final subs = ref.watch(pendingSubmissionsProvider);
    final refData = ref.watch(adminReferenceProvider);
    return Row(children: [
      SizedBox(width: 320, child: subs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (_, i) {
            final s = list[i];
            return ListTile(
              selected: s.id == _selectedId,
              title: Text((s.parsed['name'] as String?) ?? '(이름 없음)'),
              subtitle: Text('${s.barcode ?? '바코드 없음'} · #${s.id}'),
              onTap: () => setState(() { _selectedId = s.id; _draft = Map.of(s.parsed); }),
            );
          },
        ),
      )),
      const VerticalDivider(width: 1),
      Expanded(child: (_selectedId == null || _draft == null)
        ? const Center(child: Text('제보를 선택하세요'))
        : refData.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (ref0) {
              final preview = OcrResult.fromParsed(_draft!).product;
              final interp = Interpretation.of(preview, ref0);
              return ListView(padding: const EdgeInsets.all(16), children: [
                _GradePreview(interp: interp),
                const SizedBox(height: 12),
                ParsedForm(key: ValueKey(_selectedId), parsed: _draft!, onChanged: (m) => setState(() => _draft = m)),
                const SizedBox(height: 16),
                Row(children: [
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: CubedColors.brand),
                    onPressed: _busy ? null : _approve,
                    child: const Text('승인 → 제품 승격')),
                  const SizedBox(width: 12),
                  OutlinedButton(onPressed: _busy ? null : _reject, child: const Text('거절')),
                ]),
              ]);
            },
          ),
      ),
    ]);
  }

  Future<void> _approve() async {
    final id = _selectedId!;
    setState(() => _busy = true);
    try {
      final svc = ref.read(adminServiceProvider);
      await svc.updateParsed(id, _draft!);
      await svc.promote(id);
      ref.invalidate(pendingSubmissionsProvider);
      setState(() { _selectedId = null; _draft = null; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('승격 완료')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final id = _selectedId!;
    setState(() => _busy = true);
    try {
      await ref.read(adminServiceProvider).reject(id);
      ref.invalidate(pendingSubmissionsProvider);
      setState(() { _selectedId = null; _draft = null; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _GradePreview extends StatelessWidget {
  const _GradePreview({required this.interp});
  final Interpretation interp;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CubedColors.grade(interp.grade).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Text('등급 ${interp.grade.ko}', style: TextStyle(
          fontWeight: FontWeight.w800, fontSize: 18, color: CubedColors.grade(interp.grade))),
        const SizedBox(width: 16),
        Text('순탄수 ${interp.netCarb}g · 100당 ${interp.per100NetCarb}g'),
        const SizedBox(width: 16),
        Expanded(child: Text('함정: ${interp.trapCodes.join(", ")}', overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}
