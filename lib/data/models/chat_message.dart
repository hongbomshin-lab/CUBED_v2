/// 채팅 메시지 (메모리 보관 — DB 저장 안 함)
enum ChatRole { user, assistant }

class ChatMessage {
  final ChatRole role;
  final String content;
  const ChatMessage({required this.role, required this.content});

  bool get isUser => role == ChatRole.user;

  /// Edge Function 'chat' 전송용 (web lib/chat.ts의 ChatMessage와 동일 포맷)
  Map<String, dynamic> toJson() => {
        'role': role == ChatRole.user ? 'user' : 'assistant',
        'content': content,
      };
}
