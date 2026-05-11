import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/purchase_manager.dart';
import '../utils/audio_manager.dart';
import '../utils/ad_manager.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final pm = PurchaseManager.instance;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background
          Container(decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3), radius: 1.2,
              colors: [Color(0xFF1A0800), Colors.black],
            ),
          )),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () { AudioManager.instance.playClick(); Navigator.pop(context); },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                            color: Colors.black45,
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text('STORE', style: TextStyle(
                        fontSize: 20, color: GameConstants.goldColor, letterSpacing: 4)),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      const SizedBox(height: 16),

                      // ── 30-DAY AD-FREE PASS (\$8.99) — BEST VALUE ─────────
                      ValueListenableBuilder<bool>(
                        valueListenable: pm.monthlySkipNotifier,
                        builder: (context, active, child) {
                          final rem  = pm.monthlySkipRemaining;
                          final days = rem.inDays;
                          final hrs  = rem.inHours % 24;
                          return _StoreCard(
                            icon: active ? Icons.workspace_premium : Icons.star_rounded,
                            iconColor: Colors.amber,
                            title: active ? '30-DAY PASS ACTIVE' : '30-DAY AD-FREE PASS',
                            subtitle: active
                                ? 'Expires in \${days}d \${hrs}h'
                                : 'Best value! No ads for a full 30 days.',
                            price: active ? 'ACTIVE' : r'\$8.99',
                            buttonLabel: active ? 'ACTIVE' : 'BUY',
                            buttonColor: Colors.amber,
                            loading: _loading,
                            onTap: active ? null : () async {
                              AudioManager.instance.playClick();
                              setState(() => _loading = true);
                              try { await pm.buyMonthlySkip(); } catch (_) {}
                              if (mounted) setState(() => _loading = false);
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // ── WEEKLY AD SKIP ($2.99 / 7 days) ──────────────────
                      ValueListenableBuilder<bool>(
                        valueListenable: pm.weeklySkipNotifier,
                        builder: (context, active, child) {
                          final rem = pm.weeklySkipRemaining;
                          final days = rem.inDays;
                          final hrs  = rem.inHours % 24;
                          return _StoreCard(
                            icon: active ? Icons.event_available : Icons.calendar_today,
                            iconColor: GameConstants.neonGreen,
                            title: active ? '7-DAY PASS ACTIVE ✓' : '7-DAY AD-FREE PASS',
                            subtitle: active
                                ? 'Expires in $days d $hrs h'
                                : 'No ads for a full week. Renew whenever it expires.',
                            price: active ? 'ACTIVE' : _price(pm, 'pivot_ball_weekly_skip', r'$2.99'),
                            buttonLabel: active ? 'ACTIVE' : 'BUY',
                            buttonColor: GameConstants.neonGreen,
                            loading: _loading,
                            onTap: active ? null : () async {
                              AudioManager.instance.playClick();
                              setState(() => _loading = true);
                              try { await pm.buyWeeklySkip(); } catch (_) {}
                              if (mounted) setState(() => _loading = false);
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // ── DAILY AD SKIP ─────────────────────────────────────
                      ValueListenableBuilder<bool>(
                        valueListenable: pm.dailySkipNotifier,
                        builder: (context, skipActive, child) {
                          final remaining = pm.dailySkipRemaining;
                          final hh = remaining.inHours.toString().padLeft(2,'0');
                          final mm = (remaining.inMinutes % 60).toString().padLeft(2,'0');
                          return _StoreCard(
                            icon: skipActive ? Icons.timer : Icons.skip_next_rounded,
                            iconColor: GameConstants.neonBlue,
                            title: skipActive ? 'AD-FREE TODAY ✓' : 'DAILY AD-FREE PASS',
                            subtitle: skipActive
                                ? 'Expires in $hh h $mm min'
                                : 'Skip ALL ads for 24 hours. Renew any day you play.',
                            price: skipActive ? 'ACTIVE' : _price(pm, 'pivot_ball_daily_skip', r'$0.99'),
                            buttonLabel: skipActive ? 'ACTIVE' : 'BUY',
                            buttonColor: GameConstants.neonBlue,
                            loading: _loading,
                            onTap: skipActive ? null : () async {
                              AudioManager.instance.playClick();
                              setState(() => _loading = true);
                              try { await pm.buyDailySkip(); } catch (_) {}
                              if (mounted) setState(() => _loading = false);
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // ── RESTORE ───────────────────────────────────────────
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            AudioManager.instance.playClick();
                            final messenger = ScaffoldMessenger.of(context);
                            await pm.restorePurchases();
                            if (mounted) {
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Purchases restored')),
                              );
                            }
                          },
                          child: Text('Restore Purchases',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 11,
                              decoration: TextDecoration.underline,
                            )),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── REWARDED ADS (free) ───────────────────────────────
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text('FREE BOOSTS (Watch Ad)',
                          style: TextStyle(
                            color: GameConstants.goldColor,
                            fontSize: 11, letterSpacing: 3)),
                      ),

                      _FreeBoostCard(
                        icon: Icons.timer_outlined,
                        title: '+30 SECONDS',
                        subtitle: 'Watch a short ad to add 30s\nto your current level timer',
                        available: AdManager.instance.rewardedAdReady,
                        note: 'Available in-game when time is low',
                      ),

                      const SizedBox(height: 12),

                      _FreeBoostCard(
                        icon: Icons.skip_next_rounded,
                        title: 'SKIP LEVEL',
                        subtitle: 'Watch a short ad to skip\nany level that feels too hard',
                        available: AdManager.instance.rewardedAdReady,
                        note: 'Available via Pause menu in-game',
                      ),

                      const SizedBox(height: 40),
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

  String _price(PurchaseManager pm, String id, String fallback) {
    try {
      final p = pm.products.cast<dynamic>().firstWhere(
        (p) => p.id == id, orElse: () => null);
      return p?.price ?? fallback;
    } catch (_) { return fallback; }
  }
}

class _StoreCard extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   title;
  final String   subtitle;
  final String   price;
  final String   buttonLabel;
  final Color    buttonColor;
  final bool     loading;
  final VoidCallback? onTap;

  const _StoreCard({
    required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    required this.price, required this.buttonLabel,
    required this.buttonColor, required this.loading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withOpacity(0.1),
              border: Border.all(color: iconColor.withOpacity(0.3)),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(
                  color: iconColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(
                  color: Colors.white.withOpacity(0.5), fontSize: 9, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              Text(price, style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: onTap == null ? Colors.grey.withOpacity(0.2) : buttonColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: onTap == null ? Colors.grey : buttonColor),
                  ),
                  child: loading
                    ? SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(buttonColor)))
                    : Text(buttonLabel, style: TextStyle(
                        color: onTap == null ? Colors.grey : buttonColor,
                        fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FreeBoostCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle, note;
  final bool available;

  const _FreeBoostCard({
    required this.icon, required this.title,
    required this.subtitle, required this.note,
    required this.available,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GameConstants.goldColor.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: GameConstants.goldColor.withOpacity(0.7), size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                  color: GameConstants.goldColor, fontSize: 10,
                  fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 9, height: 1.5)),
                const SizedBox(height: 4),
                Text(note, style: TextStyle(
                  color: GameConstants.goldColor.withOpacity(0.4), fontSize: 8)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
