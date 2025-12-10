import 'package:flutter/material.dart';
import 'package:singlelinedraw/models/vertex_model.dart';
import 'package:singlelinedraw/models/segment_model.dart';
import 'dart:ui' as ui;

/// Connection Graph
/// Builds and manages the vertex-segment connectivity graph
/// Provides methods for querying connections and transitions
class ConnectionGraph {
  final Map<int, VertexModel> vertices;
  final Map<int, SegmentModel> segments;

  // Quick lookup maps
  final Map<int, Set<int>> _vertexToSegments = {};
  final Map<int, Set<int>> _segmentToVertices = {};

  ConnectionGraph({required this.vertices, required this.segments}) {
    _buildConnectivityMaps();
  }

  /// Build internal connectivity maps for fast lookups
  void _buildConnectivityMaps() {
    _vertexToSegments.clear();
    _segmentToVertices.clear();

    // Build vertex-to-segments map
    for (var segment in segments.values) {
      _vertexToSegments
          .putIfAbsent(segment.startVertexId, () => {})
          .add(segment.segmentId);
      _vertexToSegments
          .putIfAbsent(segment.endVertexId, () => {})
          .add(segment.segmentId);

      _segmentToVertices.putIfAbsent(segment.segmentId, () => {})
        ..add(segment.startVertexId)
        ..add(segment.endVertexId);
    }
  }

  /// Get all segments connected to a vertex
  Set<int> getSegmentsAtVertex(int vertexId) {
    return _vertexToSegments[vertexId] ?? {};
  }

  /// Get all vertices of a segment
  Set<int> getVerticesOfSegment(int segmentId) {
    return _segmentToVertices[segmentId] ?? {};
  }

  /// Find connected segments from a given segment at a specific position
  /// Returns segments that share a vertex with the current segment at the position
  List<int> findConnectedSegments(
    int currentSegmentId,
    double distanceAlongSegment,
  ) {
    final segment = segments[currentSegmentId];
    if (segment == null) return [];

    // Determine which vertex we're near
    int? nearVertexId;
    if (distanceAlongSegment < 15.0) {
      nearVertexId = segment.startVertexId;
    } else if (distanceAlongSegment > segment.length - 15.0) {
      nearVertexId = segment.endVertexId;
    }

    if (nearVertexId == null) return [];

    // Get all segments at this vertex, excluding current segment
    final connectedSegments =
        getSegmentsAtVertex(
          nearVertexId,
        ).where((id) => id != currentSegmentId).toList();

    return connectedSegments;
  }

  /// Check if two segments are connected (share a vertex)
  bool areSegmentsConnected(int segmentId1, int segmentId2) {
    final vertices1 = getVerticesOfSegment(segmentId1);
    final vertices2 = getVerticesOfSegment(segmentId2);

    return vertices1.intersection(vertices2).isNotEmpty;
  }

  /// Find the vertex ID that connects two segments
  int? getConnectingVertex(int segmentId1, int segmentId2) {
    final vertices1 = getVerticesOfSegment(segmentId1);
    final vertices2 = getVerticesOfSegment(segmentId2);

    final intersection = vertices1.intersection(vertices2);
    return intersection.isEmpty ? null : intersection.first;
  }

  /// Get the nearest vertex to a point
  VertexModel? getNearestVertex(Offset point, {double tolerance = 20.0}) {
    VertexModel? nearest;
    double minDist = double.infinity;

    for (var vertex in vertices.values) {
      final dist = (vertex.position - point).distance;
      if (dist < tolerance && dist < minDist) {
        minDist = dist;
        nearest = vertex;
      }
    }

    return nearest;
  }

  /// Print debug information about the graph structure
  void printDebugInfo() {
    print('\n========== CONNECTION GRAPH DEBUG ==========');
    print('Total Vertices: ${vertices.length}');
    print('Total Segments: ${segments.length}');

    print('\n--- VERTICES ---');
    for (var vertex in vertices.values) {
      print(vertex.toString());
    }

    print('\n--- SEGMENTS ---');
    for (var segment in segments.values) {
      print(segment.toString());
    }

    print('\n--- CONNECTIVITY MAP ---');
    for (var entry in _vertexToSegments.entries) {
      print('Vertex ${entry.key} → Segments ${entry.value}');
    }

    print('\n--- VERTEX DEGREES ---');
    for (var vertex in vertices.values) {
      final degree = getSegmentsAtVertex(vertex.vertexId).length;
      print(
        'Vertex ${vertex.vertexId}: degree $degree ${degree == 1
            ? "(endpoint)"
            : degree == 2
            ? "(path)"
            : "(junction)"}',
      );
    }

    print('============================================\n');
  }
}

/// Graph Builder
/// Static methods to build the connection graph from path data
class GraphBuilder {
  /// Build a complete connection graph from path metrics and vertices
  /// Splits path metrics at vertex positions to create proper segments
  static ConnectionGraph buildFromPath(
    List<ui.PathMetric> pathMetrics,
    List<Offset> vertexPositions,
  ) {
    final Map<int, VertexModel> vertices = {};
    final Map<int, SegmentModel> segments = {};

    int vertexIdCounter = 0;
    int segmentIdCounter = 0;

    // Step 1: Create vertices from positions
    for (var position in vertexPositions) {
      vertices[vertexIdCounter] = VertexModel(
        vertexId: vertexIdCounter,
        dx: position.dx,
        dy: position.dy,
      );
      vertexIdCounter++;
    }

    // Step 2: For each path metric, find all vertices along it and create segments between them
    for (var pathMetric in pathMetrics) {
      // Find all vertices that lie on this path metric
      List<_VertexOnPath> verticesOnPath = [];

      // Check each vertex to see if it's on this path
      for (var vertex in vertices.values) {
        double? distanceOnPath = _findDistanceOnPath(
          pathMetric,
          vertex.position,
          tolerance: 15.0,
        );

        if (distanceOnPath != null) {
          verticesOnPath.add(
            _VertexOnPath(
              vertexId: vertex.vertexId,
              position: vertex.position,
              distanceAlongPath: distanceOnPath,
            ),
          );
        }
      }

      // Sort vertices by their distance along the path
      verticesOnPath.sort(
        (a, b) => a.distanceAlongPath.compareTo(b.distanceAlongPath),
      );

      // If less than 2 vertices found on this path, add start and end
      if (verticesOnPath.length < 2) {
        final startTangent = pathMetric.getTangentForOffset(0);
        final endTangent = pathMetric.getTangentForOffset(pathMetric.length);

        if (startTangent != null && endTangent != null) {
          int? startVertexId = _findVertexIdByPosition(
            vertices,
            startTangent.position,
          );
          int? endVertexId = _findVertexIdByPosition(
            vertices,
            endTangent.position,
          );

          if (startVertexId == null) {
            startVertexId = vertexIdCounter;
            vertices[vertexIdCounter] = VertexModel(
              vertexId: vertexIdCounter,
              dx: startTangent.position.dx,
              dy: startTangent.position.dy,
            );
            vertexIdCounter++;
          }

          if (endVertexId == null) {
            endVertexId = vertexIdCounter;
            vertices[vertexIdCounter] = VertexModel(
              vertexId: vertexIdCounter,
              dx: endTangent.position.dx,
              dy: endTangent.position.dy,
            );
            vertexIdCounter++;
          }

          // Create single segment for the entire path
          final segment = SegmentModel(
            segmentId: segmentIdCounter,
            startVertexId: startVertexId,
            endVertexId: endVertexId,
            length: pathMetric.length,
            pathMetric: pathMetric,
            startPosition: startTangent.position,
            endPosition: endTangent.position,
            startOffsetOnPath: 0.0,
          );

          segments[segmentIdCounter] = segment;
          vertices[startVertexId]!.addSegmentConnection(segmentIdCounter);
          vertices[endVertexId]!.addSegmentConnection(segmentIdCounter);
          segmentIdCounter++;
        }
      } else {
        // Create segments between consecutive vertices
        for (int i = 0; i < verticesOnPath.length - 1; i++) {
          final startVertex = verticesOnPath[i];
          final endVertex = verticesOnPath[i + 1];

          final segmentLength =
              endVertex.distanceAlongPath - startVertex.distanceAlongPath;

          // Create segment between these two vertices
          final segment = SegmentModel(
            segmentId: segmentIdCounter,
            startVertexId: startVertex.vertexId,
            endVertexId: endVertex.vertexId,
            length: segmentLength,
            pathMetric: pathMetric,
            startPosition: startVertex.position,
            endPosition: endVertex.position,
            startOffsetOnPath:
                startVertex.distanceAlongPath, // Key: offset on parent path
          );

          segments[segmentIdCounter] = segment;
          vertices[startVertex.vertexId]!.addSegmentConnection(
            segmentIdCounter,
          );
          vertices[endVertex.vertexId]!.addSegmentConnection(segmentIdCounter);
          segmentIdCounter++;
        }

        // Check if this is a closed path (start and end are close)
        if (verticesOnPath.isNotEmpty) {
          final firstVertex = verticesOnPath.first;
          final lastVertex = verticesOnPath.last;
          final startTangent = pathMetric.getTangentForOffset(0);
          final endTangent = pathMetric.getTangentForOffset(pathMetric.length);

          if (startTangent != null && endTangent != null) {
            final isClosedPath =
                (startTangent.position - endTangent.position).distance < 10.0;

            // If closed path, create segment from last vertex back to first
            if (isClosedPath && verticesOnPath.length >= 2) {
              final segmentLength =
                  pathMetric.length - lastVertex.distanceAlongPath;

              final segment = SegmentModel(
                segmentId: segmentIdCounter,
                startVertexId: lastVertex.vertexId,
                endVertexId: firstVertex.vertexId,
                length: segmentLength,
                pathMetric: pathMetric,
                startPosition: lastVertex.position,
                endPosition: firstVertex.position,
                startOffsetOnPath: lastVertex.distanceAlongPath,
              );

              segments[segmentIdCounter] = segment;
              vertices[lastVertex.vertexId]!.addSegmentConnection(
                segmentIdCounter,
              );
              vertices[firstVertex.vertexId]!.addSegmentConnection(
                segmentIdCounter,
              );
              segmentIdCounter++;
            }
          }
        }
      }
    }

    return ConnectionGraph(vertices: vertices, segments: segments);
  }

  /// Find the distance along a path where a position is located
  static double? _findDistanceOnPath(
    ui.PathMetric pathMetric,
    Offset position, {
    double tolerance = 15.0,
  }) {
    double? closestDistance;
    double minDist = double.infinity;

    final length = pathMetric.length;

    // Sample the path with finer steps to find closest point more accurately
    for (double distance = 0; distance <= length; distance += 0.5) {
      final tangent = pathMetric.getTangentForOffset(distance);
      if (tangent != null) {
        final dist = (tangent.position - position).distance;
        if (dist < minDist) {
          minDist = dist;
          closestDistance = distance;
        }
      }
    }

    // Return the distance if it's within tolerance
    return (minDist <= tolerance) ? closestDistance : null;
  }

  /// Find vertex ID by position (with tolerance)
  static int? _findVertexIdByPosition(
    Map<int, VertexModel> vertices,
    Offset position, {
    double tolerance = 5.0,
  }) {
    for (var vertex in vertices.values) {
      if (vertex.isSamePosition(position, tolerance: tolerance)) {
        return vertex.vertexId;
      }
    }
    return null;
  }
}

/// Helper class to track vertex position along a path
class _VertexOnPath {
  final int vertexId;
  final Offset position;
  final double distanceAlongPath;

  _VertexOnPath({
    required this.vertexId,
    required this.position,
    required this.distanceAlongPath,
  });
}
