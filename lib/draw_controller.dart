import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:singlelinedraw/svg_path_parser.dart';

/// Draw Controller
/// Manages the drawing interaction, path validation, and game state
/// Handles gesture recognition, progress tracking, and completion detection
/// Now with vertex-aware segment drawing for better path tracing
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
      16.0; // Hit detection tolerance in pixels (balanced for accuracy and smoothness)

  // Continuous range-based tracking (instead of discrete dots)
  // Each segment has a list of drawn ranges [start, end] along its length
  List<List<List<double>>> drawnRanges =
      []; // [segmentIndex][rangeIndex][start, end]

  // Track the currently active segment index to prevent filling multiple edges at vertices
  int? _activeSegmentIndex;
  double? _lastDistanceOnSegment;

  // Track which segments have been significantly drawn (> 20% filled)
  Set<int> _drawnSegments = {};

  // Path metrics
  List<ui.PathMetric> pathSegments = [];
  double totalPathLength = 0.0;

  // Vertex-based segments
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

    // Initialize empty ranges for each segment
    drawnRanges = List.generate(pathSegments.length, (_) => []);

    reset();
  }

  /// Initialize with vertex information for better segment tracking
  void initializeWithVertices(Path transformedPath, List<Offset> vertices) {
    svgPath = transformedPath;
    pathSegments = SvgPathParser.getPathSegments(transformedPath);
    totalPathLength = SvgPathParser.getPathLength(transformedPath);
    transformedVertices = vertices;

    // Extract vertex-based segments
    vertexSegments = SvgPathParser.extractSegmentsWithVertices(
      transformedPath,
      vertices,
    );

    // If not enough segments found, ensure minimum by sampling
    if (vertexSegments.isEmpty && pathSegments.isNotEmpty) {
      // Fall back to simple segment extraction
      _createDefaultVertexSegments();
    }

    // Initialize empty ranges for each segment
    drawnRanges = List.generate(pathSegments.length, (_) => []);

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

    // Check if starting position is on or near the path
    if (_isPointOnPath(localPosition)) {
      isDrawing = true;
      userPath.clear();
      userPath.add(localPosition);
      // Reset ranges for all segments
      drawnRanges = List.generate(pathSegments.length, (_) => []);
      // Reset active segment tracking
      _activeSegmentIndex = null;
      _lastDistanceOnSegment = null;
      progress = 0.0;
      errorMessage = null;

      // Mark starting segment as drawn and set it as active
      // This now fills from the nearest vertex when starting mid-segment
      _markSegmentAsDrawnAndSetActiveFromVertex(localPosition);

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
    drawnRanges = List.generate(pathSegments.length, (_) => []);
    _activeSegmentIndex = null;
    _lastDistanceOnSegment = null;
    _drawnSegments.clear();
    onGameReset?.call();
    notifyListeners();
  }

  /// Check if a point is on or near the SVG path
  bool _isPointOnPath(Offset point) {
    if (svgPath == null) return false;

    // Optimization: Check active segment first (most likely to be on it)
    // Use slightly relaxed tolerance for active segment to allow continuous filling
    if (_activeSegmentIndex != null &&
        _activeSegmentIndex! < pathSegments.length) {
      final pathMetric = pathSegments[_activeSegmentIndex!];
      final length = pathMetric.length;

      // Use normal tolerance for active segment (was 0.9, now 1.0)
      double strictTolerance = tolerance;
      for (double distance = 0; distance < length; distance += 2.0) {
        final ui.Tangent? tangent = pathMetric.getTangentForOffset(distance);
        if (tangent != null) {
          final double currentDistance = (point - tangent.position).distance;
          if (currentDistance <= strictTolerance) {
            return true;
          }
        }
      }
    }

    // If not on active segment, check all segments with larger steps
    for (ui.PathMetric pathMetric in pathSegments) {
      final length = pathMetric.length;

      // Use larger steps (2.0 instead of 0.5) for much better performance
      for (double distance = 0; distance < length; distance += 2.0) {
        final ui.Tangent? tangent = pathMetric.getTangentForOffset(distance);
        if (tangent != null) {
          final double currentDistance = (point - tangent.position).distance;
          if (currentDistance <= tolerance) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Mark a point on the path as drawn and set the active segment
  /// This is used when starting a new drawing stroke
  void _markSegmentAsDrawnAndSetActive(Offset point) {
    // Find the single closest point across ALL segments
    int? bestSegmentIndex;
    double? bestDistance;
    double bestMinDist = double.infinity;

    for (
      int segmentIndex = 0;
      segmentIndex < pathSegments.length;
      segmentIndex++
    ) {
      final pathMetric = pathSegments[segmentIndex];
      final length = pathMetric.length;

      // Use larger steps (2.0) for better performance during segment marking
      for (double distance = 0; distance <= length; distance += 2.0) {
        final ui.Tangent? tangent = pathMetric.getTangentForOffset(distance);
        if (tangent != null) {
          final double currentDist = (point - tangent.position).distance;
          if (currentDist <= tolerance && currentDist < bestMinDist) {
            bestMinDist = currentDist;
            bestSegmentIndex = segmentIndex;
            bestDistance = distance;
          }
        }
      }
    }

    // Set the active segment and mark it as drawn
    if (bestSegmentIndex != null && bestDistance != null) {
      _activeSegmentIndex = bestSegmentIndex;
      _lastDistanceOnSegment = bestDistance;

      final length = pathSegments[bestSegmentIndex].length;
      // Add a small range around this point
      double rangeStart = (bestDistance - tolerance / 2).clamp(0, length);
      double rangeEnd = (bestDistance + tolerance / 2).clamp(0, length);
      _addRange(bestSegmentIndex, rangeStart, rangeEnd);
    }
  }

  /// Mark a point on the path as drawn and set the active segment
  /// When starting from middle of a segment, fills from the nearest vertex ON THE SAME PATH
  void _markSegmentAsDrawnAndSetActiveFromVertex(Offset point) {
    // Find the closest point on the path
    int? bestSegmentIndex;
    double? bestDistance;
    double bestMinDist = double.infinity;

    for (
      int segmentIndex = 0;
      segmentIndex < pathSegments.length;
      segmentIndex++
    ) {
      final pathMetric = pathSegments[segmentIndex];
      final length = pathMetric.length;

      // Use larger steps (2.0) for better performance
      for (double distance = 0; distance <= length; distance += 2.0) {
        final ui.Tangent? tangent = pathMetric.getTangentForOffset(distance);
        if (tangent != null) {
          final double currentDist = (point - tangent.position).distance;
          if (currentDist <= tolerance && currentDist < bestMinDist) {
            bestMinDist = currentDist;
            bestSegmentIndex = segmentIndex;
            bestDistance = distance;
          }
        }
      }
    }

    if (bestSegmentIndex == null || bestDistance == null) return;

    _activeSegmentIndex = bestSegmentIndex;
    _lastDistanceOnSegment = bestDistance;

    final pathMetric = pathSegments[bestSegmentIndex];
    final length = pathMetric.length;

    // Find the nearest vertex ON THIS SAME PATH SEGMENT only
    // This ensures we don't fill towards vertices on other paths
    double nearestVertexPathDist = 0;
    double nearestVertexScreenDist = double.infinity;

    // Always consider start of this path segment as a vertex
    final startTangent = pathMetric.getTangentForOffset(0);
    if (startTangent != null) {
      final distToStart = (point - startTangent.position).distance;
      if (distToStart < nearestVertexScreenDist) {
        nearestVertexScreenDist = distToStart;
        nearestVertexPathDist = 0;
      }
    }

    // Always consider end of this path segment as a vertex
    final endTangent = pathMetric.getTangentForOffset(length);
    if (endTangent != null) {
      final distToEnd = (point - endTangent.position).distance;
      if (distToEnd < nearestVertexScreenDist) {
        nearestVertexScreenDist = distToEnd;
        nearestVertexPathDist = length;
      }
    }

    // Check intermediate vertices ONLY if they are on THIS path segment
    // Use a strict tolerance to ensure vertex is actually on this path
    for (final vertex in transformedVertices) {
      final vertexDistOnPath = _findClosestDistanceOnSegmentStrict(
        vertex,
        bestSegmentIndex,
        8.0,
      );
      if (vertexDistOnPath != null) {
        final distToVertex = (point - vertex).distance;
        if (distToVertex < nearestVertexScreenDist) {
          nearestVertexScreenDist = distToVertex;
          nearestVertexPathDist = vertexDistOnPath;
        }
      }
    }

    // Fill from nearest vertex (on same path) to touch point
    // BUT only if the touch point is reasonably far from the vertex
    // This prevents accidental auto-fill when just shaking near a vertex
    double distanceFromVertex = (bestDistance - nearestVertexPathDist).abs();

    // Only auto-fill if moved at least 30 pixels along the path from the vertex
    if (distanceFromVertex < 30.0) {
      // Just mark a small range around the touch point, don't auto-fill from vertex
      double rangeStart = (bestDistance - tolerance / 2).clamp(0.0, length);
      double rangeEnd = (bestDistance + tolerance / 2).clamp(0.0, length);
      _addRange(bestSegmentIndex, rangeStart, rangeEnd);
      return;
    }

    double rangeStart =
        bestDistance < nearestVertexPathDist
            ? bestDistance
            : nearestVertexPathDist;
    double rangeEnd =
        bestDistance > nearestVertexPathDist
            ? bestDistance
            : nearestVertexPathDist;

    // Extend range slightly for tolerance
    rangeStart = (rangeStart - tolerance / 2).clamp(0.0, length);
    rangeEnd = (rangeEnd + tolerance / 2).clamp(0.0, length);

    _addRange(bestSegmentIndex, rangeStart, rangeEnd);
  }

  /// Find distance on segment with strict tolerance (for vertex matching on same path)
  double? _findClosestDistanceOnSegmentStrict(
    Offset point,
    int segmentIndex,
    double strictTolerance,
  ) {
    final pathMetric = pathSegments[segmentIndex];
    final length = pathMetric.length;

    double? closestDistance;
    double minDist = double.infinity;

    // Use larger steps (2.0) for better performance
    for (double distance = 0; distance <= length; distance += 2.0) {
      final ui.Tangent? tangent = pathMetric.getTangentForOffset(distance);
      if (tangent != null) {
        final double currentDist = (point - tangent.position).distance;
        if (currentDist <= strictTolerance && currentDist < minDist) {
          minDist = currentDist;
          closestDistance = distance;
        }
      }
    }

    return closestDistance;
  }

  /// Add a range to a segment, merging with existing overlapping ranges
  void _addRange(int segmentIndex, double start, double end) {
    if (segmentIndex >= drawnRanges.length) return;

    List<List<double>> ranges = drawnRanges[segmentIndex];

    // Find overlapping or adjacent ranges and merge
    List<List<double>> newRanges = [];

    for (var range in ranges) {
      // Check if ranges overlap or are adjacent (within 3 pixels for smoother drawing)
      if (start <= range[1] + 3 && end >= range[0] - 3) {
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
      if (finalRanges.isEmpty || finalRanges.last[1] < range[0] - 3) {
        finalRanges.add(range);
      } else {
        finalRanges.last[1] =
            finalRanges.last[1] > range[1] ? finalRanges.last[1] : range[1];
      }
    }

    drawnRanges[segmentIndex] = finalRanges;
  }

  /// Fill path between two points, staying on the active segment or transitioning to a new one
  /// This prevents filling multiple edges at vertices
  void _fillPathBetweenOnActiveSegment(Offset startPoint, Offset endPoint) {
    // Calculate the screen distance between the two touch points
    double screenDistance = (endPoint - startPoint).distance;

    // If points are too far apart on screen, don't fill (user may have lifted finger)
    if (screenDistance > tolerance * 3) {
      return;
    }

    // First, check if we can continue on the current active segment
    if (_activeSegmentIndex != null) {
      double? endDistOnActive = _findClosestDistanceOnSegment(
        endPoint,
        _activeSegmentIndex!,
      );

      if (endDistOnActive != null && _lastDistanceOnSegment != null) {
        // Calculate path distance on the active segment
        double pathDistance = (endDistOnActive - _lastDistanceOnSegment!).abs();

        // For fast movements, be stricter to prevent jumping to parallel lines
        double maxRatio = screenDistance > 20 ? 3.0 : 4.5;

        // Stricter condition: path distance should be proportional to screen distance
        bool isReasonableDistance =
            pathDistance <= screenDistance * maxRatio + 12;

        // Also allow very small movements for smooth continuous drawing
        bool isSmallMovement = pathDistance <= tolerance * 1.2;

        if (isReasonableDistance || isSmallMovement) {
          final length = pathSegments[_activeSegmentIndex!].length;
          double rangeStart =
              (_lastDistanceOnSegment! < endDistOnActive
                  ? _lastDistanceOnSegment!
                  : endDistOnActive);
          double rangeEnd =
              (_lastDistanceOnSegment! > endDistOnActive
                  ? _lastDistanceOnSegment!
                  : endDistOnActive);
          _addRange(
            _activeSegmentIndex!,
            rangeStart.clamp(0, length),
            rangeEnd.clamp(0, length),
          );
          _lastDistanceOnSegment = endDistOnActive;

          // Mark segment as drawn if it's significantly filled
          if (_getSegmentFilledRatio(_activeSegmentIndex!) > 0.2) {
            _drawnSegments.add(_activeSegmentIndex!);
          }

          return;
        }
      }

      // If point not found on active segment, check if we're at an edge
      // and try to transition to a connected segment
      if (_lastDistanceOnSegment != null) {
        final activeLength = pathSegments[_activeSegmentIndex!].length;
        bool nearEdge =
            _lastDistanceOnSegment! < tolerance * 3 ||
            _lastDistanceOnSegment! > activeLength - tolerance * 3;

        if (nearEdge) {
          // Try to transition to connected segment
          _tryTransitionToConnectedSegment(endPoint, screenDistance);
          return;
        }
      }

      // Check if we've reached the end of the current segment and need to transition
      // to a connected segment
      _tryTransitionToConnectedSegment(endPoint, screenDistance);
    } else {
      // No active segment set, find the best one
      _markSegmentAsDrawnAndSetActive(endPoint);
    }
  }

  /// Try to transition from the current active segment to a connected segment
  /// This handles cases where the user traces past a vertex to a new edge
  void _tryTransitionToConnectedSegment(Offset point, double screenDistance) {
    if (_activeSegmentIndex == null || _lastDistanceOnSegment == null) return;

    final activeMetric = pathSegments[_activeSegmentIndex!];
    final activeLength = activeMetric.length;

    // Check if we're near the start or end of the active segment
    // Use more generous threshold (tolerance * 4) for better edge detection
    bool nearStart = _lastDistanceOnSegment! < tolerance * 4;
    bool nearEnd = _lastDistanceOnSegment! > activeLength - tolerance * 4;

    if (!nearStart && !nearEnd) {
      // We're in the middle of the segment but the point isn't on it
      // This shouldn't normally happen if _isPointOnPath returned true
      // Try to find the closest segment
      _markSegmentAsDrawnAndSetActive(point);
      return;
    }

    // Get the endpoint position of the current segment
    Offset? endpointPos;
    if (nearEnd) {
      final tangent = activeMetric.getTangentForOffset(activeLength);
      endpointPos = tangent?.position;
    } else if (nearStart) {
      final tangent = activeMetric.getTangentForOffset(0);
      endpointPos = tangent?.position;
    }

    if (endpointPos == null) return;

    // Find segments that connect at this vertex (their start or end is near this endpoint)
    int? bestNewSegment;
    double? bestDistanceOnNewSegment;
    double bestMinDist = double.infinity;

    for (
      int segmentIndex = 0;
      segmentIndex < pathSegments.length;
      segmentIndex++
    ) {
      if (segmentIndex == _activeSegmentIndex) continue;

      // Skip segments that have already been significantly drawn (> 20% filled)
      double segmentFilledRatio = _getSegmentFilledRatio(segmentIndex);
      if (segmentFilledRatio > 0.2) continue;

      final pathMetric = pathSegments[segmentIndex];
      final length = pathMetric.length;

      // Check if this segment connects to our endpoint
      final startTangent = pathMetric.getTangentForOffset(0);
      final endTangent = pathMetric.getTangentForOffset(length);

      // Use more generous tolerance (tolerance * 3) for connection detection
      bool connectsAtStart =
          startTangent != null &&
          (startTangent.position - endpointPos).distance < tolerance * 3;
      bool connectsAtEnd =
          endTangent != null &&
          (endTangent.position - endpointPos).distance < tolerance * 3;

      if (!connectsAtStart && !connectsAtEnd) continue;

      // This segment connects - check if the current point is on it
      double? distOnSegment = _findClosestDistanceOnSegment(
        point,
        segmentIndex,
      );
      if (distOnSegment != null) {
        // Verify the point is being traced from the connection point
        // (not jumping to the middle of the segment)
        double expectedStartDist = connectsAtStart ? 0 : length;
        double distFromConnection = (distOnSegment - expectedStartDist).abs();

        // More lenient acceptance for continuous drawing
        // Allow up to tolerance * 5 from connection point
        if (distFromConnection < tolerance * 5 + screenDistance * 3) {
          final currentDist = _getDistanceFromPoint(
            point,
            segmentIndex,
            distOnSegment,
          );
          if (currentDist < bestMinDist) {
            bestMinDist = currentDist;
            bestNewSegment = segmentIndex;
            bestDistanceOnNewSegment = distOnSegment;
          }
        }
      }
    }

    // Transition to the new segment if found
    if (bestNewSegment != null && bestDistanceOnNewSegment != null) {
      // First, fill to the end of the current segment
      final length = pathSegments[_activeSegmentIndex!].length;
      if (nearEnd) {
        _addRange(_activeSegmentIndex!, _lastDistanceOnSegment!, length);
      } else if (nearStart) {
        _addRange(_activeSegmentIndex!, 0, _lastDistanceOnSegment!);
      }

      // Now switch to the new segment
      _activeSegmentIndex = bestNewSegment;

      // Determine which end of the new segment we're starting from
      final newMetric = pathSegments[bestNewSegment];
      final newLength = newMetric.length;
      final startTangent = newMetric.getTangentForOffset(0);

      bool startsFromBeginning =
          startTangent != null &&
          (startTangent.position - endpointPos).distance < tolerance * 2;

      // Add range from the connection point to current position
      if (startsFromBeginning) {
        _addRange(
          bestNewSegment,
          0,
          bestDistanceOnNewSegment.clamp(0, newLength),
        );
      } else {
        _addRange(
          bestNewSegment,
          bestDistanceOnNewSegment.clamp(0, newLength),
          newLength,
        );
      }

      _lastDistanceOnSegment = bestDistanceOnNewSegment;
    } else {
      // Couldn't find a connected segment, try to find any segment the point is on
      _markSegmentAsDrawnAndSetActive(point);
    }
  }

  /// Calculate what ratio of a segment has been filled
  double _getSegmentFilledRatio(int segmentIndex) {
    if (segmentIndex >= pathSegments.length ||
        segmentIndex >= drawnRanges.length) {
      return 0.0;
    }

    final segmentLength = pathSegments[segmentIndex].length;
    if (segmentLength == 0) return 0.0;

    double filledLength = 0;
    for (var range in drawnRanges[segmentIndex]) {
      filledLength += range[1] - range[0];
    }

    return filledLength / segmentLength;
  }

  /// Helper to get screen distance from a point to a specific position on a segment
  double _getDistanceFromPoint(
    Offset point,
    int segmentIndex,
    double distanceOnPath,
  ) {
    final pathMetric = pathSegments[segmentIndex];
    final tangent = pathMetric.getTangentForOffset(distanceOnPath);
    if (tangent == null) return double.infinity;
    return (point - tangent.position).distance;
  }

  /// Find the closest distance along a segment for a given point
  double? _findClosestDistanceOnSegment(Offset point, int segmentIndex) {
    final pathMetric = pathSegments[segmentIndex];
    final length = pathMetric.length;

    double? closestDistance;
    double minDist = double.infinity;

    // Use adaptive sampling: larger steps for longer paths
    double step = length > 200 ? 3.0 : (length > 100 ? 2.0 : 1.0);

    for (double distance = 0; distance <= length; distance += step) {
      final ui.Tangent? tangent = pathMetric.getTangentForOffset(distance);
      if (tangent != null) {
        final double currentDist = (point - tangent.position).distance;
        if (currentDist <= tolerance && currentDist < minDist) {
          minDist = currentDist;
          closestDistance = distance;
        }
      }
    }

    return closestDistance;
  }

  /// Update progress based on drawn ranges (continuous line tracking)
  void _updateProgress() {
    if (totalPathLength == 0) return;

    double drawnLength = 0;
    double actualTotalLength = 0;

    // Calculate both drawn length and actual total length from path segments
    // This handles cases where SVGs have overlapping paths
    for (
      int segmentIndex = 0;
      segmentIndex < pathSegments.length;
      segmentIndex++
    ) {
      final segmentLength = pathSegments[segmentIndex].length;
      actualTotalLength += segmentLength;

      // Sum up all drawn ranges for this segment
      for (var range in drawnRanges[segmentIndex]) {
        drawnLength += range[1] - range[0];
      }
    }

    // Use actualTotalLength if it differs from totalPathLength
    // This happens when the SVG has multiple overlapping paths
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
  List<List<List<double>>> get getDrawnRanges => drawnRanges;
}
