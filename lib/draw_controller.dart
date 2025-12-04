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
  Set<String> drawnSegments = {};
  Path? svgPath;
  double tolerance = 16.0; // Hit detection tolerance in pixels
  
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
      drawnSegments.clear();
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
      
      // Check for completion
      if (progress >= 1) { // 100% completion threshold
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
    drawnSegments.clear();
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
  
  /// Mark a point on the path as drawn
  void _markSegmentAsDrawn(Offset point) {
    for (int segmentIndex = 0; segmentIndex < pathSegments.length; segmentIndex++) {
      final pathMetric = pathSegments[segmentIndex];
      final length = pathMetric.length;
      
      for (double distance = 0; distance < length; distance += 1) {
        final ui.Tangent? tangent = pathMetric.getTangentForOffset(distance);
        if (tangent != null) {
          final double currentDistance = (point - tangent.position).distance;
          if (currentDistance <= tolerance) {
            // Create a unique identifier for this segment
            int discretePosition = (distance / length * 200).round();
            String segmentId = '${segmentIndex}_$discretePosition';
            drawnSegments.add(segmentId);
          }
        }
      }
    }
  }
  
  /// Fill path segments between two points
  void _fillPathBetween(Offset startPoint, Offset endPoint) {
    // Find the closest path segments for both points
    _markSegmentAsDrawn(startPoint);
    _markSegmentAsDrawn(endPoint);
    
    // Interpolate points between start and end for smoother path filling
    const int steps = 20; // Increased from 10 for better coverage
    for (int i = 1; i < steps; i++) {
      double t = i / steps;
      Offset interpolatedPoint = Offset(
        startPoint.dx + (endPoint.dx - startPoint.dx) * t,
        startPoint.dy + (endPoint.dy - startPoint.dy) * t,
      );
      
      if (_isPointOnPath(interpolatedPoint)) {
        _markSegmentAsDrawn(interpolatedPoint);
      }
    }
  }
  
  /// Update progress based on drawn segments
  void _updateProgress() {
    if (totalPathLength == 0) return;
    
    // Calculate drawn length based on unique segments
    double drawnLength = 0;
    Set<String> uniqueSegments = drawnSegments;
    
    // Each unique segment represents a portion of the total path
    for (int segmentIndex = 0; segmentIndex < pathSegments.length; segmentIndex++) {
      double segmentLength = pathSegments[segmentIndex].length;
      
      // Count how many discrete positions are drawn for this segment
      int drawnPositions = 0;
      for (int position = 0; position <= 200; position++) {
        if (uniqueSegments.contains('${segmentIndex}_$position')) {
          drawnPositions++;
        }
      }
      
      // Calculate percentage of this segment that's drawn
      double segmentProgress = drawnPositions / 200.0;
      drawnLength += segmentLength * segmentProgress;
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
}