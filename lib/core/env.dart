/// Supabase 연결 설정 (CUBED_v2 프로젝트).
/// anon(publishable) 키는 공개 키로 클라이언트 노출이 정상이다. (RLS로 보호)
/// service_role 키는 절대 앱에 넣지 않는다.
library;

class Env {
  static const supabaseUrl = 'https://aqhfddvvxnakgkdtirem.supabase.co';
  // anon 키(JWT). RLS로 보호되므로 클라이언트 노출 정상. Edge Function의 verify_jwt와 정합.
  // service_role 키는 앱에 절대 포함하지 않는다.
  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFxaGZkZHZ2eG5ha2drZHRpcmVtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEyOTcxNzAsImV4cCI6MjA5Njg3MzE3MH0.wntnduEOWL-LMkVkDs9d_p2MKQDDY4XGn8_4tlL6Q9w';

  /// 대표 썸네일 베이스 경로 (Storage product-images 버킷).
  /// products.image_file = "{product_id}.png"
  static const imageBaseUrl = '$supabaseUrl/storage/v1/object/public/product-images';
}
