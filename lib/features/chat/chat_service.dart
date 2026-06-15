import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/chat_message.dart';

/// Edge Function 'chat' 호출 — 제품 룰북 요약을 주입해 Gemini가 생성한 답변을 받는다.
/// 키(GEMINI_API_KEY)는 Edge Function에만 있고 앱엔 노출되지 않는다. (ocr_service.dart와 동일 패턴)
class ChatService {
  ChatService(this._db);
  final SupabaseClient _db;

  /// 멀티턴 history를 보내고 어시스턴트 답변 1개를 받는다(비스트리밍).
  Future<String> send(List<ChatMessage> history) async {
    final res = await _db.functions.invoke('chat', body: {
      'messages': history.map((m) => m.toJson()).toList(),
    });

    final raw = res.data;
    final map = raw is String
        ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
        : Map<String, dynamic>.from((raw as Map?) ?? const {});

    if (res.status != 200) {
      throw Exception(map['error']?.toString() ?? '채팅 응답 실패 (status ${res.status})');
    }
    final reply = map['reply'] as String?;
    if (reply == null || reply.trim().isEmpty) {
      throw Exception(map['error']?.toString() ?? '빈 응답을 받았어요');
    }
    return reply;
  }
}
