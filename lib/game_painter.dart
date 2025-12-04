import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// Game Painter
/// Custom painter for rendering the SVG outline and user's drawing stroke
/// Handles visual feedback for the single line drawing game
class GamePainter extends CustomPainter {
  final Path? svgPath;
  final List<Offset> userPath;
  final Set<String> drawnSegments;
  final List<ui.PathMetric> pathSegments;
  final double progress;
  final bool isGameCompleted;
  final bool hasError;
  
  GamePainter({
    required this.svgPath,
    required this.userPath,
    required this.drawnSegments,
    required this.pathSegments,
    required this.progress,
    required this.isGameCompleted,
    required this.hasError,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (svgPath == null) return;
    
    // Draw the original SVG outline (gray/white) only for untraced parts
    _drawOriginalPath(canvas);
    
    // Draw the traced path segments (colored) - this will overlay the original path
    _drawTracedSegments(canvas);
    
    // Draw current touch point if actively drawing
    _drawTouchPoint(canvas);
  }
  
  /// Draw the original SVG path outline for untraced segments only
  void _drawOriginalPath(Canvas canvas) {
    if (pathSegments.isEmpty) return;
    
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    // Draw only the untraced segments
    for (int segmentIndex = 0; segmentIndex < pathSegments.length; segmentIndex++) {
      final pathMetric = pathSegments[segmentIndex];
      final totalLength = pathMetric.length;
      
      // Check which parts of this segment have NOT been drawn
      const int numSegments = 200;
      for (int i = 0; i < numSegments; i++) {
        String segmentId = '${segmentIndex}_$i';
        
        if (!drawnSegments.contains(segmentId)) {
          // Draw this untraced segment
          final startDistance = (i / numSegments) * totalLength;
          final endDistance = ((i + 1) / numSegments) * totalLength;
          
          try {
            final segmentPath = pathMetric.extractPath(startDistance, endDistance);
            canvas.drawPath(segmentPath, paint);
          } catch (e) {
            // Handle any path extraction errors gracefully
            continue;
          }
        }
      }
    }
  }
  
  /// Draw the segments that have been successfully traced
  void _drawTracedSegments(Canvas canvas) {
    if (pathSegments.isEmpty) return;
    
    // Determine color based on game state
    Color traceColor;
    if (isGameCompleted) {
      traceColor = const Color(0xFF34C759); // Green for completion
    } else if (hasError) {
      traceColor = const Color(0xFFFF3B30); // Red for error
    } else {
      traceColor = const Color(0xFF007AFF); // Blue for normal drawing
    }
    
    final paint = Paint()
      ..color = traceColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    // Draw each traced segment
    for (int segmentIndex = 0; segmentIndex < pathSegments.length; segmentIndex++) {
      final pathMetric = pathSegments[segmentIndex];
      final totalLength = pathMetric.length;
      
      // Check which parts of this segment have been drawn
      const int numSegments = 200;
      for (int i = 0; i < numSegments; i++) {
        String segmentId = '${segmentIndex}_$i';
        
        if (drawnSegments.contains(segmentId)) {
          // Draw this segment
          final startDistance = (i / numSegments) * totalLength;
          final endDistance = ((i + 1) / numSegments) * totalLength;
          
          try {
            final segmentPath = pathMetric.extractPath(startDistance, endDistance);
            canvas.drawPath(segmentPath, paint);
          } catch (e) {
            // Handle any path extraction errors gracefully
            continue;
          }
        }
      }
    }
  }
  

  
  /// Draw current touch point indicator
  void _drawTouchPoint(Canvas canvas) {
    if (userPath.isEmpty) return;
    
    final lastPoint = userPath.last;
    
    // Outer circle
    final outerPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    // Inner circle
    Color innerColor;
    if (isGameCompleted) {
      innerColor = const Color(0xFF34C759);
    } else if (hasError) {
      innerColor = const Color(0xFFFF3B30);
    } else {
      innerColor = const Color(0xFF007AFF);
    }
    
    final innerPaint = Paint()
      ..color = innerColor
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(lastPoint, 12.0, outerPaint);
    canvas.drawCircle(lastPoint, 8.0, innerPaint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is! GamePainter) return true;
    
    return oldDelegate.userPath.length != userPath.length ||
           oldDelegate.drawnSegments.length != drawnSegments.length ||
           oldDelegate.progress != progress ||
           oldDelegate.isGameCompleted != isGameCompleted ||
           oldDelegate.hasError != hasError;
  }
}

/// Progress Painter
/// Draws the circular progress indicator for level completion
class ProgressPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;
  
  ProgressPainter({
    required this.progress,
    this.progressColor = const Color(0xFF007AFF),
    this.backgroundColor = Colors.white24,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -pi / 2; // Start from top
    final sweepAngle = 2 * pi * progress;
    
    canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is! ProgressPainter) return true;
    return oldDelegate.progress != progress;
  }
}

/// Helper constant for π
const double pi = 3.14159265359;