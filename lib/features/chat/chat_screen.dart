import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models/chat_message.dart';
import 'chat_controller.dart';

/// CUBED AI 도우미 채팅 화면.
/// 제품 룰북 요약을 주입받은 Gemini가 데이터에 있는 제품만 근거로 답한다. (대화는 메모리만)
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.initialPrompt});

  /// 결과 화면 등에서 진입 시 자동으로 보낼 첫 질문 (null이면 기존과 동일)
  final String? initialPrompt;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final p = widget.initialPrompt;
    if (p != null && p.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(p));
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = preset ?? _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    ref.read(chatControllerProvider.notifier).send(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    // 새 메시지/로딩 변화 시 하단으로 스크롤
    ref.listen(chatControllerProvider, (_, __) => _scrollToBottom());

    final showSuggestions = state.messages.length <= 1 && !state.loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CUBED 도우미'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(18),
          child: Padding(
            padding: EdgeInsets.only(left: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('저당 제품 안내',
                  style: TextStyle(color: CubedColors.inkSoft, fontSize: 12)),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: state.messages.length + (state.loading ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == state.messages.length) return const _TypingBubble();
                return _Bubble(message: state.messages[i]);
              },
            ),
          ),
          if (showSuggestions) _Suggestions(onTap: _send),
          _InputBar(controller: _input, loading: state.loading, onSend: () => _send()),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: isUser ? CubedColors.brand : CubedColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser ? null : Border.all(color: CubedColors.line),
        ),
        child: SelectableText(
          message.content,
          style: TextStyle(
            color: isUser ? Colors.white : CubedColors.ink,
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: CubedColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: CubedColors.line),
        ),
        child: const SizedBox(
          width: 18,
          height: 14,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: CubedColors.inkSoft),
            ),
          ),
        ),
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onTap});
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in chatSuggestions)
            ActionChip(
              label: Text(s, style: const TextStyle(fontSize: 12.5)),
              backgroundColor: CubedColors.surface,
              side: const BorderSide(color: CubedColors.line),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onPressed: () => onTap(s),
            ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.loading, required this.onSend});
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: CubedColors.bg,
          border: Border(top: BorderSide(color: CubedColors.line)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: '제품·혈당·당류에 대해 물어보세요',
                      hintStyle: const TextStyle(color: CubedColors.inkSoft, fontSize: 14),
                      filled: true,
                      fillColor: CubedColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: CubedColors.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: CubedColors.brand, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _SendButton(loading: loading, onTap: onSend),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '이 답변은 의료 조언이 아닙니다 · 등급은 CUBED 자체 해석',
              style: TextStyle(color: CubedColors.inkSoft, fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: loading ? CubedColors.inkSoft : CubedColors.brand,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? null : onTap,
        child: const SizedBox(
          width: 46,
          height: 46,
          child: Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
