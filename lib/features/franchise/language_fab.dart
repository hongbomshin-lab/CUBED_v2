import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_lang.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';

/// 메뉴 정보 화면의 언어 선택 버튼.
/// 접혀 있을 때는 현재 언어만 보이고, 탭하면 나머지 언어가 위로 펼쳐진다.
class LanguageFab extends ConsumerStatefulWidget {
  const LanguageFab({super.key});

  @override
  ConsumerState<LanguageFab> createState() => _LanguageFabState();
}

class _LanguageFabState extends ConsumerState<LanguageFab>
    with SingleTickerProviderStateMixin {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(menuLangProvider);
    // 펼쳤을 때 위로 쌓이는 순서: 아래(버튼 가까이)부터 자연스럽게 보이도록 역순.
    final others =
        AppLang.values.where((l) => l != current).toList().reversed.toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 펼쳐진 선택지 (위쪽)
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.bottomRight,
          child: _open
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final lang in others)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _LangPill(
                          lang: lang,
                          selected: false,
                          onTap: () {
                            ref.read(menuLangProvider.notifier).select(lang);
                            setState(() => _open = false);
                          },
                        ),
                      ),
                  ],
                )
              : const SizedBox.shrink(),
        ),

        // 현재 언어 버튼 (탭하면 펼침/접힘)
        _LangPill(
          lang: current,
          selected: true,
          expanded: _open,
          onTap: () => setState(() => _open = !_open),
        ),
      ],
    );
  }
}

class _LangPill extends StatelessWidget {
  const _LangPill({
    required this.lang,
    required this.selected,
    required this.onTap,
    this.expanded = false,
  });

  final AppLang lang;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? CubedColors.brand : CubedColors.surface;
    final fg = selected ? Colors.white : CubedColors.ink;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(22),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          // alignment 를 주면 Container 가 가용 폭 전체로 늘어난다 — 내용 폭에 맞춘다.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: selected ? null : Border.all(color: CubedColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? Icons.translate_rounded : Icons.circle_outlined,
                size: selected ? 18 : 8,
                color: fg,
              ),
              const SizedBox(width: 8),
              Text(
                selected ? lang.short : lang.label,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: fg),
              ),
              if (selected) ...[
                const SizedBox(width: 4),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  size: 18,
                  color: fg,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
