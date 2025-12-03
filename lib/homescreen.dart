import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
// import 'package:singlelinedraw/pause_screen.dart';
import 'package:singlelinedraw/levels_data.dart';
import 'package:singlelinedraw/level_screen.dart';

class SingleLineGameScreen extends StatelessWidget {
  const SingleLineGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(
        255,
        32,
        1,
        52,
      ), // Purple background
      body: SafeArea(
        child: Column(
          children: [
            // Top section with navigation and game preview
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  children: [
                    // Navigation bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            child: const Icon(
                              Icons.arrow_back_ios,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            // GestureDetector(
                            //   onTap: () {
                            //     // Open pause screen
                            //     Navigator.push(
                            //       context,
                            //       MaterialPageRoute(
                            //         builder: (context) => const PauseScreen(),
                            //       ),
                            //     );
                            //   },
                            //   child: Container(
                            //     padding: const EdgeInsets.all(8.0),
                            //     child: const Icon(
                            //       Icons.pause,
                            //       color: Colors.white,
                            //       size: 24,
                            //     ),
                            //   ),
                            // ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                // Help action
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8.0),
                                child: const Icon(
                                  Icons.help_outline,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                // Share action
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8.0),
                                child: const Icon(
                                  Icons.share,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Game preview area
                    Expanded(
                      child: SvgPicture.asset(
                        'assets/svg/home.svg',
                        width: 150,
                        height: 150,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom sheet
            Expanded(
              flex: 7,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header section
                        const Text(
                          'Games',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF007AFF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Single Line',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Levels section
                        const Text(
                          'Levels',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Level selector
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: LevelsData.levels.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 10.0),
                                child: LevelItem(
                                  levelNumber: index + 1,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => LevelScreen(
                                              levelNumber: index + 1,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Benefits section
                        const Text(
                          'Benefits',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),

                        const BenefitItem(
                          icon: Icons.center_focus_strong_outlined,
                          title: 'Selective attention',
                          description:
                              'Improve your ability to focus on relevant details while ignoring distractions.',
                        ),
                        const SizedBox(height: 16),
                        const BenefitItem(
                          icon: Icons.swap_horiz_outlined,
                          title: 'Cognitive flexibility',
                          description:
                              'Enhance your ability to alternate between different concepts or tasks.',
                        ),
                        const SizedBox(height: 16),
                        const BenefitItem(
                          icon: Icons.speed_outlined,
                          title: 'Visual processing speed',
                          description:
                              'Boost the speed at which you process and react to visual information.',
                        ),

                        const SizedBox(height: 24),

                        // Play Game button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              // Start game with level 1
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          const LevelScreen(levelNumber: 1),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF007AFF),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Play Game',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 32,
                        ), // Add bottom padding for scroll
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LevelItem extends StatelessWidget {
  final int levelNumber;
  final VoidCallback? onTap;

  const LevelItem({super.key, required this.levelNumber, this.onTap});

  @override
  Widget build(BuildContext context) {
    final levelData = LevelsData.getLevelData(levelNumber);
    late Widget icon;

    if (levelData != null) {
      if (levelData.isCompleted) {
        // Completed level - green check
        icon = Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0xFF34C759),
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 24),
        );
      } else if (levelData.isUnlocked) {
        // Playable level - blue play
        icon = Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0xFF007AFF),
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
        );
      } else {
        // Locked level - grey lock
        icon = Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0xFFD1D1D6),
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: const Icon(Icons.lock, color: Colors.white, size: 24),
        );
      }
    } else {
      // Default locked state
      icon = Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0xFFD1D1D6),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.lock, color: Colors.white, size: 24),
      );
    }

    return GestureDetector(
      onTap: levelData?.isUnlocked == true ? onTap : null,
      child: Column(
        children: [
          icon,
          const SizedBox(height: 8),
          Text(
            '$levelNumber',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class BenefitItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const BenefitItem({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFF007AFF),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6D6D80),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
