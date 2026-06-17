import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import 'admin_providers.dart';

/// parsed(jsonb) 편집 폼. 변경 시 onChanged(업데이트된 Map) 호출.
/// 카테고리/감미료 slug 목록은 adminReferenceProvider(기준데이터)에서 가져온다.
class ParsedForm extends ConsumerWidget {
  const ParsedForm({super.key, required this.parsed, required this.onChanged});
  final Map<String, dynamic> parsed;
  final void Function(Map<String, dynamic>) onChanged;

  Map<String, dynamic> _with(String key, Object? value) {
    final m = Map<String, dynamic>.from(parsed);
    if (value == null || value == '') {
      m.remove(key);
    } else {
      m[key] = value;
    }
    return m;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refData = ref.watch(adminReferenceProvider);
    final categories = refData.maybeWhen(
        data: (r) => r.categoryLiquid.keys.toList()..sort(), orElse: () => <String>[]);
    final slugs = refData.maybeWhen(
        data: (r) => r.sweeteners.keys.toList()..sort(), orElse: () => <String>[]);
    final sweeteners = ((parsed['sweeteners'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final unknown = ((parsed['unknown_sweeteners'] as List?) ?? const []).cast<String>();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _text('제품명', parsed['name'], (v) => onChanged(_with('name', v))),
      _text('브랜드', parsed['brand'], (v) => onChanged(_with('brand', v))),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _dropdown('카테고리', categories, parsed['category'] as String?,
            (v) => onChanged(_with('category', v)))),
        const SizedBox(width: 12),
        _unitToggle(parsed['unit'] as String?, (v) => onChanged(_with('unit', v))),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 8, children: [
        for (final f in const [
          ['serving_size', '1회제공량'], ['kcal', '열량'], ['carb', '탄수'], ['sugar', '당류'],
          ['protein', '단백질'], ['fat', '지방'], ['sodium_mg', '나트륨(mg)'], ['fiber', '식이섬유'],
          ['sugar_alcohol', '당알코올'], ['rare_sugar_g', '희소당(알룰로오스)'],
        ])
          SizedBox(width: 150, child: _num(f[1], parsed[f[0]], (v) => onChanged(_with(f[0], v)))),
      ]),
      const SizedBox(height: 8),
      _text('원재료명', parsed['ingredients_raw'], (v) => onChanged(_with('ingredients_raw', v)), maxLines: 3),
      const SizedBox(height: 12),
      const Text('감미료', style: TextStyle(fontWeight: FontWeight.w800)),
      for (var i = 0; i < sweeteners.length; i++) _sweetenerRow(slugs, sweeteners, i),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => onChanged(_with('sweeteners',
              [...sweeteners, {'slug': slugs.isNotEmpty ? slugs.first : '', 'amount_g': null}])),
          icon: const Icon(Icons.add),
          label: const Text('감미료 추가')),
      ),
      if (unknown.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('미지 감미료(검수 대상): ${unknown.join(", ")}',
              style: const TextStyle(color: CubedColors.caution))),
    ]);
  }

  Widget _sweetenerRow(List<String> slugs, List<Map<String, dynamic>> sweeteners, int i) {
    final sw = sweeteners[i];
    final slug = sw['slug'] as String?;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
          child: DropdownButton<String>(
            isExpanded: true,
            value: (slug != null && slugs.contains(slug)) ? slug : null,
            hint: const Text('slug 선택'),
            items: [for (final s in slugs) DropdownMenuItem(value: s, child: Text(s))],
            onChanged: (v) {
              final next = [...sweeteners];
              next[i] = {...sw, 'slug': v};
              onChanged(_with('sweeteners', next));
            }),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: TextFormField(
            initialValue: sw['amount_g']?.toString() ?? '',
            decoration: const InputDecoration(labelText: 'g'),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final next = [...sweeteners];
              next[i] = {...sw, 'amount_g': v.isEmpty ? null : num.tryParse(v)};
              onChanged(_with('sweeteners', next));
            }),
        ),
        IconButton(
          onPressed: () {
            final next = [...sweeteners]..removeAt(i);
            onChanged(_with('sweeteners', next));
          },
          icon: const Icon(Icons.delete_outline)),
      ]),
    );
  }

  Widget _text(String label, Object? value, void Function(String) onCh, {int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextFormField(
          initialValue: value?.toString() ?? '',
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label),
          onChanged: onCh));

  Widget _num(String label, Object? value, void Function(num?) onCh) => TextFormField(
        initialValue: value?.toString() ?? '',
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        onChanged: (v) => onCh(v.isEmpty ? null : num.tryParse(v)));

  Widget _dropdown(String label, List<String> options, String? value, void Function(String?) onCh) =>
      InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: (value != null && options.contains(value)) ? value : null,
            hint: const Text('선택'),
            items: [for (final o in options) DropdownMenuItem(value: o, child: Text(o))],
            onChanged: onCh)),
      );

  Widget _unitToggle(String? value, void Function(String) onCh) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('단위 '),
          ChoiceChip(label: const Text('ml'), selected: value == 'ml', onSelected: (_) => onCh('ml')),
          const SizedBox(width: 6),
          ChoiceChip(label: const Text('g'), selected: value == 'g', onSelected: (_) => onCh('g')),
        ]);
}
