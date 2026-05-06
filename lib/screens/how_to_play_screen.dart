import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/audio_manager.dart';
import '../utils/storage_manager.dart';
import 'gameplay_screen.dart';

class HowToPlayScreen extends StatefulWidget {
  const HowToPlayScreen({super.key});

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _tutorialPages = [
    {
      'title': 'WELCOME',
      'description': 'Guide the ball into the glowing green target hole using precision control. Inspired by the classic 1983 arcade game "Ice Cold Beer" by Taito.',
      'icon': Icons.sports_esports,
      'color': GameConstants.goldColor,
    },
    {
      'title': 'DUAL JOYSTICKS',
      'description': 'Use the LEFT joystick (red) to control the left end of the bar, and the RIGHT joystick (blue) to control the right end. Slide up and down to tilt!',
      'icon': Icons.gamepad,
      'color': GameConstants.neonRed,
    },
    {
      'title': 'PHYSICS',
      'description': 'The ball rolls based on gravity and the bar angle. Be gentle! Sudden movements will make the ball fall. Master the physics to win.',
      'icon': Icons.science,
      'color': GameConstants.neonBlue,
    },
    {
      'title': 'TARGETS',
      'description': 'Guide the ball into the GREEN glowing hole to advance. Avoid RED danger holes - they will end your game! Higher levels = more difficulty.',
      'icon': Icons.flag,
      'color': GameConstants.neonGreen,
    },
    {
      'title': 'TIPS',
      'description': '- Small movements are key\n- Balance both sides carefully\n- Watch the timer!\n- Higher levels have moving holes\n- Bumper pegs appear later',
      'icon': Icons.lightbulb,
      'color': Colors.amber,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/menu_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          
          // Dark overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.85),
            ),
          ),
          
          // Content
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          AudioManager.instance.playClick();
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'HOW TO PLAY',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: GameConstants.goldColor,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Page indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _tutorialPages.length,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? GameConstants.goldColor
                            : Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Tutorial pages
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    itemCount: _tutorialPages.length,
                    itemBuilder: (context, index) {
                      final page = _tutorialPages[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (page['color'] as Color).withOpacity(0.2),
                                border: Border.all(
                                  color: (page['color'] as Color).withOpacity(0.5),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                page['icon'] as IconData,
                                size: 50,
                                color: page['color'] as Color,
                              ),
                            ),
                            
                            const SizedBox(height: 30),
                            
                            // Title
                            Text(
                              page['title'] as String,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: page['color'] as Color,
                                letterSpacing: 3,
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Description
                            Text(
                              page['description'] as String,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.8),
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                // Navigation buttons
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      if (_currentPage > 0)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              AudioManager.instance.playClick();
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'BACK',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      
                      const SizedBox(width: 12),
                      
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            AudioManager.instance.playClick();
                            if (_currentPage < _tutorialPages.length - 1) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              // Finish tutorial
                              StorageManager.instance.saveTutorialSeen(true);
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const GameplayScreen(
                                    startLevel: 1,
                                  ),
                                ),
                              );
                            }
                          },
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  GameConstants.goldColor,
                                  GameConstants.darkGold,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: GameConstants.goldColor.withOpacity(0.4),
                                  blurRadius: 15,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _currentPage < _tutorialPages.length - 1
                                    ? 'NEXT'
                                    : 'PLAY NOW',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
