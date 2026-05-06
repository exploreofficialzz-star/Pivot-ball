import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/audio_manager.dart';
import '../utils/storage_manager.dart';
// import '../utils/ad_manager.dart'; // Uncomment when using ads in settings

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _soundEnabled = StorageManager.instance.getSoundEnabled();
      _musicEnabled = StorageManager.instance.getMusicEnabled();
    });
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
                        'SETTINGS',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: GameConstants.goldColor,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Settings list
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      // Audio section
                      _buildSectionHeader('AUDIO'),
                      const SizedBox(height: 12),
                      
                      _buildToggleSetting(
                        'Sound Effects',
                        Icons.volume_up,
                        _soundEnabled,
                        (value) {
                          setState(() {
                            _soundEnabled = value;
                          });
                          AudioManager.instance.setSoundEnabled(value);
                          StorageManager.instance.saveSoundEnabled(value);
                          if (value) AudioManager.instance.playClick();
                        },
                      ),
                      
                      const SizedBox(height: 12),
                      
                      _buildToggleSetting(
                        'Music',
                        Icons.music_note,
                        _musicEnabled,
                        (value) {
                          setState(() {
                            _musicEnabled = value;
                          });
                          AudioManager.instance.setMusicEnabled(value);
                          StorageManager.instance.saveMusicEnabled(value);
                        },
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Game section
                      _buildSectionHeader('GAME'),
                      const SizedBox(height: 12),
                      
                      _buildToggleSetting(
                        'Vibration',
                        Icons.vibration,
                        _vibrationEnabled,
                        (value) {
                          setState(() {
                            _vibrationEnabled = value;
                          });
                        },
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Reset progress
                      _buildActionSetting(
                        'Reset Progress',
                        Icons.delete_forever,
                        GameConstants.neonRed,
                        () => _showResetConfirm(),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // About section
                      _buildSectionHeader('ABOUT'),
                      const SizedBox(height: 12),
                      
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/images/app_icon.png',
                              width: 60,
                              height: 60,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              GameConstants.appName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: GameConstants.goldColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              GameConstants.appSubtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Version 1.0.0',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Developed by ${GameConstants.companyFullName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.5),
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
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: GameConstants.goldColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.5),
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleSetting(
    String title,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white.withOpacity(0.6),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: GameConstants.goldColor,
            activeTrackColor: GameConstants.goldColor.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSetting(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        AudioManager.instance.playClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: color,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: color.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: GameConstants.neonRed),
        ),
        title: const Text(
          'Reset Progress?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will delete all your scores and unlocked levels. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              StorageManager.instance.resetProgress();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Progress reset successfully'),
                  backgroundColor: GameConstants.neonGreen,
                ),
              );
            },
            child: const Text(
              'RESET',
              style: TextStyle(color: GameConstants.neonRed),
            ),
          ),
        ],
      ),
    );
  }
}
