import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cubed_app/features/capture/capture_controller.dart';

Uint8List _b(int n) => Uint8List.fromList([n]);

// StateNotifier.state는 @protected라 외부에서 직접 읽지 않는다.
// 상태는 provider를 통해 읽고, autoDispose 유지를 위해 리스너를 건다.
ProviderContainer _container() {
  final c = ProviderContainer();
  c.listen(captureControllerProvider, (_, __) {});
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('CaptureState(순수): 3장 다 차야 isComplete', () {
    const empty = CaptureState();
    expect(empty.isComplete, false);
    expect(empty.count, 0);
    final two = empty.copyWith(images: {
      CaptureSlot.full: _b(1),
      CaptureSlot.ingredients: _b(2),
    });
    expect(two.isComplete, false);
    expect(two.count, 2);
    final three = two.copyWith(images: {...two.images, CaptureSlot.nutrition: _b(3)});
    expect(three.isComplete, true);
    expect(three.count, 3);
  });

  test('CaptureController.setImage → 3장이면 isComplete', () {
    final c = _container();
    final ctrl = c.read(captureControllerProvider.notifier);
    ctrl.setImage(CaptureSlot.full, _b(1));
    ctrl.setImage(CaptureSlot.ingredients, _b(2));
    ctrl.setImage(CaptureSlot.nutrition, _b(3));
    expect(c.read(captureControllerProvider).isComplete, true);
  });

  test('removeImage / reset', () {
    final c = _container();
    final ctrl = c.read(captureControllerProvider.notifier);
    ctrl.setImage(CaptureSlot.full, _b(1));
    ctrl.removeImage(CaptureSlot.full);
    expect(c.read(captureControllerProvider).images.containsKey(CaptureSlot.full), false);
    ctrl.setImage(CaptureSlot.full, _b(1));
    ctrl.setError('x');
    ctrl.reset();
    final s = c.read(captureControllerProvider);
    expect(s.count, 0);
    expect(s.error, isNull);
    expect(s.submitting, false);
  });
}
