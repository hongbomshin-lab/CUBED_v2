import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// 브라우저 클립보드에서 이미지 바이트를 읽는다(웹 전용). 이미지가 없으면 null.
/// 버튼 클릭(사용자 제스처) 안에서 호출해야 클립보드 읽기 권한이 허용된다.
Future<Uint8List?> readClipboardImage() async {
  final clipboard = web.window.navigator.clipboard;
  final items = (await clipboard.read().toDart).toDart;
  for (final item in items) {
    final types = item.types.toDart;
    for (final t in types) {
      final type = t.toDart;
      if (type.startsWith('image/')) {
        final blob = await item.getType(type).toDart;
        final buffer = await blob.arrayBuffer().toDart;
        return buffer.toDart.asUint8List();
      }
    }
  }
  return null;
}
