import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// ---------------------------------------------------------------------------
// Ad unit IDs — injected at build time via --dart-define.
// Google's official test IDs are the fallback (work on any device, no setup).
// ---------------------------------------------------------------------------
const _kTestBannerAndroid       = 'ca-app-pub-3940256099942544/6300978111';
const _kTestBannerIos           = 'ca-app-pub-3940256099942544/2934735716';
const _kTestInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
const _kTestInterstitialIos     = 'ca-app-pub-3940256099942544/4411468910';
const _kTestRewardedAndroid     = 'ca-app-pub-3940256099942544/5224354917';
const _kTestRewardedIos         = 'ca-app-pub-3940256099942544/1712485313';

const _bannerAndroid =
    String.fromEnvironment('ADMOB_BANNER_ANDROID',       defaultValue: _kTestBannerAndroid);
const _bannerIos =
    String.fromEnvironment('ADMOB_BANNER_IOS',           defaultValue: _kTestBannerIos);
const _interstitialAndroid =
    String.fromEnvironment('ADMOB_INTERSTITIAL_ANDROID', defaultValue: _kTestInterstitialAndroid);
const _interstitialIos =
    String.fromEnvironment('ADMOB_INTERSTITIAL_IOS',     defaultValue: _kTestInterstitialIos);
const _rewardedAndroid =
    String.fromEnvironment('ADMOB_REWARDED_ANDROID',     defaultValue: _kTestRewardedAndroid);
const _rewardedIos =
    String.fromEnvironment('ADMOB_REWARDED_IOS',         defaultValue: _kTestRewardedIos);

// ---------------------------------------------------------------------------
// AdManager — network-aware, aggressive but respectful ad loading
// ---------------------------------------------------------------------------
class AdManager {
  static final AdManager _instance = AdManager._internal();
  static AdManager get instance => _instance;
  AdManager._internal();

  // State
  bool _initialized       = false;
  bool _hasNetwork        = false;
  bool _adBlocked         = false; // suspected ad-blocker / no fill
  int  _consecutiveFails  = 0;
  int  _gamesSinceAd      = 0;     // show interstitial every 2 games

  InterstitialAd? _interstitialAd;
  RewardedAd?     _rewardedAd;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer?          _retryTimer;

  // =========================================================================
  // INIT
  // =========================================================================
  Future<void> initialize() async {
    if (_initialized) return;

    // 1. Check network first
    _hasNetwork = await _checkNetwork();

    // 2. Listen for connectivity changes — reload ads when back online
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online && !_hasNetwork) {
        _hasNetwork = true;
        _adBlocked  = false;
        _consecutiveFails = 0;
        _loadInterstitialAd();
        _loadRewardedAd();
      }
      _hasNetwork = online;
    });

    // 3. Initialize AdMob SDK — timeout safety
    try {
      await MobileAds.instance.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () => InitializationStatus({}),
      );
    } catch (_) {}

    _initialized = true;

    // 4. Pre-load both ad types immediately
    if (_hasNetwork) {
      _loadInterstitialAd();
      _loadRewardedAd();
    }

    // 5. Periodic retry every 45 s if ads haven't loaded
    _retryTimer = Timer.periodic(const Duration(seconds: 45), (_) async {
      _hasNetwork = await _checkNetwork();
      if (_hasNetwork) {
        if (_interstitialAd == null) _loadInterstitialAd();
        if (_rewardedAd == null)     _loadRewardedAd();
      }
    });
  }

  // =========================================================================
  // NETWORK
  // =========================================================================
  Future<bool> _checkNetwork() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  bool get hasNetwork  => _hasNetwork;
  bool get isAdBlocked => _adBlocked;

  // =========================================================================
  // AD UNIT IDs
  // =========================================================================
  static String get bannerAdUnitId =>
      Platform.isAndroid ? _bannerAndroid : _bannerIos;
  static String get interstitialAdUnitId =>
      Platform.isAndroid ? _interstitialAndroid : _interstitialIos;
  static String get rewardedAdUnitId =>
      Platform.isAndroid ? _rewardedAndroid : _rewardedIos;

  // =========================================================================
  // INTERSTITIAL
  // =========================================================================
  void _loadInterstitialAd() {
    if (!_initialized || !_hasNetwork || _adBlocked) return;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _consecutiveFails = 0;
          _adBlocked = false;
          ad.setImmersiveMode(true);
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _handleAdFailure();
        },
      ),
    );
  }

  /// Call after every game-over. Shows every 2nd game-over for better revenue.
  void showInterstitialAd() {
    if (!_initialized || !_hasNetwork) return;
    _gamesSinceAd++;
    if (_gamesSinceAd < 2) return; // show every 2 game-overs

    if (_interstitialAd == null) {
      _loadInterstitialAd(); // reload for next time
      return;
    }

    _gamesSinceAd = 0;
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd(); // preload next immediately
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd();
      },
    );
    _interstitialAd!.show();
    _interstitialAd = null;
  }

  // =========================================================================
  // REWARDED
  // =========================================================================
  void _loadRewardedAd() {
    if (!_initialized || !_hasNetwork || _adBlocked) return;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _consecutiveFails = 0;
        },
        onAdFailedToLoad: (_) {
          _rewardedAd = null;
          _handleAdFailure();
        },
      ),
    );
  }

  bool get rewardedAdReady => _rewardedAd != null;

  Future<bool> showRewardedAd() async {
    if (!_initialized || !_hasNetwork || _rewardedAd == null) return false;
    final completer = Completer<bool>();

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
        if (!completer.isCompleted) completer.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (_, reward) {
        if (!completer.isCompleted) completer.complete(true);
      },
    );
    _rewardedAd = null;
    return completer.future;
  }

  // =========================================================================
  // BANNER
  // =========================================================================
  /// Returns a live banner ad widget, or a "support us" nudge if no network/
  /// ads are blocked, or empty if totally unavailable.
  Widget buildBannerAd({bool showNudge = false}) {
    if (!_initialized) return const SizedBox.shrink();

    if (!_hasNetwork) {
      return showNudge ? _noNetworkNudge() : const SizedBox.shrink();
    }

    if (_adBlocked) {
      return showNudge ? _adBlockedNudge() : const SizedBox.shrink();
    }

    return BannerAdWidget(
      adUnitId:   bannerAdUnitId,
      onFailed:   _handleAdFailure,
    );
  }

  // =========================================================================
  // FAILURE TRACKING & AD-BLOCK DETECTION
  // =========================================================================
  void _handleAdFailure() {
    _consecutiveFails++;
    // After 4 consecutive failures, suspect ad blocker / no fill
    if (_consecutiveFails >= 4) {
      _adBlocked = true;
    }
  }

  // =========================================================================
  // NUDGE WIDGETS — shown when ads can't load
  // =========================================================================
  Widget _noNetworkNudge() {
    return Container(
      height: 50,
      color: Colors.black87,
      child: Center(
        child: Text(
          '📶  Connect to internet to support us with ads',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _adBlockedNudge() {
    return Container(
      height: 50,
      color: Colors.black87,
      child: Center(
        child: Text(
          '❤️  This game is free — please disable your ad blocker to support us',
          style: TextStyle(color: Colors.amber.withOpacity(0.7), fontSize: 9),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // =========================================================================
  // CLEANUP
  // =========================================================================
  void dispose() {
    _connectivitySub?.cancel();
    _retryTimer?.cancel();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}

// ---------------------------------------------------------------------------
// BannerAdWidget — retries up to 3 times with exponential back-off
// ---------------------------------------------------------------------------
class BannerAdWidget extends StatefulWidget {
  final String adUnitId;
  final VoidCallback? onFailed;

  const BannerAdWidget({
    super.key,
    required this.adUnitId,
    this.onFailed,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _loaded    = false;
  int  _attempts  = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      size:     AdSize.banner,
      request:  const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          widget.onFailed?.call();

          // Exponential back-off: 3 s → 8 s → 20 s (max 3 retries)
          if (_attempts < 3 && mounted) {
            final delay = [3, 8, 20][_attempts];
            _attempts++;
            Future.delayed(Duration(seconds: delay), () {
              if (mounted) _load();
            });
          }
        },
      ),
    );
    _bannerAd!.load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _bannerAd == null) {
      // Placeholder keeps layout stable while ad loads
      return Container(
        height: 50,
        color: Colors.black,
        child: Center(
          child: Text(
            'Loading ad...',
            style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10),
          ),
        ),
      );
    }
    return SizedBox(
      width:  _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child:  AdWidget(ad: _bannerAd!),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}
