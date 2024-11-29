import 'dart:math';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';

class EditActionDetails {
  EditorConfig? config;
  Rect? _layoutRect;

  Rect? get layoutRect => _layoutRect;
  Rect? _screenDestinationRect;
  Rect? _rawDestinationRect;

  double totalScale = 1.0;
  double preTotalScale = 1.0;

  Offset delta = Offset.zero;
  Offset? screenFocalPoint;
  EdgeInsets? cropRectPadding;
  Rect? cropRect;

  /// aspect ratio of image
  double? originalAspectRatio;

  ///  aspect ratio of crop rect

  double? _cropAspectRatio;

  /// the original aspect ratio
  double? get originalCropAspectRatio => _cropAspectRatio;

  /// current aspect ratio of crop rect
  double? get cropAspectRatio {
    if (_cropAspectRatio != null && _cropAspectRatio! <= 0) {
      return originalAspectRatio;
    }
    return _cropAspectRatio;
  }

  set cropAspectRatio(double? value) {
    if (_cropAspectRatio != value) {
      _cropAspectRatio = value;
    }
  }

  /// image
  Rect? get screenDestinationRect => _screenDestinationRect;

  void setScreenDestinationRect(Rect value) {
    _screenDestinationRect = value;
  }

  double _rotateRadians = 0.0;

  double get rotateRadians => _rotateRadians;

  set rotateRadians(double value) {
    // ingore precisionErrorTolerance
    if (value != 0.0 && value.isZero) {
      value = 0.0;
    }
    _rotateRadians = value;
  }

  double _rectRotateRadians = 0.0;

  double get rectRotateRadians => _rectRotateRadians;

  set rectRotateRadians(double value) {
    if (value != 0.0 && value.isZero) {
      value = 0.0;
    }
    _rectRotateRadians = value;
  }

  double rotationYRadians = 0.0;

  bool get hasRotateDegrees => !isTwoPi;

  bool get hasEditAction => hasRotateDegrees || rotationYRadians != 0;

  bool get needCrop => screenCropRect != screenDestinationRect;

  double get rotateDegrees => degrees(rotateRadians);

  bool get needFlip => rotationYRadians != 0;

  bool get flipY => rotationYRadians != 0;

  bool get isHalfPi => (rotateRadians % (2 * pi)) == pi / 2;

  bool get isPi => (rotateRadians % (2 * pi)) == pi;

  bool get isTwoPi => (rotateRadians % (2 * pi)) == 0;

  /// destination rect base on layer
  Rect? get layerDestinationRect => screenDestinationRect?.shift(-layoutTopLeft!);

  Offset? get layoutTopLeft => _layoutRect?.topLeft;

  Rect? get rawDestinationRect => _rawDestinationRect;

  Rect? get screenCropRect => cropRect?.shift(layoutTopLeft!);

  Rect? get cropRectLayoutRect {
    if (cropRectPadding != null) {
      return cropRectPadding!.deflateRect(_layoutRect!).shift(-layoutTopLeft!);
    }
    return _layoutRect?.shift(-layoutTopLeft!);
  }

  Offset? get cropRectLayoutRectCenter => cropRectLayoutRect?.center;

  void initRect(Rect layoutRect, Rect destinationRect) {
    if (_layoutRect != layoutRect) {
      _layoutRect = layoutRect;
      _screenDestinationRect = null;
    }

    if (_rawDestinationRect != destinationRect) {
      _rawDestinationRect = destinationRect;
      _screenDestinationRect = null;
    }
  }

  Rect getFinalDestinationRect() {
    if (screenDestinationRect != null) {
      /// scale
      final double scaleDelta = totalScale / preTotalScale;
      if (scaleDelta != 1.0) {
        Offset focalPoint = screenFocalPoint ?? _screenDestinationRect!.center;

        focalPoint = Offset(
          focalPoint.dx.clamp(_screenDestinationRect!.left, _screenDestinationRect!.right).toDouble(),
          focalPoint.dy.clamp(_screenDestinationRect!.top, _screenDestinationRect!.bottom).toDouble(),
        );

        _screenDestinationRect = Rect.fromLTWH(
            focalPoint.dx - (focalPoint.dx - _screenDestinationRect!.left) * scaleDelta,
            focalPoint.dy - (focalPoint.dy - _screenDestinationRect!.top) * scaleDelta,
            _screenDestinationRect!.width * scaleDelta,
            _screenDestinationRect!.height * scaleDelta);

        preTotalScale = totalScale;

        delta = Offset.zero;
      }

      /// move
      else {
        if (_screenDestinationRect != screenCropRect) {
          _screenDestinationRect = _screenDestinationRect!.shift(delta);
        }
        // we have shift offset, we should clear delta.
        delta = Offset.zero;
      }
    } else {
      _screenDestinationRect = getRectWithScale(
        _rawDestinationRect!,
        totalScale,
      );
    }
    return _screenDestinationRect!;
  }

  Rect getRectWithScale(Rect rect, double totalScale) {
    final double width = rect.width * totalScale;
    final double height = rect.height * totalScale;
    final Offset center = rect.center;
    return Rect.fromLTWH(center.dx - width / 2.0, center.dy - height / 2.0, width, height);
  }

  /// The path of the processed image, displayed on the screen
  ///
  Path getImagePath({Rect? rect}) {
    rect ??= _screenDestinationRect!;

    final Matrix4 result = getTransform();
    final List<Offset> corners = <Offset>[
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ];
    final List<Offset> rotatedCorners = corners.map((Offset corner) {
      final Vector4 cornerVector = Vector4(corner.dx, corner.dy, 0.0, 1.0);
      final Vector4 newCornerVector = result.transform(cornerVector);
      return Offset(newCornerVector.x, newCornerVector.y);
    }).toList();

    return Path()
      ..moveTo(rotatedCorners[0].dx, rotatedCorners[0].dy)
      ..lineTo(rotatedCorners[1].dx, rotatedCorners[1].dy)
      ..lineTo(rotatedCorners[2].dx, rotatedCorners[2].dy)
      ..lineTo(rotatedCorners[3].dx, rotatedCorners[3].dy)
      ..close();
  }

  Rect rotateRect(Rect rect, Offset center, double angle) {
    final Offset leftTop = rotateOffset(rect.topLeft, center, angle);
    final Offset bottomRight = rotateOffset(rect.bottomRight, center, angle);
    return Rect.fromPoints(leftTop, bottomRight);
  }

  Offset rotateOffset(Offset input, Offset center, double angle) {
    final double x = input.dx;
    final double y = input.dy;
    final double rx0 = center.dx;
    final double ry0 = center.dy;
    final double x0 = (x - rx0) * cos(angle) - (y - ry0) * sin(angle) + rx0;
    final double y0 = (x - rx0) * sin(angle) + (y - ry0) * cos(angle) + ry0;
    return Offset(x0, y0);
  }

  Matrix4 getTransform({Offset? center}) {
    final Offset origin = center ?? _layoutRect?.center ?? _screenDestinationRect!.center;
    final Matrix4 result = Matrix4.identity();

    result.translate(
      origin.dx,
      origin.dy,
    );
    if (rotationYRadians != 0) {
      result.multiply(Matrix4.rotationY(rotationYRadians));
    }
    if (hasRotateDegrees) {
      result.multiply(Matrix4.rotationZ(rotateRadians));
    }

    result.translate(-origin.dx, -origin.dy);

    return result;
  }

  double reverseRotateRadians(double rotateRadians) {
    return rotationYRadians == 0 ? rotateRadians : -rotateRadians;
  }

  void updateRotateRadians(double rotateRadians, double maxScale, {bool zoomInOnly = false}) {
    this.rotateRadians = rotateRadians;
    scaleToFitRect(maxScale, zoomInOnly: zoomInOnly);
  }

  void scaleToFitRect(double maxScale, {bool zoomInOnly = false}) {
    double scaleDelta = scaleToFitCropRect();

    if (scaleDelta > 0) {
      // can't scale image
      // so we should scale the crop rect
      if (totalScale * scaleDelta > maxScale) {
        screenFocalPoint = null;
        preTotalScale = totalScale;
        totalScale = maxScale;
        getFinalDestinationRect();
        scaleDelta = scaleToFitImageRect();
        if (scaleDelta > 0) {
          cropRect = Rect.fromCenter(
            center: cropRect!.center,
            width: cropRect!.width * scaleDelta,
            height: cropRect!.height * scaleDelta,
          );
        } else {
          updateDelta(Offset.zero);
        }
      } else if ((zoomInOnly && scaleDelta > 1.0) || !zoomInOnly) {
        screenFocalPoint = null;
        preTotalScale = totalScale;
        totalScale = totalScale * scaleDelta;
      }
    }
  }

  double scaleToFitCropRect() {
    final Matrix4 result = getTransform();
    result.invert();
    final Rect rect = _screenDestinationRect!;
    final List<Offset> rectVertices = <Offset>[
      screenCropRect!.topLeft,
      screenCropRect!.topRight,
      screenCropRect!.bottomRight,
      screenCropRect!.bottomLeft,
    ].map((Offset element) {
      final Vector4 cornerVector = Vector4(element.dx, element.dy, 0.0, 1.0);
      final Vector4 newCornerVector = result.transform(cornerVector);
      return Offset(newCornerVector.x, newCornerVector.y);
    }).toList();

    final double scaleDelta = scaleToFit(
      rectVertices,
      rect,
    );
    return scaleDelta;
  }

  double scaleToFit(
    List<Offset> rectVertices,
    Rect rect,
  ) {
    double scaleDelta = 0.0;
    final Offset center = rect.center;

    for (final Offset element in rectVertices) {
      final double x = (element.dx - center.dx).abs();
      final double y = (element.dy - center.dy).abs();
      final double halfWidth = rect.width / 2;
      final double halfHeight = rect.height / 2;

      scaleDelta = max(scaleDelta, max(x / halfWidth, y / halfHeight));
    }

    return scaleDelta;
  }

  double scaleToFitImageRect() {
    final Matrix4 result = getTransform();
    result.invert();
    final Rect rect = _screenDestinationRect!;
    final List<Offset> rectVertices = <Offset>[
      screenCropRect!.topLeft,
      screenCropRect!.topRight,
      screenCropRect!.bottomRight,
      screenCropRect!.bottomLeft,
    ].map((Offset element) {
      final Vector4 cornerVector = Vector4(element.dx, element.dy, 0.0, 1.0);
      final Vector4 newCornerVector = result.transform(cornerVector);
      return Offset(newCornerVector.x, newCornerVector.y);
    }).toList();

    final double scaleDelta = _scaleToFitImageRect(
      rectVertices,
      rect,
      rect.center,
    );
    return scaleDelta;
  }

  double _scaleToFitImageRect(
    List<Offset> rectVertices,
    Rect rect,
    Offset center,
  ) {
    double scaleDelta = double.maxFinite;
    final Offset cropRectCenter = (rectVertices[0] + (rectVertices[2])) / 2;
    int contains = 0;
    for (final Offset element in rectVertices) {
      if (rect.containsOffset(element)) {
        contains++;
        continue;
      }
      final List<Offset> list = getLineRectIntersections(rect, element, cropRectCenter);
      if (list.isNotEmpty) {
        scaleDelta = min(
            scaleDelta,
            sqrt(pow(list[0].dx - cropRectCenter.dx, 2) + pow(list[0].dy - cropRectCenter.dy, 2)) /
                sqrt(pow(element.dx - cropRectCenter.dx, 2) + pow(element.dy - cropRectCenter.dy, 2)));
      }
    }
    if (contains == 4 || scaleDelta == double.maxFinite) {
      return -1;
    }
    return scaleDelta;
  }

  void updateDelta(Offset delta) {
    double dx = delta.dx;
    final double dy = delta.dy;
    if (rotationYRadians == pi) {
      dx = -dx;
    }
    final double transformedDx = dx * cos(rotateRadians) + dy * sin(rotateRadians);
    final double transformedDy = dy * cos(rotateRadians) - dx * sin(rotateRadians);

    Offset offset = Offset(transformedDx, transformedDy);
    Rect rect = _screenDestinationRect!.shift(offset);

    final Matrix4 result = getTransform();
    result.invert();
    final List<Offset> rectVertices = <Offset>[
      screenCropRect!.topLeft,
      screenCropRect!.topRight,
      screenCropRect!.bottomRight,
      screenCropRect!.bottomLeft,
    ].map((Offset element) {
      final Vector4 cornerVector = Vector4(element.dx, element.dy, 0.0, 1.0);
      final Vector4 newCornerVector = result.transform(cornerVector);
      return Offset(newCornerVector.x, newCornerVector.y);
    }).toList();

    for (final Offset element in rectVertices) {
      if (rect.containsOffset(element)) {
        continue;
      }

      // find nearest point on rect
      final double nearestX = element.dx.clamp(rect.left, rect.right);
      final double nearestY = element.dy.clamp(rect.top, rect.bottom);

      final Offset nearestOffset = Offset(nearestX, nearestY);

      if (nearestOffset != element) {
        offset -= nearestOffset - element;
        rect = _screenDestinationRect = _screenDestinationRect!.shift(offset);
        // clear
        offset = Offset.zero;
      }
    }

    this.delta += offset;
  }

  void updateScale(double totalScale) {
    final double scaleDelta = totalScale / preTotalScale;
    if (scaleDelta == 1.0) {
      return;
    }
    final Matrix4 result = getTransform();
    result.invert();
    final List<Offset> rectVertices = <Offset>[
      screenCropRect!.topLeft,
      screenCropRect!.topRight,
      screenCropRect!.bottomRight,
      screenCropRect!.bottomLeft,
    ].map((Offset element) {
      final Vector4 cornerVector = Vector4(element.dx, element.dy, 0.0, 1.0);
      final Vector4 newCornerVector = result.transform(cornerVector);
      return Offset(newCornerVector.x, newCornerVector.y);
    }).toList();

    Offset focalPoint = screenFocalPoint ?? _screenDestinationRect!.center;

    focalPoint = Offset(
      focalPoint.dx.clamp(_screenDestinationRect!.left, _screenDestinationRect!.right).toDouble(),
      focalPoint.dy.clamp(_screenDestinationRect!.top, _screenDestinationRect!.bottom).toDouble(),
    );

    Rect rect = Rect.fromLTWH(
        focalPoint.dx - (focalPoint.dx - _screenDestinationRect!.left) * scaleDelta,
        focalPoint.dy - (focalPoint.dy - _screenDestinationRect!.top) * scaleDelta,
        _screenDestinationRect!.width * scaleDelta,
        _screenDestinationRect!.height * scaleDelta);
    bool fixed = false;
    for (final Offset element in rectVertices) {
      if (rect.containsOffset(element)) {
        continue;
      }
      // find nearest point on rect
      final double nearestX = element.dx.clamp(rect.left, rect.right);
      final double nearestY = element.dy.clamp(rect.top, rect.bottom);

      final Offset nearestOffset = Offset(nearestX, nearestY);

      if (nearestOffset != element) {
        fixed = true;
        rect = rect.shift(-(nearestOffset - element));
      }
    }

    for (final Offset element in rectVertices) {
      if (!rect.containsOffset(element)) {
        return;
      }
    }
    if (fixed == true) {
      _screenDestinationRect = rect;
      // scale has already apply
      preTotalScale = totalScale;
    }

    this.totalScale = totalScale;
  }

  Rect updateCropRect(Rect cropRect) {
    // 将裁剪框转换到屏幕坐标
    final Rect screenCropRect = cropRect.shift(layoutTopLeft!);

    // 获取旋转后的图像矩形顶点
    final Rect imageRect = _screenDestinationRect!;
    final List<Offset> imageVertices = <Offset>[
      imageRect.topLeft,
      imageRect.topRight,
      imageRect.bottomRight,
      imageRect.bottomLeft,
    ];

    // 获取旋转后的图像边界
    final Matrix4 transformMatrix = getTransform();
    final List<Offset> rotatedImageVertices = imageVertices.map((Offset vertex) {
      final Vector4 vector = Vector4(vertex.dx, vertex.dy, 0.0, 1.0);
      final Vector4 transformed = transformMatrix.transform(vector);
      return Offset(transformed.x, transformed.y);
    }).toList();

    // 使用旋转后的图像顶点创建一个路径，表示旋转后的图像区域
    final Path rotatedImagePath = Path()..addPolygon(rotatedImageVertices, true);

    // 检查裁剪框是否完全在图片范围内
    final List<Offset> cropVertices = <Offset>[
      screenCropRect.topLeft,
      screenCropRect.topRight,
      screenCropRect.bottomRight,
      screenCropRect.bottomLeft,
    ];

    final bool isInside = cropVertices.every((Offset vertex) => rotatedImagePath.contains(vertex)); // 判断所有顶点是否都在图片内

    if (!isInside) {
      return this.cropRect!;
    } else {
      return cropRect;
    }
  }

  Offset? getIntersection(Offset p1, Offset p2, Offset p3, Offset p4) {
    final double s1X = p2.dx - p1.dx;
    final double s1Y = p2.dy - p1.dy;
    final double s2X = p4.dx - p3.dx;
    final double s2Y = p4.dy - p3.dy;

    final double s = (-s1Y * (p1.dx - p3.dx) + s1X * (p1.dy - p3.dy)) / (-s2X * s1Y + s1X * s2Y);
    final double t = (s2X * (p1.dy - p3.dy) - s2Y * (p1.dx - p3.dx)) / (-s2X * s1Y + s1X * s2Y);

    if (s >= 0 && s <= 1 && t >= 0 && t <= 1) {
      final double intersectionX = p1.dx + (t * s1X);
      final double intersectionY = p1.dy + (t * s1Y);
      return Offset(intersectionX, intersectionY);
    }

    return null;
  }

  List<Offset> getLineRectIntersections(Rect rect, Offset p1, Offset p2) {
    final List<Offset> intersections = <Offset>[];

    final Offset topLeft = Offset(rect.left, rect.top);
    final Offset topRight = Offset(rect.right, rect.top);
    final Offset bottomLeft = Offset(rect.left, rect.bottom);
    final Offset bottomRight = Offset(rect.right, rect.bottom);

    final Offset? topIntersection = getIntersection(p1, p2, topLeft, topRight);
    if (topIntersection != null) {
      intersections.add(topIntersection);
    }

    final Offset? bottomIntersection = getIntersection(p1, p2, bottomLeft, bottomRight);
    if (bottomIntersection != null) {
      intersections.add(bottomIntersection);
    }

    final Offset? leftIntersection = getIntersection(p1, p2, topLeft, bottomLeft);
    if (leftIntersection != null) {
      intersections.add(leftIntersection);
    }

    final Offset? rightIntersection = getIntersection(p1, p2, topRight, bottomRight);
    if (rightIntersection != null) {
      intersections.add(rightIntersection);
    }

    return intersections;
  }

  ///  The copyWith method allows you to create a modified copy of an instance.
  EditActionDetails copyWith({
    Rect? layoutRect,
    Rect? screenDestinationRect,
    Rect? rawDestinationRect,
    double? totalScale,
    double? preTotalScale,
    Offset? delta,
    Offset? screenFocalPoint,
    EdgeInsets? cropRectPadding,
    Rect? cropRect,
    double? originalAspectRatio,
    double? cropAspectRatio,
    double? rotateRadians,
    double? rotationYRadians,
  }) {
    return EditActionDetails()
      .._layoutRect = layoutRect ?? _layoutRect
      .._screenDestinationRect = screenDestinationRect ?? _screenDestinationRect
      .._rawDestinationRect = rawDestinationRect ?? _rawDestinationRect
      ..totalScale = totalScale ?? this.totalScale
      ..preTotalScale = preTotalScale ?? this.preTotalScale
      ..delta = delta ?? this.delta
      ..screenFocalPoint = screenFocalPoint ?? this.screenFocalPoint
      ..cropRectPadding = cropRectPadding ?? this.cropRectPadding
      ..cropRect = cropRect ?? this.cropRect
      ..originalAspectRatio = originalAspectRatio ?? this.originalAspectRatio
      ..cropAspectRatio = cropAspectRatio ?? _cropAspectRatio
      ..rotateRadians = rotateRadians ?? this.rotateRadians
      ..rotationYRadians = rotationYRadians ?? this.rotationYRadians
      ..config = config;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is EditActionDetails &&
        _layoutRect.isSame(other._layoutRect) &&
        _screenDestinationRect.isSame(other._screenDestinationRect) &&
        _rawDestinationRect.isSame(other._rawDestinationRect) &&
        totalScale.equalTo(other.totalScale) &&
        preTotalScale.equalTo(other.preTotalScale) &&
        delta.isSame(other.delta) &&
        // screenFocalPoint == other.screenFocalPoint &&
        cropRectPadding == other.cropRectPadding &&
        cropRect.isSame(other.cropRect) &&
        originalAspectRatio.equalTo(other.originalAspectRatio) &&
        cropAspectRatio.equalTo(other.cropAspectRatio) &&
        rotateRadians.equalTo(other.rotateRadians) &&
        rotationYRadians.equalTo(other.rotationYRadians);
  }

  @override
  int get hashCode {
    return _layoutRect.hashCode ^
        _screenDestinationRect.hashCode ^
        _rawDestinationRect.hashCode ^
        totalScale.hashCode ^
        preTotalScale.hashCode ^
        delta.hashCode ^
        // screenFocalPoint.hashCode ^
        cropRectPadding.hashCode ^
        cropRect.hashCode ^
        originalAspectRatio.hashCode ^
        cropAspectRatio.hashCode ^
        rotateRadians.hashCode ^
        rotationYRadians.hashCode;
  }
}
