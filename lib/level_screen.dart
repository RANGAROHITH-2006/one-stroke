import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:singlelinedraw/levels_data.dart';
import 'package:singlelinedraw/pause_screen.dart';

class LevelScreen extends StatefulWidget {
  final int levelNumber;

  const LevelScreen({super.key, required this.levelNumber});

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> {
  late LevelData? levelData;

  @override
  void initState() {
    super.initState();
    levelData = LevelsData.getLevelData(widget.levelNumber);
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

                    // Action buttons
                    Row(
                      children: [
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

              // Main game area with SVG - Direct display without card
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 30.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // SVG displayed directly with transparent background
                      Expanded(
                        child: Center(
                          child: levelData != null
                              ? SvgPicture.asset(
                                  levelData!.svgPath,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.contain,
                                  colorFilter: const ColorFilter.mode(
                                    Colors.white70,
                                    BlendMode.srcIn,
                                  ),
                                )
                              : const Icon(
                                  Icons.error_outline,
                                  size: 100,
                                  color: Colors.white54,
                                ),
                        ),
                      ),

                  
                     

                 
                  ],
                ),
              ),
           ) ],
          ),
        ),
      ),
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
                '• Draw a continuous line through all points',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              SizedBox(height: 8),
              Text(
                '• You cannot lift your finger or retrace a line',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              SizedBox(height: 8),
              Text(
                '• Complete the puzzle in one stroke',
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