import 'package:flutter/material.dart';
import 'package:singlelinedraw/levels_data.dart';
import 'package:singlelinedraw/svg_path_parser.dart';

class LevelScreen extends StatefulWidget {
  final int levelNumber;

  const LevelScreen({super.key, required this.levelNumber});

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> {
  late LevelData? levelData;
  bool isLoading = true;
  Path? transformedSvgPath;
  
  @override
  void initState() {
    super.initState();
    levelData = LevelsData.getLevelData(widget.levelNumber);
    
    // Load SVG path
    _loadSvgPath();
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  /// Load and process SVG path for the current level
  Future<void> _loadSvgPath() async {
    if (levelData == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }
    
    try {
      // Load SVG path data
      final svgPathData = await SvgPathParser.loadSvgPath(levelData!.svgPath);
      
      // Transform path to fit the game area (calculate container size)
      const double containerWidth = 300;  // Game area width
      const double containerHeight = 400; // Game area height
      
      transformedSvgPath = SvgPathParser.transformPath(
        svgPathData.path,
        svgPathData.viewBoxWidth,
        svgPathData.viewBoxHeight,
        containerWidth,
        containerHeight,
      );
      
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading SVG path: $e');
      setState(() {
        isLoading = false;
      });
    }
  }
  


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/backgroundimage.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top navigation bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),

                    // Level indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Level ${widget.levelNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(width: 48),
                  ],
                ),
              ),



              // Main game area
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 30.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Game drawing area
                      Expanded(
                        child: Center(
                          child: isLoading
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Loading level...',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                )
                              : _buildGameArea(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the main game area
  Widget _buildGameArea() {
    return transformedSvgPath != null
        ? CustomPaint(
            size: const Size(300, 400),
            painter: SimpleSvgPainter(svgPath: transformedSvgPath!),
          )
        : const Text(
            'No path available',
            style: TextStyle(color: Colors.white70),
          );
  }

}


/// Simple SVG Painter - just displays the SVG path outline
class SimpleSvgPainter extends CustomPainter {
  final Path svgPath;

  SimpleSvgPainter({required this.svgPath});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(svgPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}