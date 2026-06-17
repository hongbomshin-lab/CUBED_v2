import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/env.dart';
import '../core/rulebook.dart';
import '../core/theme.dart';
import '../domain/interpretation.dart';
import '../features/ocr/ocr_service.dart';
import 'admin_providers.dart';
import 'parsed_form.dart';

/// 기존 408개 + 승격분 검색 → 선택 시 상세 편집(제보 큐와 동일한 ParsedForm 재사용).
/// 실시간 등급 미리보기 + verified 토글 + 저장(products 필드 + product_sweeteners).
class ProductBrowserScreen extends ConsumerStatefulWidget {
  const ProductBrowserScreen({super.key});
  @override
  ConsumerState<ProductBrowserScreen> createState() => _ProductBrowserScreenState();
}

class _ProductBrowserScreenState extends ConsumerState<ProductBrowserScreen> {
  String _q = '';
  String? _selectedId;
  Map<String, dynamic>? _draft;
  String? _selectedImageFile;
  bool _verified = false;
  bool _busy = false;

  /// products 행(product_sweeteners 조인 포함) → ParsedForm이 쓰는 parsed 형태 맵.
  Map<String, dynamic> _toParsed(Map<String, dynamic> p) => {
        'name': p['name'],
        'brand': p['brand'],
        'category': p['category'],
        'unit': p['unit'],
        'serving_size': p['serving_size'],
        'kcal': p['kcal'],
        'carb': p['carb'],
        'sugar': p['sugar'],
        'protein': p['protein'],
        'fat': p['fat'],
        'sodium_mg': p['sodium_mg'],
        'fiber': p['fiber'],
        'sugar_alcohol': p['sugar_alcohol'],
        'rare_sugar_g': p['rare_sugar_g'],
        'ingredients_raw': p['ingredients_raw'],
        'notes': p['notes'],
        'sweeteners': ((p['product_sweeteners'] as List?) ?? const [])
            .map((s) => {'slug': (s as Map)['slug'], 'amount_g': s['amount_g']})
            .toList(),
        'unknown_sweeteners': const <String>[],
      };

  void _select(Map<String, dynamic> p) {
    setState(() {
      _selectedId = p['product_id'] as String;
      _draft = _toParsed(p);
      _selectedImageFile = p['image_file'] as String?;
      _verified = (p['verified'] as bool?) ?? false;
    });
  }

  Future<void> _save() async {
    final id = _selectedId!;
    setState(() => _busy = true);
    try {
      final svc = ref.read(adminServiceProvider);
      // products 행 필드(= parsed에서 감미료/미지 제외, null 제외) + verified
      final fields = Map<String, dynamic>.from(_draft!)
        ..remove('sweeteners')
        ..remove('unknown_sweeteners')
        ..removeWhere((k, v) => v == null);
      fields['verified'] = _verified;
      await svc.updateProduct(id, fields);
      await svc.updateProductSweeteners(
        id,
        ((_draft!['sweeteners'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
      ref.invalidate(productSearchProvider(_q));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장 완료')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(productSearchProvider(_q));
    final refData = ref.watch(adminReferenceProvider);
    return Row(children: [
      // ── 좌: 검색 + 목록
      SizedBox(
        width: 340,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(hintText: '제품명 검색', prefixIcon: Icon(Icons.search)),
              onSubmitted: (v) => setState(() => _q = v.trim()),
            ),
          ),
          Expanded(
            child: results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (list) => ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = list[i];
                  final verified = (p['verified'] as bool?) ?? false;
                  return ListTile(
                    selected: p['product_id'] == _selectedId,
                    title: Text((p['name'] as String?) ?? ''),
                    subtitle: Text('${p['brand'] ?? ''} · ${p['category'] ?? ''} · ${p['source_type'] ?? ''}'),
                    trailing: verified
                        ? const Icon(Icons.verified, color: CubedColors.brand, size: 18)
                        : const Icon(Icons.remove_circle_outline, color: CubedColors.line, size: 18),
                    onTap: () => _select(p),
                  );
                },
              ),
            ),
          ),
        ]),
      ),
      const VerticalDivider(width: 1),
      // ── 우: 상세 편집
      Expanded(
        child: (_selectedId == null || _draft == null)
            ? const Center(child: Text('제품을 선택하세요'))
            : refData.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (ref0) {
                  final preview = OcrResult.fromParsed(_draft!).product;
                  final interp = Interpretation.of(preview, ref0);
                  return ListView(padding: const EdgeInsets.all(16), children: [
                    Row(children: [
                      Expanded(child: _GradePreview(interp: interp)),
                      const SizedBox(width: 12),
                      const Text('검증됨'),
                      Switch(
                        value: _verified,
                        activeThumbColor: CubedColors.brand,
                        onChanged: (v) => setState(() => _verified = v),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    if (_selectedImageFile != null && _selectedImageFile!.isNotEmpty) ...[
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            '${Env.imageBaseUrl}/${_selectedImageFile!}',
                            height: 200,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              height: 60,
                              child: Center(child: Text('이미지 불러오기 실패',
                                  style: TextStyle(color: CubedColors.inkSoft))),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ParsedForm(
                      key: ValueKey(_selectedId),
                      parsed: _draft!,
                      onChanged: (m) => setState(() => _draft = m),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: CubedColors.brand,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _busy ? null : _save,
                      child: const Text('저장'),
                    ),
                  ]);
                },
              ),
      ),
    ]);
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
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Text('등급 ${interp.grade.ko}',
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 18, color: CubedColors.grade(interp.grade))),
        const SizedBox(width: 16),
        Text('순탄수 ${interp.netCarb}g · 100당 ${interp.per100NetCarb}g'),
        const SizedBox(width: 16),
        Expanded(child: Text('함정: ${interp.trapCodes.join(", ")}', overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}
