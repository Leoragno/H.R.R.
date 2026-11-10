// HEAT — forme. Niente angoli arrotondati: pannelli inclinati (parallelogrammi),
// card smussate su un angolo, emblemi esagonali. Ogni forma è un [ShapeBorder]
// così funziona sia come clip sia come bordo/ombra (ShapeDecoration).

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Parallelogramma: il lato sinistro rientra di [left] in alto, il destro
/// rientra di [right] in basso — `polygon(Lpx 0,100% 0,calc(100% - Rpx) 100%,0 100%)`.
/// Con `left: 0` o `right: 0` si ottengono i pannelli tagliati su un solo lato.
class SlantBorder extends OutlinedBorder {
  const SlantBorder({this.left = 10, this.right = 10, super.side});

  /// Pill inclinata simmetrica (bottoni, tab, chip).
  const SlantBorder.all(double cut, {BorderSide side = BorderSide.none})
      : this(left: cut, right: cut, side: side);

  final double left;
  final double right;

  Path _path(Rect r) => Path()
    ..moveTo(r.left + left, r.top)
    ..lineTo(r.right, r.top)
    ..lineTo(r.right - right, r.bottom)
    ..lineTo(r.left, r.bottom)
    ..close();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect.deflate(side.strokeInset));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(_path(rect.deflate(side.width / 2)), side.toPaint());
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) =>
      SlantBorder(left: left * t, right: right * t, side: side.scale(t));

  @override
  SlantBorder copyWith({BorderSide? side}) =>
      SlantBorder(left: left, right: right, side: side ?? this.side);
}

/// Card smussata: taglio a 45° in alto a destra (e opzionalmente in basso a
/// sinistra) di [cut] px.
class ChamferBorder extends OutlinedBorder {
  const ChamferBorder({this.cut = 14, this.bottomLeft = false, super.side});

  final double cut;
  final bool bottomLeft;

  Path _path(Rect r) {
    final p = Path()
      ..moveTo(r.left, r.top)
      ..lineTo(r.right - cut, r.top)
      ..lineTo(r.right, r.top + cut)
      ..lineTo(r.right, r.bottom);
    if (bottomLeft) {
      p
        ..lineTo(r.left + cut, r.bottom)
        ..lineTo(r.left, r.bottom - cut);
    } else {
      p.lineTo(r.left, r.bottom);
    }
    return p..close();
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect.deflate(side.strokeInset));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(_path(rect.deflate(side.width / 2)), side.toPaint());
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) =>
      ChamferBorder(cut: cut * t, bottomLeft: bottomLeft, side: side.scale(t));

  @override
  ChamferBorder copyWith({BorderSide? side}) =>
      ChamferBorder(cut: cut, bottomLeft: bottomLeft, side: side ?? this.side);
}

/// Emblema esagonale dei piloti:
/// `polygon(50% 0,100% 16%,100% 72%,50% 100%,0 72%,0 16%)`.
class HexEmblemBorder extends OutlinedBorder {
  const HexEmblemBorder({super.side});

  Path _path(Rect r) => Path()
    ..moveTo(r.left + r.width * .5, r.top)
    ..lineTo(r.right, r.top + r.height * .16)
    ..lineTo(r.right, r.top + r.height * .72)
    ..lineTo(r.left + r.width * .5, r.bottom)
    ..lineTo(r.left, r.top + r.height * .72)
    ..lineTo(r.left, r.top + r.height * .16)
    ..close();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect.deflate(side.strokeInset));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(_path(rect.deflate(side.width / 2)), side.toPaint());
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) => HexEmblemBorder(side: side.scale(t));

  @override
  HexEmblemBorder copyWith({BorderSide? side}) =>
      HexEmblemBorder(side: side ?? this.side);
}

/// Inclinazione delle barre segmentate (`skewX(-30deg)`).
final double kHeatBarSkew = math.tan(30 * math.pi / 180);
