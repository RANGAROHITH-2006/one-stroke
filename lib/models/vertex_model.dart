import 'package:flutter/material.dart';

/// Vertex Model
/// Represents a vertex (endpoint/junction) in the path with unique ID
/// Maintains connections to segments for accurate transition tracking
class VertexModel {
  final int vertexId;
  final double dx;
  final double dy;
  final Set<int> connectedSegmentIds;

  VertexModel({
    required this.vertexId,
    required this.dx,
    required this.dy,
    Set<int>? connectedSegmentIds,
  }) : connectedSegmentIds = connectedSegmentIds ?? {};

  Offset get position => Offset(dx, dy);

  /// Add a segment connection to this vertex
  void addSegmentConnection(int segmentId) {
    connectedSegmentIds.add(segmentId);
  }

  /// Check if this vertex connects to a specific segment
  bool isConnectedTo(int segmentId) {
    return connectedSegmentIds.contains(segmentId);
  }

  /// Get the number of connected segments (degree of vertex)
  int get degree => connectedSegmentIds.length;

  /// Check if two vertices are at the same position (within tolerance)
  bool isSamePosition(Offset other, {double tolerance = 5.0}) {
    return (position - other).distance < tolerance;
  }

  @override
  String toString() {
    return 'Vertex(id: $vertexId, pos: (${dx.toStringAsFixed(1)}, ${dy.toStringAsFixed(1)}), segments: $connectedSegmentIds)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VertexModel && other.vertexId == vertexId;
  }

  @override
  int get hashCode => vertexId.hashCode;
}
