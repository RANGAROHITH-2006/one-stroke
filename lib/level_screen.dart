import 'package:flutter/material.dart';
import 'package:singlelinedraw/levels_data.dart';
import 'package:singlelinedraw/pause_screen.dart';
import 'package:singlelinedraw/svg_path_parser.dart';
import 'package:singlelinedraw/draw_controller.dart';
import 'package:singlelinedraw/game_painter.dart';

class LevelScreen extends StatefulWidget {
  final int levelNumber;

  const LevelScreen({super.key, required this.levelNumber});

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> {
  late LevelData? levelData;
  late DrawController drawController;
  bool isLoading = true;
  Path? transformedSvgPath;
  
  @override
  void initState() {
    super.initState();
    levelData = LevelsData.getLevelData(widget.levelNumber);
    
    // Initialize draw controller with callbacks
    drawController = DrawController(
      onLevelComplete: _onLevelComplete,
      onGameReset: _onGameReset,
    );
    
    // Load SVG path
    _loadSvgPath();
  }
  
  @override
  void dispose() {
    drawController.dispose();
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
      
      // Initialize the draw controller with the transformed path
      drawController.initializeWithPath(transformedSvgPath!);
      
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
  
  /// Handle level completion
  void _onLevelComplete() {
    _showCompletionDialog();
  }
  
  /// Handle game reset
  void _onGameReset() {
    // Called when game resets - can add any additional logic here
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

                    // Level indicator with progress
                    AnimatedBuilder(
                      animation: drawController,
                      builder: (context, child) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Level ${widget.levelNumber}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (drawController.progress > 0) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '${drawController.completionPercentage}%',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),

                    // Action buttons
                    Row(
                      children: [
                        // Reset button
                        GestureDetector(
                          onTap: () => drawController.reset(),
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            // Open pause screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PauseScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.pause,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            // Help action
                            _showHelpDialog();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.help_outline,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Game status message
              AnimatedBuilder(
                animation: drawController,
                builder: (context, child) {
                  if (drawController.hasError) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              drawController.errorMessage!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (drawController.isGameCompleted) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Level Completed! 🎉',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
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

  /// Build the main game drawing area
  Widget _buildGameArea() {
    return Container(
      width: 300,
      height: 400,
      child: Stack(
        children: [
          // Interactive drawing overlay
          Positioned.fill(
            child: GestureDetector(
              onPanStart: drawController.onPanStart,
              onPanUpdate: drawController.onPanUpdate,
              onPanEnd: drawController.onPanEnd,
              child: AnimatedBuilder(
                animation: drawController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: GamePainter(
                      svgPath: transformedSvgPath,
                      userPath: drawController.userPath,
                      drawnRanges: drawController.getDrawnRanges,
                      pathSegments: drawController.pathSegments,
                      progress: drawController.progress,
                      isGameCompleted: drawController.isGameCompleted,
                      hasError: drawController.hasError,
                    ),
                  );
                },
              ),
            ),
          ),
          
          // // Instructions overlay (shows when not drawing)
          // AnimatedBuilder(
          //   animation: drawController,
          //   builder: (context, child) {
          //     if (!drawController.isDrawing && 
          //         drawController.userPath.isEmpty && 
          //         !drawController.isGameCompleted) {
          //       return Positioned(
          //         bottom: 0,
          //         left: 20,
          //         right: 20,
          //         child: Container(
          //           padding: const EdgeInsets.symmetric(
          //             horizontal: 16,
          //             vertical: 12,
          //           ),
          //           decoration: BoxDecoration(
          //             color: Colors.black.withOpacity(0.7),
          //             borderRadius: BorderRadius.circular(12),
          //           ),
          //           child: const Text(
          //             'Trace the outline in one continuous stroke',
          //             textAlign: TextAlign.center,
          //             style: TextStyle(
          //               color: Colors.white,
          //               fontSize: 14,
          //               fontWeight: FontWeight.w500,
          //             ),
          //           ),
          //         ),
          //       );
          //     }
          //     return const SizedBox.shrink();
          //   },
          // ),
        ],
      ),
    );
  }

  /// Show completion dialog
  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Celebration icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFF34C759),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Title
                Text(
                  'Level ${widget.levelNumber} Completed!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                
                // Subtitle
                const Text(
                  'Great job! You traced the entire outline perfectly.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Buttons
                Row(
                  children: [
                    // Try Again button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          drawController.reset();
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF007AFF)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Try Again',
                          style: TextStyle(
                            color: Color(0xFF007AFF),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Next Level / Home button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          if (widget.levelNumber < LevelsData.levels.length) {
                            // Go to next level
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LevelScreen(
                                  levelNumber: widget.levelNumber + 1,
                                ),
                              ),
                            );
                          } else {
                            // Go back to home
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          widget.levelNumber < LevelsData.levels.length
                              ? 'Next Level'
                              : 'Home',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Level ${widget.levelNumber} - Help',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '• Trace the entire outline in one continuous stroke',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              SizedBox(height: 8),
              Text(
                '• Do not lift your finger or go outside the path',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              SizedBox(height: 8),
              Text(
                '• Stay within the white outline to continue drawing',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              SizedBox(height: 8),
              Text(
                '• Complete the full path to finish the level',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Got it!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF007AFF),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}