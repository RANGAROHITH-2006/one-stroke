import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';
import 'package:path_drawing/path_drawing.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;

/// SVG Path Parser
/// Handles loading SVG files and converting path data to Flutter Path objects
/// Also manages scaling and transformation for proper display on screen
/// Now includes vertex extraction for proper segment-based drawing
class SvgPathParser {
  /// Load and parse SVG file from assets
  static Future<SvgPathData> loadSvgPath(String assetPath) async {
    try {
      // Load the SVG file as string
      final svgString = await rootBundle.loadString(assetPath);
      
      // Parse the XML
      final document = XmlDocument.parse(svgString);
      
      // Get viewBox dimensions from SVG element
      final svgElement = document.findAllElements('svg').first;
      double svgViewBoxWidth = 100;
      double svgViewBoxHeight = 100;
      
      final viewBox = svgElement.getAttribute('viewBox');
      if (viewBox != null) {
        final parts = viewBox.split(' ');
        if (parts.length >= 4) {
          svgViewBoxWidth = double.parse(parts[2]);
          svgViewBoxHeight = double.parse(parts[3]);
        }
      }
      
      // Find all path elements and combine them
      final pathElements = document.findAllElements('path');
      Path combinedPath = Path();
      List<Offset> allVertices = [];
      
      for (var pathElement in pathElements) {
        final pathData = pathElement.getAttribute('d');
        if (pathData != null) {
          // Parse the SVG path data into a Flutter Path
          final parsedPath = parseSvgPathData(pathData);
          combinedPath.addPath(parsedPath, Offset.zero);
          
          // Extract vertices from this path
          final vertices = _extractVerticesFromPathData(pathData);
          allVertices.addAll(vertices);
        }
      }
      
      // Remove duplicate vertices that are too close together
      allVertices = _removeDuplicateVertices(allVertices, 5.0);
      
      // Add intersection vertices for complex paths
      allVertices.addAll(_detectPathIntersections(combinedPath));
      allVertices = _removeDuplicateVertices(allVertices, 5.0);
      
      // Remove collinear points to reduce false vertices
      allVertices = _removeCollinearVertices(allVertices, angleThreshold: 8.0);
      
      // Ensure minimum vertices by sampling the path if needed
      if (allVertices.length < 3) {
        allVertices = _sampleVerticesFromPath(combinedPath, 6);
      }
      
      return SvgPathData(
        path: combinedPath,
        viewBoxWidth: svgViewBoxWidth,
        viewBoxHeight: svgViewBoxHeight,
        vertices: allVertices,
      );
    } catch (e) {
      throw Exception('Error loading SVG path from $assetPath: $e');
    }
  }
  
  /// Extract vertex points from SVG path data string
  /// Only extracts ACTUAL corner/edge points on the path border
  /// Ignores control points from curves to avoid unwanted points
  static List<Offset> _extractVerticesFromPathData(String pathData) {
    List<Offset> vertices = [];
    
    // Current position tracking
    double currentX = 0;
    double currentY = 0;
    double startX = 0; // For Z command
    double startY = 0;
    
    // Regex to match SVG path commands
    final commandRegex = RegExp(r'([MmLlHhVvCcSsQqTtAaZz])([^MmLlHhVvCcSsQqTtAaZz]*)');
    
    for (final match in commandRegex.allMatches(pathData)) {
      final command = match.group(1)!;
      final argsStr = match.group(2)?.trim() ?? '';
      
      // Parse numbers from arguments
      final numbers = _parseNumbers(argsStr);
      
      switch (command) {
        case 'M': // Absolute moveto
          if (numbers.length >= 2) {
            currentX = numbers[0];
            currentY = numbers[1];
            startX = currentX;
            startY = currentY;
            vertices.add(Offset(currentX, currentY));
            
            // Additional pairs are treated as lineto
            for (int i = 2; i < numbers.length - 1; i += 2) {
              currentX = numbers[i];
              currentY = numbers[i + 1];
              vertices.add(Offset(currentX, currentY));
            }
          }
          break;
          
        case 'm': // Relative moveto
          if (numbers.length >= 2) {
            currentX += numbers[0];
            currentY += numbers[1];
            startX = currentX;
            startY = currentY;
            vertices.add(Offset(currentX, currentY));
            
            for (int i = 2; i < numbers.length - 1; i += 2) {
              currentX += numbers[i];
              currentY += numbers[i + 1];
              vertices.add(Offset(currentX, currentY));
            }
          }
          break;
          
        case 'L': // Absolute lineto
          for (int i = 0; i < numbers.length - 1; i += 2) {
            currentX = numbers[i];
            currentY = numbers[i + 1];
            vertices.add(Offset(currentX, currentY));
          }
          break;
          
        case 'l': // Relative lineto
          for (int i = 0; i < numbers.length - 1; i += 2) {
            currentX += numbers[i];
            currentY += numbers[i + 1];
            vertices.add(Offset(currentX, currentY));
          }
          break;
          
        case 'H': // Absolute horizontal lineto
          for (int i = 0; i < numbers.length; i++) {
            currentX = numbers[i];
            vertices.add(Offset(currentX, currentY));
          }
          break;
          
        case 'h': // Relative horizontal lineto
          for (int i = 0; i < numbers.length; i++) {
            currentX += numbers[i];
            vertices.add(Offset(currentX, currentY));
          }
          break;
          
        case 'V': // Absolute vertical lineto
          for (int i = 0; i < numbers.length; i++) {
            currentY = numbers[i];
            vertices.add(Offset(currentX, currentY));
          }
          break;
          
        case 'v': // Relative vertical lineto
          for (int i = 0; i < numbers.length; i++) {
            currentY += numbers[i];
            vertices.add(Offset(currentX, currentY));
          }
          break;
          
        case 'C': // Absolute cubic bezier - ONLY endpoint, skip control points
          for (int i = 0; i < numbers.length - 5; i += 6) {
            // Skip control points [i], [i+1], [i+2], [i+3]
            // Only add the ENDPOINT which is on the actual path border
            currentX = numbers[i + 4];
            currentY = numbers[i + 5];
            vertices.add(Offset(currentX, currentY));
          }
          break;
          
        case 'c': // Relative cubic bezier - ONLY endpoint
          for (int i = 0; i < numbers.length - 5; i += 6) {
            // Skip control points, only endpoint
            currentX += numbers[i + 4];
            currentY += numbers[i + 5];
            vertices.add(Offset(currentX, currentY));
          }
          break;
          
        case 'S': // Absolute smooth cubic bezier - ONLY endpoint
          for (int i = 0; i < numbers.length - 3; i += 4) {
            // Skip control point [i], [i+1]
            // Only add endpoint
            currentX = numbers[i + 2];
            currentY = numbers[i + 3];
            vertices.add(Offset(currentX, currentY));
          }
          break;
          
        case 's': // Relative smooth cubic bezier - ONLY endpoint
          for (int i = 0; i < numbers.length - 3; i += 4) {
            // Skip control point, only endpoint
            currentX += numbers[i + 2];
            currentY += numbers[i + 3];
            vertices.add(Offset(currentX, currentY));
          }
          break;
          
        case 'Q': // Absolute quadratic bezier - ONLY endpoint
          for (int i = 0; i < numbers.length - 3; i += 4) {
            // Skip control point [i], [i+1]
            // Only add endpoint
            currentX = numbers[i + 2];
            currentY = numbers[i + 3];
            vertices.add(Offset(currentX, currentY));
          }
          break;
          
        case 'q': // Relative quadratic bezier - ONLY endpoint
          for (int i = 0; i < numbers.length - 3; i += 4) {
            // Skip control point, only endpoint
            currentX += numbers[i + 2];
            currentY += numbers[i + 3];
            vertices.add(Offset(currentX, currentY));
          }
          break;
          
        case 'T': // Absolute smooth quadratic bezier - endpoint only
          for (int i = 0; i < numbers.length - 1; i += 2) {
            currentX = numbers[i];
            currentY = numbers[i + 1];
            vertices.add(Offset(currentX, currentY));
          }
          break;
          
        case 't': // Relative smooth quadratic bezier - endpoint only
          for (int i = 0; i < numbers.length - 1; i += 2) {
            currentX += numbers[i];
            currentY += numbers[i + 1];
            vertices.add(Offset(currentX, currentY));
          }
          break;
          
        case 'A': // Absolute arc - ONLY endpoint, no intermediate points
          for (int i = 0; i < numbers.length - 6; i += 7) {
            // Only add the actual endpoint of the arc
            currentX = numbers[i + 5];
            currentY = numbers[i + 6];
            vertices.add(Offset(currentX, currentY));
          }
          break;
          
        case 'a': // Relative arc - ONLY endpoint
          for (int i = 0; i < numbers.length - 6; i += 7) {
            // Only add endpoint
            currentX += numbers[i + 5];
            currentY += numbers[i + 6];
            vertices.add(Offset(currentX, currentY));
          }
          break;
          
        case 'Z':
        case 'z': // Closepath
          // Only add closing point if it's different from start
          if ((currentX - startX).abs() > 1 || (currentY - startY).abs() > 1) {
            vertices.add(Offset(startX, startY));
          }
          currentX = startX;
          currentY = startY;
          break;
      }
    }
    
    return vertices;
  }
  
  /// Parse numbers from SVG path argument string
  static List<double> _parseNumbers(String str) {
    if (str.isEmpty) return [];
    
    // Handle scientific notation and negative numbers
    final regex = RegExp(r'-?[\d.]+(?:e[+-]?\d+)?', caseSensitive: false);
    final matches = regex.allMatches(str);
    
    return matches.map((m) => double.tryParse(m.group(0)!) ?? 0.0).toList();
  }
  
  /// Remove collinear vertices (points that don't significantly change direction)
  static List<Offset> _removeCollinearVertices(
    List<Offset> vertices,
    {double angleThreshold = 8.0,
  }) {
    if (vertices.length < 3) return vertices;

    final result = <Offset>[vertices.first];
    final threshold = angleThreshold * 3.14159 / 180; // Convert to radians

    for (int i = 1; i < vertices.length - 1; i++) {
      final prev = vertices[i - 1];
      final current = vertices[i];
      final next = vertices[i + 1];

      // Calculate vectors
      final v1x = current.dx - prev.dx;
      final v1y = current.dy - prev.dy;
      final v2x = next.dx - current.dx;
      final v2y = next.dy - current.dy;

      // Calculate angle between vectors using dot product
      final dot = v1x * v2x + v1y * v2y;
      final mag1 = math.sqrt(v1x * v1x + v1y * v1y);
      final mag2 = math.sqrt(v2x * v2x + v2y * v2y);

      if (mag1 > 1.0 && mag2 > 1.0) {
        final cosAngle = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
        final angle = math.acos(cosAngle);

        // Keep points where direction changes significantly
        // or if the point is far from both neighbors
        if (angle > threshold || mag1 > 50 || mag2 > 50) {
          result.add(current);
        }
      } else {
        // Keep if segments are very short (might be important corners)
        result.add(current);
      }
    }

    result.add(vertices.last);
    return result;
  }

  /// Remove duplicate vertices that are too close together
  static List<Offset> _removeDuplicateVertices(List<Offset> vertices, double threshold) {
    if (vertices.isEmpty) return vertices;
    
    List<Offset> result = [vertices.first];
    
    for (int i = 1; i < vertices.length; i++) {
      bool isDuplicate = false;
      for (var existing in result) {
        if ((vertices[i] - existing).distance < threshold) {
          isDuplicate = true;
          break;
        }
      }
      if (!isDuplicate) {
        result.add(vertices[i]);
      }
    }
    
    return result;
  }
  
  /// Sample vertices evenly from a path if not enough vertices were extracted
  static List<Offset> _sampleVerticesFromPath(Path path, int minVertices) {
    List<Offset> vertices = [];
    
    final metrics = path.computeMetrics();
    for (var metric in metrics) {
      final length = metric.length;
      final step = length / (minVertices - 1);
      
      for (int i = 0; i < minVertices; i++) {
        final distance = (i * step).clamp(0.0, length);
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          vertices.add(tangent.position);
        }
      }
    }
    
    return _removeDuplicateVertices(vertices, 5.0);
  }
  
  /// Detect path intersections and near-intersections
  /// This finds points where path segments come close together or cross
  /// Critical for complex shapes with internal structure like lattices
  static List<Offset> _detectPathIntersections(Path path) {
    List<Offset> intersectionPoints = [];
    
    // Get all path metrics (segments)
    final metrics = path.computeMetrics().toList();
    if (metrics.length < 2) return intersectionPoints;
    
    // Sample points densely from each segment
    List<List<Offset>> segmentSamples = [];
    for (var metric in metrics) {
      List<Offset> samples = [];
      final length = metric.length;
      // Sample every 5 pixels for good intersection detection
      final numSamples = (length / 5).ceil().clamp(5, 100);
      
      for (int i = 0; i < numSamples; i++) {
        final distance = (i / (numSamples - 1)) * length;
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          samples.add(tangent.position);
        }
      }
      segmentSamples.add(samples);
    }
    
    // Check for intersections between different segments
    // A point is considered an intersection if segments come within 3 pixels
    const intersectionThreshold = 3.0;
    
    for (int i = 0; i < segmentSamples.length; i++) {
      for (int j = i + 1; j < segmentSamples.length; j++) {
        final samples1 = segmentSamples[i];
        final samples2 = segmentSamples[j];
        
        // Check each point in segment1 against points in segment2
        for (var point1 in samples1) {
          for (var point2 in samples2) {
            final distance = (point1 - point2).distance;
            if (distance < intersectionThreshold) {
              // Found an intersection - add the midpoint
              final intersectionPoint = Offset(
                (point1.dx + point2.dx) / 2,
                (point1.dy + point2.dy) / 2,
              );
              intersectionPoints.add(intersectionPoint);
            }
          }
        }
      }
    }
    
    return intersectionPoints;
  }
  
  /// Transform and scale path to fit within container dimensions
  static Path transformPath(
    Path originalPath,
    double viewBoxWidth,
    double viewBoxHeight,
    double containerWidth,
    double containerHeight,
  ) {
    // Calculate scale to fit properly while maintaining aspect ratio
    double scaleX = containerWidth / viewBoxWidth;
    double scaleY = containerHeight / viewBoxHeight;
    double scale = scaleX < scaleY ? scaleX : scaleY;
    
    // Center the path in the container
    double scaledSvgWidth = viewBoxWidth * scale;
    double scaledSvgHeight = viewBoxHeight * scale;
    Offset offset = Offset(
      (containerWidth - scaledSvgWidth) / 2,
      (containerHeight - scaledSvgHeight) / 2,
    );
    
    // Create a matrix for scaling and translation
    final matrix = Matrix4.identity()
      ..translate(offset.dx, offset.dy)
      ..scale(scale, scale);
    
    // Apply transformation to the path
    return originalPath.transform(matrix.storage);
  }
  
  /// Transform vertices to fit within container dimensions
  static List<Offset> transformVertices(
    List<Offset> vertices,
    double viewBoxWidth,
    double viewBoxHeight,
    double containerWidth,
    double containerHeight,
  ) {
    // Calculate scale to fit properly while maintaining aspect ratio
    double scaleX = containerWidth / viewBoxWidth;
    double scaleY = containerHeight / viewBoxHeight;
    double scale = scaleX < scaleY ? scaleX : scaleY;
    
    // Center the path in the container
    double scaledSvgWidth = viewBoxWidth * scale;
    double scaledSvgHeight = viewBoxHeight * scale;
    double offsetX = (containerWidth - scaledSvgWidth) / 2;
    double offsetY = (containerHeight - scaledSvgHeight) / 2;
    
    return vertices.map((v) => Offset(
      v.dx * scale + offsetX,
      v.dy * scale + offsetY,
    )).toList();
  }
  
  /// Get total length of all path segments
  static double getPathLength(Path path) {
    final pathMetrics = path.computeMetrics();
    double totalLength = 0;
    for (var metric in pathMetrics) {
      totalLength += metric.length;
    }
    return totalLength;
  }
  
  /// Get all path segments with their metrics
  static List<ui.PathMetric> getPathSegments(Path path) {
    return path.computeMetrics().toList();
  }
  
  /// Extract line segments from a path with vertex information
  /// Each segment is defined by two vertices and the path distance between them
  static List<PathSegmentInfo> extractSegmentsWithVertices(
    Path transformedPath,
    List<Offset> transformedVertices,
  ) {
    List<PathSegmentInfo> segments = [];
    final metrics = transformedPath.computeMetrics().toList();
    
    if (metrics.isEmpty || transformedVertices.isEmpty) {
      return segments;
    }
    
    // For each path metric, find vertices that lie on it and create segments
    for (int metricIndex = 0; metricIndex < metrics.length; metricIndex++) {
      final metric = metrics[metricIndex];
      final length = metric.length;
      
      // Find all vertices on this path metric with their distances
      List<VertexOnPath> verticesOnPath = [];
      
      for (int vIndex = 0; vIndex < transformedVertices.length; vIndex++) {
        final vertex = transformedVertices[vIndex];
        final distanceOnPath = _findDistanceOnPath(metric, vertex, 15.0);
        
        if (distanceOnPath != null) {
          verticesOnPath.add(VertexOnPath(
            vertex: vertex,
            vertexIndex: vIndex,
            distanceOnPath: distanceOnPath,
          ));
        }
      }
      
      // Sort by distance on path
      verticesOnPath.sort((a, b) => a.distanceOnPath.compareTo(b.distanceOnPath));
      
      // If no vertices found on this path, add start and end points
      if (verticesOnPath.isEmpty) {
        final startTangent = metric.getTangentForOffset(0);
        final endTangent = metric.getTangentForOffset(length);
        
        if (startTangent != null && endTangent != null) {
          segments.add(PathSegmentInfo(
            pathMetricIndex: metricIndex,
            startVertex: startTangent.position,
            endVertex: endTangent.position,
            startDistance: 0,
            endDistance: length,
            startVertexIndex: -1,
            endVertexIndex: -1,
          ));
        }
        continue;
      }
      
      // Add segment from start to first vertex if needed
      if (verticesOnPath.first.distanceOnPath > 5.0) {
        final startTangent = metric.getTangentForOffset(0);
        if (startTangent != null) {
          segments.add(PathSegmentInfo(
            pathMetricIndex: metricIndex,
            startVertex: startTangent.position,
            endVertex: verticesOnPath.first.vertex,
            startDistance: 0,
            endDistance: verticesOnPath.first.distanceOnPath,
            startVertexIndex: -1,
            endVertexIndex: verticesOnPath.first.vertexIndex,
          ));
        }
      }
      
      // Create segments between consecutive vertices
      for (int i = 0; i < verticesOnPath.length - 1; i++) {
        segments.add(PathSegmentInfo(
          pathMetricIndex: metricIndex,
          startVertex: verticesOnPath[i].vertex,
          endVertex: verticesOnPath[i + 1].vertex,
          startDistance: verticesOnPath[i].distanceOnPath,
          endDistance: verticesOnPath[i + 1].distanceOnPath,
          startVertexIndex: verticesOnPath[i].vertexIndex,
          endVertexIndex: verticesOnPath[i + 1].vertexIndex,
        ));
      }
      
      // Add segment from last vertex to end if needed
      if (verticesOnPath.last.distanceOnPath < length - 5.0) {
        final endTangent = metric.getTangentForOffset(length);
        if (endTangent != null) {
          segments.add(PathSegmentInfo(
            pathMetricIndex: metricIndex,
            startVertex: verticesOnPath.last.vertex,
            endVertex: endTangent.position,
            startDistance: verticesOnPath.last.distanceOnPath,
            endDistance: length,
            startVertexIndex: verticesOnPath.last.vertexIndex,
            endVertexIndex: -1,
          ));
        }
      }
    }
    
    return segments;
  }
  
  /// Find the distance along a path metric where a point lies
  static double? _findDistanceOnPath(ui.PathMetric metric, Offset point, double tolerance) {
    final length = metric.length;
    double? closestDistance;
    double minDist = double.infinity;
    
    // Sample along the path to find closest point
    for (double d = 0; d <= length; d += 2) {
      final tangent = metric.getTangentForOffset(d);
      if (tangent != null) {
        final dist = (point - tangent.position).distance;
        if (dist < tolerance && dist < minDist) {
          minDist = dist;
          closestDistance = d;
        }
      }
    }
    
    return closestDistance;
  }
}

/// Helper class for vertex location on path
class VertexOnPath {
  final Offset vertex;
  final int vertexIndex;
  final double distanceOnPath;
  
  const VertexOnPath({
    required this.vertex,
    required this.vertexIndex,
    required this.distanceOnPath,
  });
}

/// Information about a segment between two vertices
class PathSegmentInfo {
  final int pathMetricIndex;
  final Offset startVertex;
  final Offset endVertex;
  final double startDistance;
  final double endDistance;
  final int startVertexIndex;
  final int endVertexIndex;
  
  const PathSegmentInfo({
    required this.pathMetricIndex,
    required this.startVertex,
    required this.endVertex,
    required this.startDistance,
    required this.endDistance,
    required this.startVertexIndex,
    required this.endVertexIndex,
  });
  
  double get length => endDistance - startDistance;
}

/// Data class to hold SVG path information
class SvgPathData {
  final Path path;
  final double viewBoxWidth;
  final double viewBoxHeight;
  final List<Offset> vertices;
  
  const SvgPathData({
    required this.path,
    required this.viewBoxWidth,
    required this.viewBoxHeight,
    this.vertices = const [],
  });
}