// lib/domain/gaze/calibration.dart
// 9점 보정: raw(0..1) -> screen(0..1) 선형(아핀) 맵핑. 최소자승.
// 참고: 간단 아핀(2x3)으로 왜곡 1차 보정. 2차 항은 선택(미구현).

import 'dart:convert';

class Calibration {
  // 아핀 변환 파라미터: x' = ax*x + bx*y + cx, y' = ay*x + by*y + cy
  final List<double> a; // length 6
  Calibration(this.a);

  Map<String, dynamic> toJson() => {'a': a};
  static Calibration fromJson(Map<String, dynamic> j) => Calibration((j['a'] as List).cast<double>());
  static Calibration? tryParse(String? jsonStr) {
    if (jsonStr == null) return null;
    try {
      return Calibration.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // 매핑
  List<double> map(double rx, double ry) {
    final nx = (a[0] * rx + a[1] * ry + a[2]).clamp(0.0, 1.0);
    final ny = (a[3] * rx + a[4] * ry + a[5]).clamp(0.0, 1.0);
    return [nx, ny];
  }

  // 표본으로부터 최소자승 아핀 계산
  static Calibration solve(List<List<double>> raw, List<List<double>> screen) {
    // raw[i] = [x,y], screen[i] = [X,Y]
    final n = raw.length;
    // Normal equations for Ax=b, where A: n x 3 for x and y stacked separately.
    // We compute [ax bx cx] and [ay by cy]
    double sxx = 0, sxy = 0, sx1 = 0;
    double syx = 0, syy = 0, sy1 = 0;
    double s1x = 0, s1y = 0, s11 = 0;
    double bx = 0, by = 0, cx = 0, cy = 0; // will be reused
    double txx = 0, txy = 0, tx1 = 0; // for target X
    double tyx = 0, tyy = 0, ty1 = 0; // for target Y

    for (var i = 0; i < n; i++) {
      final x = raw[i][0];
      final y = raw[i][1];
      final X = screen[i][0];
      final Y = screen[i][1];
      sxx += x * x;
      sxy += x * y;
      sx1 += x;
      syx += y * x;
      syy += y * y;
      sy1 += y;
      s1x += x;
      s1y += y;
      s11 += 1;
      txx += x * X;
      txy += y * X;
      tx1 += X;
      tyx += x * Y;
      tyy += y * Y;
      ty1 += Y;
    }

    // Build 3x3 normal matrix M and vectors vx, vy
    final M = [
      [sxx, sxy, sx1],
      [syx, syy, sy1],
      [s1x, s1y, s11],
    ];
    final vx = [txx, txy, tx1];
    final vy = [tyx, tyy, ty1];

    final inv = _invert3x3(M);
    final ax = _mulMatVec(inv, vx);
    final ay = _mulMatVec(inv, vy);
    return Calibration([ax[0], ax[1], ax[2], ay[0], ay[1], ay[2]]);
  }

  static List<double> _mulMatVec(List<List<double>> m, List<double> v) {
    return [
      m[0][0] * v[0] + m[0][1] * v[1] + m[0][2] * v[2],
      m[1][0] * v[0] + m[1][1] * v[1] + m[1][2] * v[2],
      m[2][0] * v[0] + m[2][1] * v[1] + m[2][2] * v[2],
    ];
  }

  static List<List<double>> _invert3x3(List<List<double>> m) {
    final a = m[0][0], b = m[0][1], c = m[0][2];
    final d = m[1][0], e = m[1][1], f = m[1][2];
    final g = m[2][0], h = m[2][1], i = m[2][2];
    final A = (e * i - f * h);
    final B = -(d * i - f * g);
    final C = (d * h - e * g);
    final D = -(b * i - c * h);
    final E = (a * i - c * g);
    final F = -(a * h - b * g);
    final G = (b * f - c * e);
    final H = -(a * f - c * d);
    final I = (a * e - b * d);
    final det = a * A + b * B + c * C;
    final invDet = 1.0 / (det == 0 ? 1e-12 : det);
    return [
      [A * invDet, D * invDet, G * invDet],
      [B * invDet, E * invDet, H * invDet],
      [C * invDet, F * invDet, I * invDet],
    ];
  }
}

