import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 제보 큐 항목 (parsed는 편집 대상이라 Map 그대로 보관).
class Submission {
  final int id;
  final String? barcode;
  final Map<String, dynamic> parsed;
  final String imagePath;
  final String status;
  const Submission({required this.id, this.barcode, required this.parsed, required this.imagePath, required this.status});
  factory Submission.fromMap(Map<String, dynamic> m) => Submission(
        id: m['id'] as int,
        barcode: m['barcode'] as String?,
        parsed: Map<String, dynamic>.from((m['parsed'] as Map?) ?? const {}),
        imagePath: (m['image_path'] as String?) ?? '',
        status: (m['status'] as String?) ?? 'pending',
      );
}

class AdminService {
  AdminService(this._db);
  final SupabaseClient _db;

  Future<Map<String, dynamic>> _call(String action, [Map<String, dynamic> args = const {}]) async {
    final res = await _db.functions.invoke('admin', body: {'action': action, ...args});
    final data = res.data is String ? jsonDecode(res.data as String) : res.data;
    final m = Map<String, dynamic>.from(data as Map);
    if (res.status != 200 || m['error'] != null) {
      throw Exception(m['error'] ?? '요청 실패 (status ${res.status})');
    }
    return m;
  }

  Future<List<Submission>> listSubmissions({String status = 'pending'}) async {
    final m = await _call('list_submissions', {'status': status});
    return ((m['submissions'] as List?) ?? const [])
        .map((e) => Submission.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> updateParsed(int id, Map<String, dynamic> parsed) => _call('update_parsed', {'id': id, 'parsed': parsed});
  Future<void> reject(int id) => _call('reject', {'id': id});
  Future<String> promote(int submissionId) async =>
      (await _call('promote', {'submission_id': submissionId}))['product_id'] as String;

  Future<List<Map<String, dynamic>>> listProducts({String q = ''}) async {
    final m = await _call('list_products', {'q': q});
    return ((m['products'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> updateProduct(String productId, Map<String, dynamic> fields) =>
      _call('update_product', {'product_id': productId, 'fields': fields});
  Future<void> setVerified(String productId, bool verified) =>
      _call('set_verified', {'product_id': productId, 'verified': verified});

  /// 제보 원본 사진 3장의 서명 URL(full/ingredients/nutrition). 비공개 버킷이라 서버 경유.
  Future<Map<String, String?>> signedUrls(String imagePath) async {
    final m = await _call('signed_urls', {'image_path': imagePath});
    final urls = Map<String, dynamic>.from((m['urls'] as Map?) ?? const {});
    return urls.map((k, v) => MapEntry(k, v as String?));
  }

  Future<void> updateProductSweeteners(String productId, List<Map<String, dynamic>> sweeteners) =>
      _call('update_product_sweeteners', {'product_id': productId, 'sweeteners': sweeteners});
}
