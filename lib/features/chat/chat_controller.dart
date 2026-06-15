import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_message.dart';
import '../../providers/providers.dart';

/// 채팅 화면 상태 (메모리만 — autoDispose라 화면을 나가면 초기화)
class ChatState {
  final List<ChatMessage> messages;
  final bool loading;
  const ChatState({required this.messages, required this.loading});

  ChatState copyWith({List<ChatMessage>? messages, bool? loading}) =>
      ChatState(messages: messages ?? this.messages, loading: loading ?? this.loading);
}

const greetingMessage = ChatMessage(
  role: ChatRole.assistant,
  content:
      '안녕하세요! CUBED 저당 제품 도우미예요.\n예: "혈당 부담 적은 음료 추천해줘", "당 0g인데 주의해야 할 과자 있어?"',
);

/// 예시 질문 칩 (인사만 있을 때 노출)
const chatSuggestions = <String>[
  '혈당 부담 적은 음료 추천해줘',
  '당 0g인데 주의해야 할 과자 있어?',
  '말티톨 든 제품 알려줘',
];

class ChatController extends AutoDisposeNotifier<ChatState> {
  @override
  ChatState build() => const ChatState(messages: [greetingMessage], loading: false);

  Future<void> send(String text) async {
    final t = text.trim();
    if (t.isEmpty || state.loading) return;

    final withUser = [...state.messages, ChatMessage(role: ChatRole.user, content: t)];
    state = state.copyWith(messages: withUser, loading: true);

    try {
      final reply = await ref.read(chatServiceProvider).send(_apiHistory(withUser));
      state = state.copyWith(
        messages: [...withUser, ChatMessage(role: ChatRole.assistant, content: reply)],
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        messages: [
          ...withUser,
          ChatMessage(role: ChatRole.assistant, content: '죄송해요, 답변 중 오류가 발생했어요. ($e)'),
        ],
        loading: false,
      );
    }
  }

  /// 전송용 history — 첫 인사(assistant) 등 선두 비-user 메시지를 제거해 user 턴으로 시작시킨다.
  List<ChatMessage> _apiHistory(List<ChatMessage> all) {
    final start = all.indexWhere((m) => m.role == ChatRole.user);
    return start < 0 ? const [] : all.sublist(start);
  }
}

final chatControllerProvider =
    NotifierProvider.autoDispose<ChatController, ChatState>(ChatController.new);
