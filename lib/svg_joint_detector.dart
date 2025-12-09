import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;

/// A utility class for detecting joints (connection points) in SVG paths
class SvgJointDetector {
  /// Detects joints in an SVG path string
  ///
  /// [pathData] - The SVG path data string
  /// [includeControlPoints] - Whether to include control points from curves
  /// [duplicateTolerance] - Distance threshold for removing duplicate points
  ///
  /// Returns a list of Offset representing joint positions
  static List<Offset> detectJoints(
    String pathData, {
    bool includeControlPoints = true,
    double duplicateTolerance = 2.0,
  }) {
    final List<Offset> joints = [];
    double currentX = 0.0;
    double currentY = 0.0;
    double startX = 0.0;
    double startY = 0.0;
    double lastControlX = 0.0;
    double lastControlY = 0.0;
    bool lastWasCurve = false;

    // Regex to parse SVG path commands
    final commandRegex = RegExp(
      r'([MmLlHhVvCcSsQqTtAaZz])([^MmLlHhVvCcSsQqTtAaZz]*)',
    );
    final matches = commandRegex.allMatches(pathData);

    for (final match in matches) {
      final command = match.group(1)!;
      final params = match.group(2)!.trim();
      final numbers = _parseNumbers(params);

      switch (command) {
        // Move to (absolute)
        case 'M':
          for (int i = 0; i < numbers.length; i += 2) {
            currentX = numbers[i];
            currentY = numbers[i + 1];
            if (i == 0) {
              startX = currentX;
              startY = currentY;
            }
            joints.add(Offset(currentX, currentY));
          }
          lastWasCurve = false;
          break;

        // Move to (relative)
        case 'm':
          for (int i = 0; i < numbers.length; i += 2) {
            currentX += numbers[i];
            currentY += numbers[i + 1];
            if (i == 0 && joints.isEmpty) {
              startX = currentX;
              startY = currentY;
            }
            joints.add(Offset(currentX, currentY));
          }
          lastWasCurve = false;
          break;

        // Line to (absolute)
        case 'L':
          for (int i = 0; i < numbers.length; i += 2) {
            currentX = numbers[i];
            currentY = numbers[i + 1];
            joints.add(Offset(currentX, currentY));
          }
          lastWasCurve = false;
          break;

        // Line to (relative)
        case 'l':
          for (int i = 0; i < numbers.length; i += 2) {
            currentX += numbers[i];
            currentY += numbers[i + 1];
            joints.add(Offset(currentX, currentY));
          }
          lastWasCurve = false;
          break;

        // Horizontal line to (absolute)
        case 'H':
          for (final x in numbers) {
            currentX = x;
            joints.add(Offset(currentX, currentY));
          }
          lastWasCurve = false;
          break;

        // Horizontal line to (relative)
        case 'h':
          for (final dx in numbers) {
            currentX += dx;
            joints.add(Offset(currentX, currentY));
          }
          lastWasCurve = false;
          break;

        // Vertical line to (absolute)
        case 'V':
          for (final y in numbers) {
            currentY = y;
            joints.add(Offset(currentX, currentY));
          }
          lastWasCurve = false;
          break;

        // Vertical line to (relative)
        case 'v':
          for (final dy in numbers) {
            currentY += dy;
            joints.add(Offset(currentX, currentY));
          }
          lastWasCurve = false;
          break;

        // Cubic Bezier curve (absolute)
        case 'C':
          for (int i = 0; i < numbers.length; i += 6) {
            final cp1x = numbers[i];
            final cp1y = numbers[i + 1];
            final cp2x = numbers[i + 2];
            final cp2y = numbers[i + 3];
            final x = numbers[i + 4];
            final y = numbers[i + 5];

            if (includeControlPoints) {
              joints.add(Offset(cp1x, cp1y));
              joints.add(Offset(cp2x, cp2y));
            }

            currentX = x;
            currentY = y;
            lastControlX = cp2x;
            lastControlY = cp2y;
            joints.add(Offset(currentX, currentY));
          }
          lastWasCurve = true;
          break;

        // Cubic Bezier curve (relative)
        case 'c':
          for (int i = 0; i < numbers.length; i += 6) {
            final cp1x = currentX + numbers[i];
            final cp1y = currentY + numbers[i + 1];
            final cp2x = currentX + numbers[i + 2];
            final cp2y = currentY + numbers[i + 3];
            final x = currentX + numbers[i + 4];
            final y = currentY + numbers[i + 5];

            if (includeControlPoints) {
              joints.add(Offset(cp1x, cp1y));
              joints.add(Offset(cp2x, cp2y));
            }

            currentX = x;
            currentY = y;
            lastControlX = cp2x;
            lastControlY = cp2y;
            joints.add(Offset(currentX, currentY));
          }
          lastWasCurve = true;
          break;

        // Smooth cubic Bezier curve (absolute)
        case 'S':
          for (int i = 0; i < numbers.length; i += 4) {
            final cp1x = lastWasCurve ? 2 * currentX - lastControlX : currentX;
            final cp1y = lastWasCurve ? 2 * currentY - lastControlY : currentY;
            final cp2x = numbers[i];
            final cp2y = numbers[i + 1];
            final x = numbers[i + 2];
            final y = numbers[i + 3];

            if (includeControlPoints) {
              joints.add(Offset(cp1x, cp1y));
              joints.add(Offset(cp2x, cp2y));
            }

            currentX = x;
            currentY = y;
            lastControlX = cp2x;
            lastControlY = cp2y;
            joints.add(Offset(currentX, currentY));
          }
          lastWasCurve = true;
          break;

        // Smooth cubic Bezier curve (relative)
        case 's':
          for (int i = 0; i < numbers.length; i += 4) {
            final cp1x = lastWasCurve ? 2 * currentX - lastControlX : currentX;
            final cp1y = lastWasCurve ? 2 * currentY - lastControlY : currentY;
            final cp2x = currentX + numbers[i];
            final cp2y = currentY + numbers[i + 1];
            final x = currentX + numbers[i + 2];
            final y = currentY + numbers[i + 3];

            if (includeControlPoints) {
              joints.add(Offset(cp1x, cp1y));
              joints.add(Offset(cp2x, cp2y));
            }

            currentX = x;
            currentY = y;
            lastControlX = cp2x;
            lastControlY = cp2y;
            joints.add(Offset(currentX, currentY));
          }
          lastWasCurve = true;
          break;

        // Quadratic Bezier curve (absolute)
        case 'Q':
          for (int i = 0; i < numbers.length; i += 4) {
            final cpx = numbers[i];
            final cpy = numbers[i + 1];
            final x = numbers[i + 2];
            final y = numbers[i + 3];

            if (includeControlPoints) {
              joints.add(Offset(cpx, cpy));
            }

            currentX = x;
            currentY = y;
            lastControlX = cpx;
            lastControlY = cpy;
            joints.add(Offset(currentX, currentY));
          }
          lastWasCurve = true;
          break;

        // Quadratic Bezier curve (relative)
        case 'q':
          for (int i = 0; i < numbers.length; i += 4) {
            final cpx = currentX + numbers[i];
            final cpy = currentY + numbers[i + 1];
            final x = currentX + numbers[i + 2];
            final y = currentY + numbers[i + 3];

            if (includeControlPoints) {
              joints.add(Offset(cpx, cpy));
            }

            currentX = x;
            currentY = y;
            lastControlX = cpx;
            lastControlY = cpy;
            joints.add(Offset(currentX, currentY));
          }
          lastWasCurve = true;
          break;

        // Smooth quadratic Bezier curve (absolute)
        case 'T':
          for (int i = 0; i < numbers.length; i += 2) {
            final cpx = lastWasCurve ? 2 * currentX - lastControlX : currentX;
            final cpy = lastWasCurve ? 2 * currentY - lastControlY : currentY;
            final x = numbers[i];
            final y = numbers[i + 1];

            if (includeControlPoints) {
              joints.add(Offset(cpx, cpy));
            }

            currentX = x;
            currentY = y;
            lastControlX = cpx;
            lastControlY = cpy;
            joints.add(Offset(currentX, currentY));
          }
          lastWasCurve = true;
          break;

        // Smooth quadratic Bezier curve (relative)
        case 't':
          for (int i = 0; i < numbers.length; i += 2) {
            final cpx = lastWasCurve ? 2 * currentX - lastControlX : currentX;
            final cpy = lastWasCurve ? 2 * currentY - lastControlY : currentY;
            final x = currentX + numbers[i];
            final y = currentY + numbers[i + 1];

            if (includeControlPoints) {
              joints.add(Offset(cpx, cpy));
            }

            currentX = x;
            currentY = y;
            lastControlX = cpx;
            lastControlY = cpy;
            joints.add(Offset(currentX, currentY));
          }
          lastWasCurve = true;
          break;

        // Elliptical arc (absolute)
        case 'A':
          for (int i = 0; i < numbers.length; i += 7) {
            final rx = numbers[i];
            final ry = numbers[i + 1];
            final xAxisRotation = numbers[i + 2];
            final largeArcFlag = numbers[i + 3].toInt();
            final sweepFlag = numbers[i + 4].toInt();
            final x = numbers[i + 5];
            final y = numbers[i + 6];

            final arcPoints = _calculateArcPoints(
              currentX,
              currentY,
              rx,
              ry,
              xAxisRotation,
              largeArcFlag,
              sweepFlag,
              x,
              y,
            );

            if (includeControlPoints) {
              joints.addAll(arcPoints);
            }

            currentX = x;
            currentY = y;
            joints.add(Offset(currentX, currentY));
          }
          lastWasCurve = false;
          break;

        // Elliptical arc (relative)
        case 'a':
          for (int i = 0; i < numbers.length; i += 7) {
            final rx = numbers[i];
            final ry = numbers[i + 1];
            final xAxisRotation = numbers[i + 2];
            final largeArcFlag = numbers[i + 3].toInt();
            final sweepFlag = numbers[i + 4].toInt();
            final x = currentX + numbers[i + 5];
            final y = currentY + numbers[i + 6];

            final arcPoints = _calculateArcPoints(
              currentX,
              currentY,
              rx,
              ry,
              xAxisRotation,
              largeArcFlag,
              sweepFlag,
              x,
              y,
            );

            if (includeControlPoints) {
              joints.addAll(arcPoints);
            }

            currentX = x;
            currentY = y;
            joints.add(Offset(currentX, currentY));
          }
          lastWasCurve = false;
          break;

        // Close path
        case 'Z':
        case 'z':
          if (currentX != startX || currentY != startY) {
            currentX = startX;
            currentY = startY;
            joints.add(Offset(currentX, currentY));
          }
          lastWasCurve = false;
          break;
      }
    }

    final cleaned = _removeDuplicateJoints(joints, duplicateTolerance);
    return _removeCollinearPoints(cleaned, angleThreshold: 5.0);
  }

  /// Removes collinear points (points that don't change direction significantly)
  static List<Offset> _removeCollinearPoints(
    List<Offset> joints,
    {double angleThreshold = 5.0,
  }) {
    if (joints.length < 3) return joints;

    final result = <Offset>[joints.first];
    final threshold = angleThreshold * math.pi / 180; // Convert to radians

    for (int i = 1; i < joints.length - 1; i++) {
      final prev = joints[i - 1];
      final current = joints[i];
      final next = joints[i + 1];

      // Calculate vectors
      final v1 = Offset(current.dx - prev.dx, current.dy - prev.dy);
      final v2 = Offset(next.dx - current.dx, next.dy - current.dy);

      // Calculate angle between vectors
      final dot = v1.dx * v2.dx + v1.dy * v2.dy;
      final mag1 = math.sqrt(v1.dx * v1.dx + v1.dy * v1.dy);
      final mag2 = math.sqrt(v2.dx * v2.dx + v2.dy * v2.dy);

      if (mag1 > 0.01 && mag2 > 0.01) {
        final cosAngle = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
        final angle = math.acos(cosAngle);

        // Only keep points where direction changes significantly
        if (angle > threshold) {
          result.add(current);
        }
      }
    }

    result.add(joints.last);
    return result;
  }

  /// Parses a string of numbers into a list of doubles
  static List<double> _parseNumbers(String str) {
    if (str.isEmpty) return [];

    // Handle numbers with commas and spaces
    final cleanStr =
        str.replaceAll(',', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleanStr.isEmpty) return [];

    final numberRegex = RegExp(r'[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?');
    final matches = numberRegex.allMatches(cleanStr);

    return matches.map((m) => double.parse(m.group(0)!)).toList();
  }

  /// Removes duplicate joints that are within tolerance distance
  static List<Offset> _removeDuplicateJoints(
    List<Offset> joints,
    double tolerance,
  ) {
    if (joints.isEmpty) return [];

    final result = <Offset>[joints.first];

    for (int i = 1; i < joints.length; i++) {
      final current = joints[i];
      bool isDuplicate = false;

      // Check against all existing points, not just the last one
      for (final existing in result) {
        final distance = math.sqrt(
          math.pow(current.dx - existing.dx, 2) +
              math.pow(current.dy - existing.dy, 2),
        );

        if (distance <= tolerance) {
          isDuplicate = true;
          break;
        }
      }

      if (!isDuplicate) {
        result.add(current);
      }
    }

    return result;
  }

  /// Calculates approximate points along an elliptical arc
  static List<Offset> _calculateArcPoints(
    double x1,
    double y1,
    double rx,
    double ry,
    double xAxisRotation,
    int largeArcFlag,
    int sweepFlag,
    double x2,
    double y2,
  ) {
    if (rx == 0 || ry == 0) {
      return [];
    }

    final points = <Offset>[];
    final phi = xAxisRotation * math.pi / 180;
    final cosPhi = math.cos(phi);
    final sinPhi = math.sin(phi);

    // Convert to center parameterization
    final dx = (x1 - x2) / 2;
    final dy = (y1 - y2) / 2;
    final x1p = cosPhi * dx + sinPhi * dy;
    final y1p = -sinPhi * dx + cosPhi * dy;

    // Correct radii if needed
    var rxAbs = rx.abs();
    var ryAbs = ry.abs();
    final lambda =
        (x1p * x1p) / (rxAbs * rxAbs) + (y1p * y1p) / (ryAbs * ryAbs);

    if (lambda > 1) {
      rxAbs *= math.sqrt(lambda);
      ryAbs *= math.sqrt(lambda);
    }

    // Calculate center
    final sign = largeArcFlag != sweepFlag ? 1.0 : -1.0;
    final sq = math.max(
      0.0,
      (rxAbs * rxAbs * ryAbs * ryAbs -
              rxAbs * rxAbs * y1p * y1p -
              ryAbs * ryAbs * x1p * x1p) /
          (rxAbs * rxAbs * y1p * y1p + ryAbs * ryAbs * x1p * x1p),
    );

    final coef = sign * math.sqrt(sq);
    final cxp = coef * rxAbs * y1p / ryAbs;
    final cyp = -coef * ryAbs * x1p / rxAbs;

    final cx = cosPhi * cxp - sinPhi * cyp + (x1 + x2) / 2;
    final cy = sinPhi * cxp + cosPhi * cyp + (y1 + y2) / 2;

    // Sample points along the arc (simplified - just add center and midpoint)
    points.add(Offset(cx, cy));
    points.add(Offset((x1 + x2) / 2, (y1 + y2) / 2));

    return points;
  }

  /// Detects joints from a Flutter Path object
  static List<Offset> detectJointsFromPath(
    ui.Path path, {
    double duplicateTolerance = 2.0,
  }) {
    final joints = <Offset>[];
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      // Add start point
      final start = metric.getTangentForOffset(0.0)?.position;
      if (start != null) {
        joints.add(start);
      }

      // Sample points along the path
      final length = metric.length;
      final sampleCount = (length / 10).ceil().clamp(2, 100);

      for (int i = 1; i < sampleCount; i++) {
        final distance = (i / sampleCount) * length;
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          joints.add(tangent.position);
        }
      }

      // Add end point
      final end = metric.getTangentForOffset(length)?.position;
      if (end != null) {
        joints.add(end);
      }
    }

    return _removeDuplicateJoints(joints, duplicateTolerance);
  }

  /// Renders joints as dots on a canvas
  static void renderJoints(
    Canvas canvas,
    List<Offset> joints, {
    double radius = 5.0,
    Color color = Colors.red,
    double strokeWidth = 2.0,
  }) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final strokePaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;

    for (final joint in joints) {
      canvas.drawCircle(joint, radius, paint);
      canvas.drawCircle(joint, radius, strokePaint);
    }
  }

  /// Renders joints with labels for debugging
  static void renderJointsWithLabels(
    Canvas canvas,
    List<Offset> joints, {
    double radius = 5.0,
    Color color = Colors.red,
    TextStyle? textStyle,
  }) {
    renderJoints(canvas, joints, radius: radius, color: color);

    final style =
        textStyle ??
        const TextStyle(
          color: Colors.black,
          fontSize: 12,
          backgroundColor: Colors.white,
        );

    for (int i = 0; i < joints.length; i++) {
      final joint = joints[i];
      final textSpan = TextSpan(text: '$i', style: style);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(joint.dx + radius + 2, joint.dy - radius - 2),
      );
    }
  }

  /// Gets segments between consecutive joints
  static List<PathSegment> getSegments(List<Offset> joints) {
    final segments = <PathSegment>[];

    for (int i = 0; i < joints.length - 1; i++) {
      segments.add(PathSegment(start: joints[i], end: joints[i + 1], index: i));
    }

    return segments;
  }

  /// Analyzes path joints and returns detailed information
  static JointAnalysis analyzePathJoints(
    String pathData, {
    bool includeControlPoints = true,
    double duplicateTolerance = 2.0,
  }) {
    final joints = detectJoints(
      pathData,
      includeControlPoints: includeControlPoints,
      duplicateTolerance: duplicateTolerance,
    );

    final segments = getSegments(joints);

    double totalLength = 0.0;
    for (final segment in segments) {
      totalLength += segment.length;
    }

    Rect? boundingBox;
    if (joints.isNotEmpty) {
      double minX = joints.first.dx;
      double minY = joints.first.dy;
      double maxX = joints.first.dx;
      double maxY = joints.first.dy;

      for (final joint in joints) {
        minX = math.min(minX, joint.dx);
        minY = math.min(minY, joint.dy);
        maxX = math.max(maxX, joint.dx);
        maxY = math.max(maxY, joint.dy);
      }

      boundingBox = Rect.fromLTRB(minX, minY, maxX, maxY);
    }

    Offset? center;
    if (boundingBox != null) {
      center = boundingBox.center;
    }

    return JointAnalysis(
      joints: joints,
      segments: segments,
      totalLength: totalLength,
      boundingBox: boundingBox,
      center: center,
    );
  }
}

/// Represents a segment between two joints
class PathSegment {
  final Offset start;
  final Offset end;
  final int index;

  PathSegment({required this.start, required this.end, required this.index});

  /// Length of the segment
  double get length {
    return math.sqrt(
      math.pow(end.dx - start.dx, 2) + math.pow(end.dy - start.dy, 2),
    );
  }

  /// Direction vector (normalized)
  Offset get direction {
    final len = length;
    if (len == 0) return Offset.zero;
    return Offset((end.dx - start.dx) / len, (end.dy - start.dy) / len);
  }

  /// Angle in radians
  double get angle {
    return math.atan2(end.dy - start.dy, end.dx - start.dx);
  }

  /// Midpoint of the segment
  Offset get midpoint {
    return Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
  }
}

/// Analysis result containing joints and path information
class JointAnalysis {
  final List<Offset> joints;
  final List<PathSegment> segments;
  final double totalLength;
  final Rect? boundingBox;
  final Offset? center;

  JointAnalysis({
    required this.joints,
    required this.segments,
    required this.totalLength,
    this.boundingBox,
    this.center,
  });
}
