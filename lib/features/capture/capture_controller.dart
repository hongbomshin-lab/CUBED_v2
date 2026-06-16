import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 촬영 슬롯 — 순서 = 가이드 단계 순서(전체샷 → 원재료 → 영양성분).
enum CaptureSlot { full, ingredients, nutrition }

extension CaptureSlotLabel on CaptureSlot {
  String get title => switch (this) {
        CaptureSlot.full => '제품 전체 사진',
        CaptureSlot.ingredients => '원재료명',
        CaptureSlot.nutrition => '영양성분표',
      };
  String get hint => switch (this) {
        CaptureSlot.full => '제품 앞면 전체가 보이게 찍어주세요. 카테고리·제품명 판정에 쓰여요.',
        CaptureSlot.ingredients => '원재료명 부분이 또렷하게 보이도록 찍어주세요.',
        CaptureSlot.nutrition => '영양성분표가 정면으로, 숫자가 또렷하게 보이도록 찍어주세요.',
      };
}

@immutable
class CaptureState {
  final Map<CaptureSlot, Uint8List> images;
  final bool submitting;
  final String? error;
  const CaptureState({this.images = const {}, this.submitting = false, this.error});

  bool get isComplete => CaptureSlot.values.every(images.containsKey);
  int get count => images.length;

  CaptureState copyWith({
    Map<CaptureSlot, Uint8List>? images,
    bool? submitting,
    Object? error = _sentinel,
  }) {
    return CaptureState(
      images: images ?? this.images,
      submitting: submitting ?? this.submitting,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  static const _sentinel = Object();
}

class CaptureController extends StateNotifier<CaptureState> {
  CaptureController() : super(const CaptureState());

  void setImage(CaptureSlot slot, Uint8List bytes) {
    state = state.copyWith(images: {...state.images, slot: bytes}, error: null);
  }

  void removeImage(CaptureSlot slot) {
    final next = {...state.images}..remove(slot);
    state = state.copyWith(images: next);
  }

  void setSubmitting(bool v) => state = state.copyWith(submitting: v);
  void setError(String? e) => state = state.copyWith(error: e, submitting: false);
  void reset() => state = const CaptureState();
}

/// prefillBarcode마다 독립 인스턴스. autoDispose로 화면 이탈 시 정리.
final captureControllerProvider =
    StateNotifierProvider.autoDispose<CaptureController, CaptureState>(
  (ref) => CaptureController(),
);
