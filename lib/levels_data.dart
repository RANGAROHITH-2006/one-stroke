class LevelData {
  final int levelNumber;
  final String svgPath;
  final bool isCompleted;
  final bool isUnlocked;

  const LevelData({
    required this.levelNumber,
    required this.svgPath,
    required this.isCompleted,
    required this.isUnlocked,
  });
}

class LevelsData {
  static const List<LevelData> levels = [
    LevelData(
      levelNumber: 1,
      svgPath: 'assets/svg/Level1.svg',
      isCompleted: false,
      isUnlocked: true,
    ),
    LevelData(
      levelNumber: 2,
      svgPath: 'assets/svg/Level2.svg',
      isCompleted: false,
      isUnlocked: true,
    ),
    LevelData(
      levelNumber: 3,
      svgPath: 'assets/svg/Level3.svg',
      isCompleted: false,
      isUnlocked: true,
    ),
    LevelData(
      levelNumber: 4,
      svgPath: 'assets/svg/Level4.svg',
      isCompleted: false,
      isUnlocked: true,
    ),
    LevelData(
      levelNumber: 5,
      svgPath: 'assets/svg/Level5.svg',
      isCompleted: false,
      isUnlocked: true,
    ),
    LevelData(
      levelNumber: 6,
      svgPath: 'assets/svg/Level6.svg', // Using home.svg as fallback for level 6
      isCompleted: false,
      isUnlocked: true,
    ),
    LevelData(
      levelNumber: 7,
      svgPath: 'assets/svg/Level7.svg', // Using home.svg as fallback for level 7
      isCompleted: false,
      isUnlocked: true,
    ),
    LevelData(
      levelNumber: 8,
      svgPath: 'assets/svg/Level8.svg', // Using home.svg as fallback for level 7
      isCompleted: false,
      isUnlocked: true,
    ),
    LevelData(
      levelNumber: 8,
      svgPath: 'assets/svg/Level9.svg', // Using home.svg as fallback for level 7
      isCompleted: false,
      isUnlocked: true,
    ),
  ];

  static LevelData? getLevelData(int levelNumber) {
    try {
      return levels.firstWhere((level) => level.levelNumber == levelNumber);
    } catch (e) {
      return null;
    }
  }

  static String getLevelSvgPath(int levelNumber) {
    final levelData = getLevelData(levelNumber);
    return levelData?.svgPath ?? 'assets/svg/home.svg';
  }

  static bool isLevelCompleted(int levelNumber) {
    final levelData = getLevelData(levelNumber);
    return levelData?.isCompleted ?? false;
  }

  static bool isLevelUnlocked(int levelNumber) {
    final levelData = getLevelData(levelNumber);
    return levelData?.isUnlocked ?? false;
  }
}
