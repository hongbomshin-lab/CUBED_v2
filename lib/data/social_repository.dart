import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/comment.dart';
import 'models/my_comment.dart';

/// 좋아요·코멘트 데이터 접근. 익명 인증(auth.uid()) 기반 소유권.
class SocialRepository {
  SocialRepository(this._db);
  final SupabaseClient _db;

  String? get _uid => _db.auth.currentUser?.id;

  /// 제품 좋아요 수 + 내가 눌렀는지
  Future<LikeInfo> likeInfo(String productId) async {
    final countRows = await _db
        .from('product_like_counts')
        .select('like_count')
        .eq('product_id', productId)
        .maybeSingle();
    final count = (countRows?['like_count'] as num?)?.toInt() ?? 0;

    var liked = false;
    final uid = _uid;
    if (uid != null) {
      final mine = await _db
          .from('product_likes')
          .select('product_id')
          .eq('product_id', productId)
          .eq('user_id', uid)
          .maybeSingle();
      liked = mine != null;
    }
    return LikeInfo(count: count, liked: liked);
  }

  /// 좋아요 토글 → 변경 후 상태 반환
  Future<LikeInfo> toggleLike(String productId) async {
    final uid = _uid;
    if (uid == null) throw Exception('로그인이 필요해요');
    final info = await likeInfo(productId);
    if (info.liked) {
      await _db.from('product_likes').delete().match({
        'product_id': productId,
        'user_id': uid,
      });
    } else {
      await _db.from('product_likes').insert({
        'product_id': productId,
        'user_id': uid,
      });
    }
    return likeInfo(productId);
  }

  /// 코멘트 목록 (최신순)
  Future<List<Comment>> comments(String productId) async {
    final rows = await _db
        .from('product_comments')
        .select()
        .eq('product_id', productId)
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map((m) => Comment.fromMap(m)).toList();
  }

  Future<void> addComment(String productId, String body, {String? nickname}) async {
    final uid = _uid;
    if (uid == null) throw Exception('로그인이 필요해요');
    await _db.from('product_comments').insert({
      'product_id': productId,
      'user_id': uid,
      'nickname': nickname,
      'body': body,
    });
  }

  Future<void> deleteComment(int id) async {
    await _db.from('product_comments').delete().eq('id', id);
  }

  /// 내가 작성한 댓글 전체 (최신순) — 제품명 포함. 마이페이지용.
  Future<List<MyComment>> myComments(String userId, {int limit = 100}) async {
    final rows = await _db
        .from('product_comments')
        .select('id, product_id, body, created_at, products(name, brand)')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map((m) => MyComment.fromMap(m)).toList();
  }

  bool isMine(Comment c) => c.userId == _uid;
}
