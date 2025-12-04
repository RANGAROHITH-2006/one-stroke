import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:singlelinedraw/svg_path_parser.dart';

/// Draw Controller
/// Manages the drawing interaction, path validation, and game state
/// Handles gesture recognition, progress tracking, and completion detection
class DrawController extends ChangeNotifier {
  // Game state
  bool isDrawing = false;
  bool isGameCompleted = false;
  double progress = 0.0;
  String? errorMessage;
  
  // Drawing data
  List<Offset> userPath = [];
  Path? svgPath;
  double tolerance = 16.0; // Hit detection tolerance in pixels
  
  // Continuous range-based tracking (instead of discrete dots)
  // Each segment has a list of drawn ranges [start, end] along its length
  List<List<List<double>>> drawnRanges = []; // [segmentIndex][rangeIndex][start, end]
  
  // Path metrics
  List<ui.PathMetric> pathSegments = [];
  double totalPathLength = 0.0;
  
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
      progress = 0.0;
      errorMessage = null;
      
      // Mark starting segment as drawn
      _markSegmentAsDrawn(localPosition);
      
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
        _fillPathBetween(userPath[userPath.length - 2], localPosition);
      }
      
      _markSegmentAsDrawn(localPosition);
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
    onGameReset?.call();
    notifyListeners();
  }
  
  /// Check if a point is on or near the SVG path
  bool _isPointOnPath(Offset point) {
    if (svgPath == null) return false;
    
    for (ui.PathMetric pathMetric in pathSegments) {
      final length = pathMetric.length;
      
      // Check points along the path with smaller steps for better accuracy
      for (double distance = 0; distance < length; distance += 1) {
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
  
  /// Mark a point on the path as drawn - only marks the closest segment
  void _markSegmentAsDrawn(Offset point) {
    // Find the single closest point across ALL segments
    int? bestSegmentIndex;
    double? bestDistance;
    double bestMinDist = double.infinity;
    
    for (int segmentIndex = 0; segmentIndex < pathSegments.length; segmentIndex++) {
      final pathMetric = pathSegments[segmentIndex];
      final length = pathMetric.length;
      
      for (double distance = 0; distance <= length; distance += 1) {
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
    
    // Only mark the single closest segment
    if (bestSegmentIndex != null && bestDistance != null) {
      final length = pathSegments[bestSegmentIndex].length;
      // Add a small range around this point
      double rangeStart = (bestDistance - tolerance / 2).clamp(0, length);
      double rangeEnd = (bestDistance + tolerance / 2).clamp(0, length);
      _addRange(bestSegmentIndex, rangeStart, rangeEnd);
    }
  }
  
  /// Add a range to a segment, merging with existing overlapping ranges
  void _addRange(int segmentIndex, double start, double end) {
    if (segmentIndex >= drawnRanges.length) return;
    
    List<List<double>> ranges = drawnRanges[segmentIndex];
    
    // Find overlapping or adjacent ranges and merge
    List<List<double>> newRanges = [];
    
    for (var range in ranges) {
      // Check if ranges overlap or are adjacent (within 2 pixels)
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
        finalRanges.last[1] = finalRanges.last[1] > range[1] ? finalRanges.last[1] : range[1];
      }
    }
    
    drawnRanges[segmentIndex] = finalRanges;
  }
  
  /// Fill path segments between two points - only fills if points are consecutive on the path
  void _fillPathBetween(Offset startPoint, Offset endPoint) {
    // Calculate the screen distance between the two touch points
    double screenDistance = (endPoint - startPoint).distance;
    
    // Only fill between points if they are close on screen (prevents jumping across path)
    // This prevents the bug where touching near two different parts of the path
    // would fill the entire range between them
    if (screenDistance > tolerance * 3) {
      // Points are too far apart on screen, just mark them individually
      _markSegmentAsDrawn(startPoint);
      _markSegmentAsDrawn(endPoint);
      return;
    }
    
    // For each segment, find if we can trace a continuous line between the two points
    for (int segmentIndex = 0; segmentIndex < pathSegments.length; segmentIndex++) {
      final pathMetric = pathSegments[segmentIndex];
      final length = pathMetric.length;
      
      // Find closest distances on path for both points
      double? startDist = _findClosestDistanceOnSegment(startPoint, segmentIndex);
      double? endDist = _findClosestDistanceOnSegment(endPoint, segmentIndex);
      
      if (startDist != null && endDist != null) {
        // Calculate the path distance between the two points
        double pathDistance = (startDist - endDist).abs();
        
        // Only fill if the path distance is reasonable (not jumping across the shape)
        // The path distance should be similar to the screen distance
        // Allow some margin for curved paths
        if (pathDistance <= screenDistance * 2 + tolerance * 2) {
          double rangeStart = (startDist < endDist ? startDist : endDist);
          double rangeEnd = (startDist > endDist ? startDist : endDist);
          _addRange(segmentIndex, rangeStart.clamp(0, length), rangeEnd.clamp(0, length));
        }
      }
    }
    
    // Always mark the individual points
    _markSegmentAsDrawn(startPoint);
    _markSegmentAsDrawn(endPoint);
  }
  
  /// Find the closest distance along a segment for a given point
  double? _findClosestDistanceOnSegment(Offset point, int segmentIndex) {
    final pathMetric = pathSegments[segmentIndex];
    final length = pathMetric.length;
    
    double? closestDistance;
    double minDist = double.infinity;
    
    for (double distance = 0; distance <= length; distance += 1) {
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
    
    for (int segmentIndex = 0; segmentIndex < pathSegments.length; segmentIndex++) {
      // Sum up all drawn ranges for this segment
      for (var range in drawnRanges[segmentIndex]) {
        drawnLength += range[1] - range[0];
      }
    }
    
    progress = (drawnLength / totalPathLength).clamp(0.0, 1.0);
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
      if (errorMessage == message) { // Only reset if error hasn't changed
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