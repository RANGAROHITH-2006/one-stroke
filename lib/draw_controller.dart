import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:singlelinedraw/svg_path_parser.dart';
import 'package:singlelinedraw/models/vertex_model.dart';
import 'package:singlelinedraw/models/segment_model.dart';
import 'package:singlelinedraw/models/connection_graph.dart';

/// Draw Controller
/// Manages the drawing interaction, path validation, and game state
/// Handles gesture recognition, progress tracking, and completion detection
/// Now with ID-based vertex-segment graph for accurate path tracing
class DrawController extends ChangeNotifier {
  // Game state
  bool isDrawing = false;
  bool isGameCompleted = false;
  double progress = 0.0;
  String? errorMessage;

  // Drawing data
  List<Offset> userPath = [];
  Path? svgPath;
  double tolerance =
      20.0; // Hit detection tolerance in pixels (increased for better coverage)

  // ID-based tracking system
  ConnectionGraph? _graph;

  // Track drawn ranges by segment ID (not index)
  Map<int, List<List<double>>> drawnRangesBySegmentId = {};

  // Track the currently active segment by ID
  int? _activeSegmentId;
  double? _lastDistanceOnSegment;

  // Track drawing direction
  bool? _drawingForward; // true = toward end, false = toward start

  // Track which segments have been significantly drawn (> 20% filled)
  Set<int> _drawnSegmentIds = {};

  // Path metrics (kept for compatibility)
  List<ui.PathMetric> pathSegments = [];
  double totalPathLength = 0.0;

  // Vertex-based segments (legacy, will be replaced by graph)
  List<PathSegmentInfo> vertexSegments = [];
  List<Offset> transformedVertices = [];

  // Callbacks
  VoidCallback? onLevelComplete;
  VoidCallback? onGameReset;

  DrawController({this.onLevelComplete, this.onGameReset});

  /// Initialize the controller with SVG path data
  void initializeWithPath(Path transformedPath) {
    svgPath = transformedPath;
    pathSegments = SvgPathParser.getPathSegments(transformedPath);
    totalPathLength = SvgPathParser.getPathLength(transformedPath);

    // Build connection graph
    _graph = GraphBuilder.buildFromPath(pathSegments, []);

    // Initialize empty ranges for each segment ID
    drawnRangesBySegmentId.clear();
    for (var segmentId in _graph!.segments.keys) {
      drawnRangesBySegmentId[segmentId] = [];
    }

    // Print debug info
    _graph?.printDebugInfo();

    reset();
  }

  /// Initialize with vertex information for better segment tracking
  void initializeWithVertices(Path transformedPath, List<Offset> vertices) {
    svgPath = transformedPath;
    pathSegments = SvgPathParser.getPathSegments(transformedPath);
    totalPathLength = SvgPathParser.getPathLength(transformedPath);
    transformedVertices = vertices;

    // Extract vertex-based segments (legacy)
    vertexSegments = SvgPathParser.extractSegmentsWithVertices(
      transformedPath,
      vertices,
    );

    // If not enough segments found, ensure minimum by sampling
    if (vertexSegments.isEmpty && pathSegments.isNotEmpty) {
      // Fall back to simple segment extraction
      _createDefaultVertexSegments();
    }

    // Build ID-based connection graph
    _graph = GraphBuilder.buildFromPath(pathSegments, vertices);

    // Initialize empty ranges for each segment ID
    drawnRangesBySegmentId.clear();
    for (var segmentId in _graph!.segments.keys) {
      drawnRangesBySegmentId[segmentId] = [];
    }

    // Print debug info
    _graph?.printDebugInfo();

    reset();
  }

  /// Create default vertex segments by sampling the path
  void _createDefaultVertexSegments() {
    vertexSegments = [];
    transformedVertices = [];

    for (int i = 0; i < pathSegments.length; i++) {
      final metric = pathSegments[i];
      final length = metric.length;

      // Sample at least 5 points along each path metric
      final numPoints = (length / 50).ceil().clamp(5, 20);
      final step = length / numPoints;

      List<double> sampleDistances = [];
      for (int j = 0; j <= numPoints; j++) {
        sampleDistances.add((j * step).clamp(0.0, length));
      }

      // Create segments between sample points
      for (int j = 0; j < sampleDistances.length - 1; j++) {
        final startTangent = metric.getTangentForOffset(sampleDistances[j]);
        final endTangent = metric.getTangentForOffset(sampleDistances[j + 1]);

        if (startTangent != null && endTangent != null) {
          if (j == 0 || !transformedVertices.contains(startTangent.position)) {
            transformedVertices.add(startTangent.position);
          }
          if (!transformedVertices.contains(endTangent.position)) {
            transformedVertices.add(endTangent.position);
          }

          vertexSegments.add(
            PathSegmentInfo(
              pathMetricIndex: i,
              startVertex: startTangent.position,
              endVertex: endTangent.position,
              startDistance: sampleDistances[j],
              endDistance: sampleDistances[j + 1],
              startVertexIndex: transformedVertices.length - 2,
              endVertexIndex: transformedVertices.length - 1,
            ),
          );
        }
      }
    }
  }

  /// Get vertices for display
  List<Offset> get vertices => transformedVertices;

  /// Handle pan start - begin drawing
  void onPanStart(DragStartDetails details) {
    if (isGameCompleted) return;

    final localPosition = details.localPosition;

    // Check if starting position is on the path (vertex or middle)
    if (_isPointOnPath(localPosition)) {
      isDrawing = true;
      userPath.clear();
      userPath.add(localPosition);

      // Reset ranges for all segments by ID
      drawnRangesBySegmentId.clear();
      if (_graph != null) {
        for (var segmentId in _graph!.segments.keys) {
          drawnRangesBySegmentId[segmentId] = [];
        }
      }

      // Reset active segment tracking
      _activeSegmentId = null;
      _lastDistanceOnSegment = null;
      _drawingForward = null;
      _drawnSegmentIds.clear();

      progress = 0.0;
      errorMessage = null;

      // Find segment and auto-fill from start point to nearest endpoint
      _initializeSegmentWithAutoFill(localPosition);

      notifyListeners();
    }
  }

  /// Handle pan update - continue drawing
  void onPanUpdate(DragUpdateDetails details) {
    if (!isDrawing || isGameCompleted) return;

    final localPosition = details.localPosition;

    // Check if current position is valid (on path)
    if (_isPointOnPath(localPosition)) {
      userPath.add(localPosition);

      // Fill in segments between last and current position
      if (userPath.length > 1) {
        _fillPathBetweenOnActiveSegment(
          userPath[userPath.length - 2],
          localPosition,
        );
      }

      _updateProgress();

      // Check for completion - use 95% threshold to account for path detection tolerance
      // This prevents the issue where visually complete paths show as incomplete
      if (progress >= 0.99) {
        _completeLevel();
      }

      notifyListeners();
    } else {
      // User went outside valid path - stop drawing and show error
      _stopDrawingWithError("Stay on the line!");
    }
  }

  /// Handle pan end - finish drawing stroke
  void onPanEnd(DragEndDetails details) {
    if (!isDrawing) return;

    // If not completed and user lifted finger, reset
    if (!isGameCompleted) {
      _stopDrawingWithError("Complete the full outline in one stroke!");
    }

    isDrawing = false;
    notifyListeners();
  }

  /// Reset the game state
  void reset() {
    isDrawing = false;
    isGameCompleted = false;
    progress = 0.0;
    errorMessage = null;
    userPath.clear();

    // Reset drawn ranges by segment ID
    drawnRangesBySegmentId.clear();
    if (_graph != null) {
      for (var segmentId in _graph!.segments.keys) {
        drawnRangesBySegmentId[segmentId] = [];
      }
    }

    _activeSegmentId = null;
    _lastDistanceOnSegment = null;
    _drawingForward = null;
    _drawnSegmentIds.clear();
    onGameReset?.call();
    notifyListeners();
  }

  /// Check if a point is on or near the SVG path using ID-based system
  bool _isPointOnPath(Offset point) {
    if (svgPath == null || _graph == null) return false;

    // Optimization: Check active segment first (most likely to be on it)
    if (_activeSegmentId != null) {
      final activeSegment = _graph!.segments[_activeSegmentId];
      if (activeSegment != null) {
        final result = activeSegment.findClosestPosition(
          point,
          tolerance: tolerance * 1.6,
        );
        if (result != null) {
          return true;
        }
      }
    }

    // If not on active segment, check all segments with increased tolerance
    for (var segment in _graph!.segments.values) {
      final result = segment.findClosestPosition(
        point,
        tolerance: tolerance * 1.1,
      );
      if (result != null) {
        return true;
      }
    }

    // Final fallback: check with even higher tolerance for edge cases
    for (var segment in _graph!.segments.values) {
      final result = segment.findClosestPosition(
        point,
        tolerance: tolerance * 1.8,
      );
      if (result != null) {
        return true;
      }
    }

    return false;
  }

  /// Initialize segment with auto-fill to nearest endpoint using ID-based system
  void _initializeSegmentWithAutoFill(Offset point) {
    if (_graph == null) return;

    // Find the closest segment and position using ID-based system
    int? bestSegmentId;
    SegmentPosition? bestPosition;
    double bestDistance = double.infinity;

    for (var segment in _graph!.segments.values) {
      final position = segment.findClosestPosition(
        point,
        tolerance: tolerance * 1.5,
      );
      if (position != null && position.screenDistance < bestDistance) {
        bestDistance = position.screenDistance;
        bestSegmentId = segment.segmentId;
        bestPosition = position;
      }
    }

    if (bestSegmentId == null || bestPosition == null) {
      print('⚠️ No segment found at starting point!');
      return;
    }

    final segment = _graph!.segments[bestSegmentId]!;
    _activeSegmentId = bestSegmentId;
    _lastDistanceOnSegment = bestPosition.distanceAlongSegment;

    print(
      '✅ Started on Segment $bestSegmentId at distance ${bestPosition.distanceAlongSegment.toStringAsFixed(1)}',
    );

    // Determine which endpoint is closer
    double distToStart = bestPosition.distanceAlongSegment;
    double distToEnd = segment.length - bestPosition.distanceAlongSegment;

    // Auto-fill from start point to the NEAREST endpoint
    if (distToStart <= distToEnd) {
      // Closer to start - fill from 0 to current position
      _addRangeById(bestSegmentId, 0.0, bestPosition.distanceAlongSegment);
      _drawingForward = true; // Will draw toward the end
    } else {
      // Closer to end - fill from current position to end
      _addRangeById(
        bestSegmentId,
        bestPosition.distanceAlongSegment,
        segment.length,
      );
      _drawingForward = false; // Will draw toward the start
    }
  }

  /// Add a range to a segment by ID, merging with existing overlapping ranges
  void _addRangeById(int segmentId, double start, double end) {
    if (!drawnRangesBySegmentId.containsKey(segmentId)) return;

    List<List<double>> ranges = drawnRangesBySegmentId[segmentId]!;

    // Find overlapping or adjacent ranges and merge
    List<List<double>> newRanges = [];

    for (var range in ranges) {
      // Check if ranges overlap or are adjacent (within 2 pixels for smoother drawing)
      if (start <= range[1] + 2 && end >= range[0] - 2) {
        // Merge ranges
        start = start < range[0] ? start : range[0];
        end = end > range[1] ? end : range[1];
      } else {
        newRanges.add(range);
      }
    }

    newRanges.add([start, end]);

    // Sort ranges by start position
    newRanges.sort((a, b) => a[0].compareTo(b[0]));

    // Merge any remaining overlapping ranges after sorting
    List<List<double>> finalRanges = [];
    for (var range in newRanges) {
      if (finalRanges.isEmpty || finalRanges.last[1] < range[0] - 2) {
        finalRanges.add(range);
      } else {
        finalRanges.last[1] =
            finalRanges.last[1] > range[1] ? finalRanges.last[1] : range[1];
      }
    }

    drawnRangesBySegmentId[segmentId] = finalRanges;
  }

  /// Fill path between two points with gap auto-fill and strict single-segment control
  /// Implements: gap auto-fill for fast movements, strict single-line filling, partial filling
  void _fillPathBetweenOnActiveSegment(Offset startPoint, Offset endPoint) {
    // Calculate the screen distance between the two touch points
    double screenDistance = (endPoint - startPoint).distance;

    // STRICT SINGLE-SEGMENT RULE: Only work on the active segment
    if (_activeSegmentId == null ||
        _lastDistanceOnSegment == null ||
        _graph == null) {
      return;
    }

    final activeSegment = _graph!.segments[_activeSegmentId];
    if (activeSegment == null) return;

    // Find where the end point is on the ACTIVE segment only
    SegmentPosition? endPosition = activeSegment.findClosestPosition(
      endPoint,
      tolerance: tolerance * 1.6,
    );

    // If point is not on active segment, check if we should transition
    if (endPosition == null) {
      // Only transition if we're at an endpoint and there's a connected segment
      _checkAndTransitionAtEndpoint(endPoint, screenDistance);
      return;
    }

    double endDistOnActive = endPosition.distanceAlongSegment;

    // Calculate path distance on the active segment
    double pathDistance = (endDistOnActive - _lastDistanceOnSegment!).abs();
    final length = activeSegment.length;

    // Check if movement is in the correct direction
    bool movingForward = endDistOnActive > _lastDistanceOnSegment!;

    // Set drawing direction on first movement (but allow direction changes for flexibility)
    if (_drawingForward == null) {
      _drawingForward = movingForward;
    }

    // ADJACENT POINT CHECK: Only fill if points are truly adjacent
    // Use very relaxed multiplier for smoother drawing experience
    // Increased to allow better coverage on all segments
    double maxAllowedPathDistance = screenDistance * 3.0 + tolerance * 3.0;

    // If path distance is much larger than screen distance, points aren't adjacent
    if (pathDistance > maxAllowedPathDistance) {
      // Not adjacent - don't fill this gap
      print(
        '⚠️ Gap too large: path=$pathDistance, screen=$screenDistance, max=$maxAllowedPathDistance',
      );
      return;
    }

    // Additional smoothness: allow small jumps for very close points
    if (screenDistance < tolerance * 0.8 && pathDistance < tolerance * 1.5) {
      // Very close movement - always fill for smoothness
    }

    // PARTIAL FILLING: Only fill the portion the user actually covers
    double rangeStart =
        _lastDistanceOnSegment! < endDistOnActive
            ? _lastDistanceOnSegment!
            : endDistOnActive;
    double rangeEnd =
        _lastDistanceOnSegment! > endDistOnActive
            ? _lastDistanceOnSegment!
            : endDistOnActive;

    // Auto-fill the gap between last and current position
    _addRangeById(
      _activeSegmentId!,
      rangeStart.clamp(0, length),
      rangeEnd.clamp(0, length),
    );

    _lastDistanceOnSegment = endDistOnActive;

    // Mark segment as significantly filled if > 80% complete
    // Lower threshold allows partial fills without blocking re-entry
    if (_getSegmentFilledRatioById(_activeSegmentId!) > 0.8) {
      _drawnSegmentIds.add(_activeSegmentId!);
    }
  }

  /// Check if we're at an endpoint and should transition to a connected segment using ID-based graph
  void _checkAndTransitionAtEndpoint(Offset point, double screenDistance) {
    if (_activeSegmentId == null ||
        _lastDistanceOnSegment == null ||
        _graph == null)
      return;

    final activeSegment = _graph!.segments[_activeSegmentId];
    if (activeSegment == null) return;

    // Check if we're AT an endpoint (relaxed for smooth transitions)
    bool nearStart = _lastDistanceOnSegment! < tolerance * 3.0;
    bool nearEnd =
        _lastDistanceOnSegment! > activeSegment.length - tolerance * 3.0;

    if (!nearStart && !nearEnd) {
      // Not at an endpoint - don't transition
      return;
    }

    // Find connected segments using the graph
    List<int> connectedSegmentIds = _graph!.findConnectedSegments(
      _activeSegmentId!,
      _lastDistanceOnSegment!,
    );

    // Don't skip already drawn segments - allow re-entry for partial fills
    // This fixes the issue where some segments can't be entered
    // connectedSegmentIds = connectedSegmentIds
    //     .where((id) => !_drawnSegmentIds.contains(id))
    //     .toList();

    if (connectedSegmentIds.isEmpty) {
      print('⚠️ No connected segments found from segment $_activeSegmentId');
      return;
    }

    // Find the best segment to transition to
    int? bestNewSegmentId;
    SegmentPosition? bestPosition;
    double bestDist = double.infinity;

    for (var segmentId in connectedSegmentIds) {
      final segment = _graph!.segments[segmentId];
      if (segment == null) continue;

      // Check if the current point is on this segment
      final position = segment.findClosestPosition(
        point,
        tolerance: tolerance * 4.0,
      );
      if (position != null && position.screenDistance < bestDist) {
        // Check if we're near a connection point
        bool nearConnectionStart =
            position.distanceAlongSegment < tolerance * 4.0;
        bool nearConnectionEnd =
            position.distanceAlongSegment > segment.length - tolerance * 4.0;

        if (nearConnectionStart || nearConnectionEnd) {
          bestDist = position.screenDistance;
          bestNewSegmentId = segmentId;
          bestPosition = position;
        }
      }
    }

    // Transition if found
    if (bestNewSegmentId != null && bestPosition != null) {
      final newSegment = _graph!.segments[bestNewSegmentId]!;

      print(
        '🔄 Transitioning from segment $_activeSegmentId to $bestNewSegmentId',
      );

      // Fill to end of current segment
      if (nearEnd) {
        _addRangeById(
          _activeSegmentId!,
          _lastDistanceOnSegment!,
          activeSegment.length,
        );
      } else if (nearStart) {
        _addRangeById(_activeSegmentId!, 0, _lastDistanceOnSegment!);
      }

      // Mark old segment as completed
      _drawnSegmentIds.add(_activeSegmentId!);

      // Switch to new segment
      _activeSegmentId = bestNewSegmentId;
      _lastDistanceOnSegment = bestPosition.distanceAlongSegment;
      _drawingForward = null;

      // Auto-fill from touch point to nearest endpoint
      double distToStart = bestPosition.distanceAlongSegment;
      double distToEnd = newSegment.length - bestPosition.distanceAlongSegment;

      if (distToStart <= distToEnd) {
        _addRangeById(bestNewSegmentId, 0, bestPosition.distanceAlongSegment);
      } else {
        _addRangeById(
          bestNewSegmentId,
          bestPosition.distanceAlongSegment,
          newSegment.length,
        );
      }
    }
  }

  /// Calculate what ratio of a segment has been filled by ID
  double _getSegmentFilledRatioById(int segmentId) {
    final segment = _graph?.segments[segmentId];
    if (segment == null) return 0.0;

    final segmentLength = segment.length;
    if (segmentLength == 0) return 0.0;

    final ranges = drawnRangesBySegmentId[segmentId];
    if (ranges == null || ranges.isEmpty) return 0.0;

    double filledLength = 0;
    for (var range in ranges) {
      filledLength += range[1] - range[0];
    }

    return filledLength / segmentLength;
  }

  /// Update progress based on drawn ranges by ID (continuous line tracking)
  void _updateProgress() {
    if (totalPathLength == 0 || _graph == null) return;

    double drawnLength = 0;
    double actualTotalLength = 0;

    // Calculate both drawn length and actual total length using ID-based system
    for (var segment in _graph!.segments.values) {
      actualTotalLength += segment.length;

      // Sum up all drawn ranges for this segment by ID
      final ranges = drawnRangesBySegmentId[segment.segmentId];
      if (ranges != null) {
        for (var range in ranges) {
          drawnLength += range[1] - range[0];
        }
      }
    }

    // Use actualTotalLength if it differs from totalPathLength
    final targetLength =
        actualTotalLength > 0 ? actualTotalLength : totalPathLength;
    progress = (drawnLength / targetLength).clamp(0.0, 1.0);
  }

  /// Complete the level successfully
  void _completeLevel() {
    isGameCompleted = true;
    isDrawing = false;
    progress = 1.0;
    errorMessage = null;
    onLevelComplete?.call();
  }

  /// Stop drawing with error message
  void _stopDrawingWithError(String message) {
    isDrawing = false;
    errorMessage = message;

    // Auto-reset after showing error briefly
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (errorMessage == message) {
        // Only reset if error hasn't changed
        reset();
      }
    });

    notifyListeners();
  }

  /// Get completion percentage as integer
  int get completionPercentage => (progress * 100).round();

  /// Check if game has error
  bool get hasError => errorMessage != null;

  /// Get drawn ranges for painter (for visual rendering)
  /// Converts ID-based tracking to PathMetric-absolute ranges
  List<List<List<double>>> get getDrawnRanges {
    if (_graph == null) return [];

    // Build ranges per PathMetric (not per segment)
    List<List<List<double>>> pathMetricRanges = List.generate(
      pathSegments.length,
      (_) => [],
    );

    // For each segment, convert its ranges to absolute PathMetric positions
    for (var segment in _graph!.segments.values) {
      final segmentRanges = drawnRangesBySegmentId[segment.segmentId];
      if (segmentRanges == null || segmentRanges.isEmpty) continue;

      // Find which PathMetric index this segment belongs to
      int pathMetricIndex = -1;
      for (int i = 0; i < pathSegments.length; i++) {
        if (pathSegments[i] == segment.pathMetric) {
          pathMetricIndex = i;
          break;
        }
      }

      if (pathMetricIndex == -1) continue;

      // Convert segment-relative ranges to PathMetric-absolute ranges
      for (var range in segmentRanges) {
        double absoluteStart = segment.startOffsetOnPath + range[0];
        double absoluteEnd = segment.startOffsetOnPath + range[1];

        // Add to the PathMetric's range list
        pathMetricRanges[pathMetricIndex].add([absoluteStart, absoluteEnd]);
      }
    }

    // Merge overlapping ranges for each PathMetric
    for (int i = 0; i < pathMetricRanges.length; i++) {
      pathMetricRanges[i] = _mergeRanges(pathMetricRanges[i]);
    }

    return pathMetricRanges;
  }

  /// Merge overlapping or adjacent ranges
  List<List<double>> _mergeRanges(List<List<double>> ranges) {
    if (ranges.isEmpty) return [];

    // Sort by start position
    ranges.sort((a, b) => a[0].compareTo(b[0]));

    List<List<double>> merged = [ranges[0]];

    for (int i = 1; i < ranges.length; i++) {
      final current = ranges[i];
      final last = merged.last;

      // Check if ranges overlap or are adjacent (within 2 pixels)
      if (current[0] <= last[1] + 2) {
        // Merge ranges
        last[1] = current[1] > last[1] ? current[1] : last[1];
      } else {
        merged.add(current);
      }
    }

    return merged;
  }
}
