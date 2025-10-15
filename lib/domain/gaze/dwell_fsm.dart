// lib/domain/gaze/dwell_fsm.dart
// 응시(Dwell) 상태 머신: Idle -> Gazing -> Confirming -> Triggered

enum DwellPhase { idle, gazing, confirming, triggered }

class DwellState {
  final DwellPhase phase;
  final String? targetId;
  final double progress; // 0..1 (confirming 진행률)
  DwellState(this.phase, this.targetId, this.progress);
}

class DwellFsm {
  String? _currentTarget;
  DateTime? _confirmStart;

  DwellState update({required String? hitTargetId, required int dwellMs}) {
    final now = DateTime.now();
    if (hitTargetId == null) {
      _currentTarget = null;
      _confirmStart = null;
      return DwellState(DwellPhase.idle, null, 0);
    }
    if (_currentTarget != hitTargetId) {
      _currentTarget = hitTargetId;
      _confirmStart = now;
      return DwellState(DwellPhase.gazing, _currentTarget, 0);
    }
    // same target
    if (_confirmStart == null) {
      _confirmStart = now;
      return DwellState(DwellPhase.gazing, _currentTarget, 0);
    }
    final elapsed = now.difference(_confirmStart!).inMilliseconds;
    final p = (elapsed / dwellMs).clamp(0.0, 1.0);
    if (elapsed >= dwellMs) {
      // Triggered: 호출부에서 처리 후 상태를 초기화할지 다음 프레임에 맡길지 결정
      return DwellState(DwellPhase.triggered, _currentTarget, 1.0);
    }
    return DwellState(DwellPhase.confirming, _currentTarget, p.toDouble());
  }

  void reset() {
    _currentTarget = null;
    _confirmStart = null;
  }
}

