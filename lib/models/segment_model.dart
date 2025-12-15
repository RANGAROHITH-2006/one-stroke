import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// Segment Model
/// Represents a path segment between two vertices with unique ID
/// Contains path metric information for accurate distance calculations
class SegmentModel {
  final int segmentId;
  final int startVertexId;
  final int endVertexId;
  final double length;
  final ui.PathMetric pathMetric;

  // Store actual start/end positions for quick reference
  final Offset startPosition;
  final Offset endPosition;

  // Store the offset along the parent PathMetric where this segment starts
  final double startOffsetOnPath;

  SegmentModel({
    required this.segmentId,
    required this.startVertexId,
    required this.endVertexId,
    required this.length,
    required this.pathMetric,
    required this.startPosition,
    required this.endPosition,
    this.startOffsetOnPath = 0.0,
  });

  /// Check if this segment connects to a specific vertex
  bool connectsToVertex(int vertexId) {
    return startVertexId == vertexId || endVertexId == vertexId;
  }

  /// Get the other vertex ID given one vertex ID
  int? getOtherVertexId(int vertexId) {
    if (startVertexId == vertexId) return endVertexId;
    if (endVertexId == vertexId) return startVertexId;
    return null;
  }

  /// Check if a point is near the start of this segment
  bool isNearStart(Offset point, {double tolerance = 15.0}) {
    return (point - startPosition).distance < tolerance;
  }

  /// Check if a point is near the end of this segment
  bool isNearEnd(Offset point, {double tolerance = 15.0}) {
    return (point - endPosition).distance < tolerance;
  }

  /// Get the closest point on this segment to a given point
  /// Returns null if point is not close enough to the segment
  /// Now properly handles segments that are portions of a larger PathMetric
  /// Uses adaptive sampling with finer steps at edges for better accuracy
  SegmentPosition? findClosestPosition(
    Offset point, {
    double tolerance = 16.0,
  }) {
    double? closestDistanceOnSegment;
    double minDist = double.infinity;

    // EXPLICIT ENDPOINT CHECKS with higher tolerance for edge accuracy
    double edgeTolerance = tolerance * 1.3;
    
    // Check start point
    final startDist = (point - startPosition).distance;
    if (startDist <= edgeTolerance) {
      closestDistanceOnSegment = 0.0;
      minDist = startDist;
    }
    
    // Check end point
    final endDist = (point - endPosition).distance;
    if (endDist <= edgeTolerance && endDist < minDist) {
      closestDistanceOnSegment = length;
      minDist = endDist;
    }

    // ADAPTIVE SAMPLING: Use finer steps at edges, normal steps in middle
    double edgeZone = length * 0.15; // First and last 15% of segment
    
    for (double localDist = 0; localDist <= length;) {
      final absoluteDist = startOffsetOnPath + localDist;

      // Make sure we don't exceed the PathMetric length
      if (absoluteDist > pathMetric.length) break;

      final tangent = pathMetric.getTangentForOffset(absoluteDist);
      if (tangent != null) {
        final currentDist = (point - tangent.position).distance;
        if (currentDist <= tolerance && currentDist < minDist) {
          minDist = currentDist;
          closestDistanceOnSegment = localDist;
        }
      }
      
      // Adaptive step size: 0.1px at edges, 0.3px in middle
      bool isAtEdge = localDist < edgeZone || localDist > (length - edgeZone);
      localDist += isAtEdge ? 0.1 : 0.3;
    }

    if (closestDistanceOnSegment != null) {
      return SegmentPosition(
        segmentId: segmentId,
        distanceAlongSegment: closestDistanceOnSegment,
        screenDistance: minDist,
      );
    }

    return null;
  }

  /// Get position along segment as a ratio (0.0 to 1.0)
  double getProgressRatio(double distanceAlongSegment) {
    if (length == 0) return 0.0;
    return (distanceAlongSegment / length).clamp(0.0, 1.0);
  }

  @override
  String toString() {
    return 'Segment(id: $segmentId, from: V$startVertexId, to: V$endVertexId, length: ${length.toStringAsFixed(1)})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SegmentModel && other.segmentId == segmentId;
  }

  @override
  int get hashCode => segmentId.hashCode;
}

/// Segment Position
/// Represents a specific position along a segment
class SegmentPosition {
  final int segmentId;
  final double distanceAlongSegment;
  final double screenDistance;

  SegmentPosition({
    required this.segmentId,
    required this.distanceAlongSegment,
    required this.screenDistance,
  });

  @override
  String toString() {
    return 'SegmentPosition(seg: $segmentId, dist: ${distanceAlongSegment.toStringAsFixed(1)}, screen: ${screenDistance.toStringAsFixed(1)})';
  }
}
