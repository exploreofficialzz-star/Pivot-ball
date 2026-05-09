import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/audio_manager.dart';
import '../utils/storage_manager.dart';
import '../utils/ad_manager.dart';
import 'gameplay_screen.dart';
import 'leaderboard_screen.dart';
import 'store_screen.dart';
import '../utils/purchase_manager.dart';
import 'settings_screen.dart';
import 'how_to_play_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _titleBounce;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    AudioManager.instance.resumeMusic();
    
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _titleBounce = Tween<double>(begin: -50, end: 0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.5, curve: Curves.bounceOut),
      ),
    );
    
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );
    
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _navigateTo(Widget screen) {
    AudioManager.instance.playClick();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, anim, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

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
          
          // Fixed banner at very bottom — always visible
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: AdManager.instance.buildBannerAd(showNudge: true),
          ),

          // Dark overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.25),
                    Colors.black.withOpacity(0.55),
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
          ),
          
          // Content
          SafeArea(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Column(
                  children: [
                    const SizedBox(height: 40),
                    
                    // Animated title
                    Transform.translate(
                      offset: Offset(0, _titleBounce.value),
                      child: Column(
                        children: [
                          // Ball icon
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: GameConstants.goldColor.withOpacity(0.2),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/ball.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Title
                          const Text(
                            'PIVOT BALL',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: GameConstants.goldColor,
                              letterSpacing: 6,
                              shadows: [
                                Shadow(
                                  color: GameConstants.goldColor,
                                  blurRadius: 8,
                                ),
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 10,
                                  offset: Offset(2, 2),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 6),
                          
                          Text(
                            'RETRO PHYSICS CHALLENGE',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                              letterSpacing: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Menu buttons
                    FadeTransition(
                      opacity: _fadeIn,
                      child: Column(
                        children: [
                          // Play button (large)
                          _buildMenuButton(
                            'PLAY',
                            GameConstants.goldColor,
                            Colors.black,
                            onTap: () {
                              final unlockedLevel = StorageManager.instance.getUnlockedLevel();
                              _navigateTo(GameplayScreen(startLevel: unlockedLevel));
                            },
                            isLarge: true,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Continue button
                          _buildMenuButton(
                            'CONTINUE',
                            GameConstants.neonGreen,
                            Colors.black,
                            onTap: () {
                              final unlockedLevel = StorageManager.instance.getUnlockedLevel();
                              _navigateTo(GameplayScreen(startLevel: unlockedLevel));
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Level Select
                          _buildMenuButton(
                            'LEVEL SELECT',
                            GameConstants.neonBlue,
                            Colors.black,
                            onTap: () {
                              _showLevelSelect();
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Remove Ads CTA — only shown to non-premium users
                          ValueListenableBuilder<bool>(
                            valueListenable: PurchaseManager.instance.adsRemovedNotifier,
                            builder: (context, adsRemoved, child) {
                              if (adsRemoved) return const SizedBox.shrink();
                              return GestureDetector(
                                onTap: () {
                                  AudioManager.instance.playClick();
                                  _navigateTo(const StoreScreen());
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: GameConstants.goldColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: GameConstants.goldColor.withOpacity(0.5)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.block, color: GameConstants.goldColor, size: 16),
                                      SizedBox(width: 8),
                                      Text('REMOVE ADS — \$2.99',
                                        style: TextStyle(
                                          color: GameConstants.goldColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        )),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildSmallButton(
                                Icons.emoji_events,
                                'LEADERBOARD',
                                () => _navigateTo(const LeaderboardScreen()),
                              ),
                              const SizedBox(width: 12),
                              _buildSmallButton(
                                Icons.settings,
                                'SETTINGS',
                                () => _navigateTo(const SettingsScreen()),
                              ),
                              const SizedBox(width: 12),
                              _buildSmallButton(
                                Icons.shopping_bag_outlined,
                                'STORE',
                                () => _navigateTo(const StoreScreen()),
                              ),
                              const SizedBox(width: 12),
                              _buildSmallButton(
                                Icons.help_outline,
                                'HOW TO PLAY',
                                () => _navigateTo(const HowToPlayScreen()),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 80), // space for fixed banner
                          
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Version text
                    Text(
                      'v1.0.0  |  by ${GameConstants.companyName}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(
    String text,
    Color color,
    Color textColor, {
    required VoidCallback onTap,
    bool isLarge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isLarge ? 220 : 200,
        height: isLarge ? 60 : 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color,
              color.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 6,
              spreadRadius: 0,
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: isLarge ? 22 : 16,
              fontWeight: FontWeight.bold,
              color: textColor,
              letterSpacing: 3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.8), size: 24),
          ],
        ),
      ),
    );
  }

  void _showLevelSelect() {
    AudioManager.instance.playClick();
    final unlockedLevel = StorageManager.instance.getUnlockedLevel();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: GameConstants.goldColor.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'SELECT LEVEL',
                style: TextStyle(
                  fontSize: 20,
                  color: GameConstants.goldColor,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: min(unlockedLevel, GameConstants.maxLevels),
                  itemBuilder: (context, index) {
                    final level = index + 1;
                    final isUnlocked = level <= unlockedLevel;
                    
                    return GestureDetector(
                      onTap: isUnlocked
                          ? () {
                              Navigator.pop(context);
                              _navigateTo(GameplayScreen(startLevel: level));
                            }
                          : null,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: isUnlocked
                              ? LinearGradient(
                                  colors: [
                                    GameConstants.goldColor.withOpacity(0.8),
                                    GameConstants.darkGold,
                                  ],
                                )
                              : null,
                          color: isUnlocked ? null : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isUnlocked
                                ? GameConstants.goldColor
                                : Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Center(
                          child: isUnlocked
                              ? Text(
                                  '$level',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                )
                              : Icon(
                                  Icons.lock,
                                  color: Colors.white.withOpacity(0.2),
                                  size: 20,
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
