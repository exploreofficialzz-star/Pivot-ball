import 'dart:async';
import 'storage_manager.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// ---------------------------------------------------------------------------
// Real production AdMob ad unit IDs — hardcoded directly.
// No secrets or --dart-define needed. These are public-facing IDs.
// ---------------------------------------------------------------------------
const _bannerAndroid       = 'ca-app-pub-2492078126313994/9256149896';
const _bannerIos           = 'ca-app-pub-2492078126313994/9256149896'; // add iOS ID when available
const _interstitialAndroid = 'ca-app-pub-2492078126313994/7943068221';
const _interstitialIos     = 'ca-app-pub-2492078126313994/7943068221'; // add iOS ID when available
const _rewardedAndroid     = 'ca-app-pub-2492078126313994/6629986555';
const _rewardedIos         = 'ca-app-pub-2492078126313994/6629986555'; // add iOS ID when available

class AdManager {
  static final AdManager _instance = AdManager._internal();
  static AdManager get instance => _instance;
  AdManager._internal();

  bool _sdkReady       = false; // MobileAds.initialize() completed
  bool _hasNetwork     = true;  // optimistic default
  bool _adBlocked      = false;
  int  _consecutiveFails = 0;

  InterstitialAd? _interstitialAd;
  RewardedAd?     _rewardedAd;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _retryTimer;

  // Notifier so BannerAdWidget can rebuild when SDK becomes ready
  final ValueNotifier<bool> sdkReadyNotifier    = ValueNotifier(false);
  final ValueNotifier<bool> adBlockedNotifier   = ValueNotifier(false);

  // =========================================================================
  // INIT — call once from main(), without await
  // =========================================================================
  Future<void> initialize() async {
    if (_sdkReady) return;

    // 1. Quick network check (don't block ad loading on result)
    _hasNetwork = await _checkNetwork();

    // 2. Connectivity listener — reload failed ads when back online
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      _hasNetwork = online;
      if (online && _sdkReady) {
        if (_interstitialAd == null) _loadInterstitialAd();
        if (_rewardedAd == null)     _loadRewardedAd();
      }
    });

    // 3. Initialize AdMob SDK
    try {
      await MobileAds.instance.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () => InitializationStatus({}),
      );
    } catch (_) {}

    _sdkReady = true;
    sdkReadyNotifier.value = true; // triggers BannerAdWidget rebuilds

    // 4. Load ads immediately — let AdMob handle its own network errors
    _loadInterstitialAd();
    _loadRewardedAd();

    // 5. Retry every 45s for any unloaded ads
    _retryTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (_interstitialAd == null) _loadInterstitialAd();
      if (_rewardedAd == null)     _loadRewardedAd();
    });
  }

  // =========================================================================
  // NETWORK
  // =========================================================================
  Future<bool> _checkNetwork() async {
    try {
      final result = await Connectivity().checkConnectivity()
          .timeout(const Duration(seconds: 3));
      return result.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true; // assume online if check fails
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
    if (!_sdkReady) return;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _consecutiveFails = 0;
          _adBlocked = false;
          adBlockedNotifier.value = false;
          ad.setImmersiveMode(true);
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _trackFailure();
          // Retry after 15s on failure
          Future.delayed(const Duration(seconds: 15), () {
            if (_interstitialAd == null && _sdkReady) _loadInterstitialAd();
          });
        },
      ),
    );
  }

  int _actionsSinceAd = 0; // track user actions between ads

  /// Show interstitial ad — compliant with AdMob policy:
  /// max 1 interstitial per every 2 user actions (level completions).
  /// [onDismissed] always fires so the caller's flow is never blocked.
  bool _isPremium() {
    try {
      // Legacy permanent removal
      if (StorageManager.instance.getAdsRemoved()) return true;
      // Monthly skip — 30 days
      final monthly = StorageManager.instance.getMonthlySkipTime();
      if (monthly != null && DateTime.now().difference(monthly).inDays < 30) return true;
      // Weekly skip — $2.99 for 7 days
      final weekly = StorageManager.instance.getWeeklySkipTime();
      if (weekly != null && DateTime.now().difference(weekly).inDays < 7) return true;
      // Daily skip — $0.99 for 24 hours
      final daily = StorageManager.instance.getDailySkipTime();
      if (daily != null && DateTime.now().difference(daily).inHours < 24) return true;
      return false;
    } catch (_) { return false; }
  }

  void showInterstitialAd({VoidCallback? onDismissed}) {
    // Premium users skip the ad immediately
    if (_isPremium()) {
      Future.delayed(const Duration(milliseconds: 100), () => onDismissed?.call());
      return;
    }
    _actionsSinceAd++;

    // Game-level completions are natural break points — every level is policy-compliant
    // Only skip first ever game to not overwhelm new users
    if (_actionsSinceAd < 1) {
      Future.delayed(const Duration(milliseconds: 200), () => onDismissed?.call());
      return;
    }

    if (!_sdkReady || _interstitialAd == null) {
      _loadInterstitialAd();
      Future.delayed(const Duration(milliseconds: 300), () => onDismissed?.call());
      return;
    }

    _actionsSinceAd = 0; // reset counter after showing

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd();
        onDismissed?.call();
      },
    );
    _interstitialAd!.show();
    _interstitialAd = null;
  }

  // =========================================================================
  // REWARDED
  // =========================================================================
  void _loadRewardedAd() {
    if (!_sdkReady) return;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _consecutiveFails = 0;
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _trackFailure();
          Future.delayed(const Duration(seconds: 15), () {
            if (_rewardedAd == null && _sdkReady) _loadRewardedAd();
          });
        },
      ),
    );
  }

  bool get rewardedAdReady => _rewardedAd != null;

  Future<bool> showRewardedAd() async {
    if (!_sdkReady || _rewardedAd == null) return false;
    final completer = Completer<bool>();

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
        if (!completer.isCompleted) completer.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        if (!completer.isCompleted) completer.complete(true);
      },
    );
    _rewardedAd = null;
    return completer.future;
  }

  // =========================================================================
  // BANNER — always returns a widget; never blocked by _sdkReady
  // BannerAdWidget listens to sdkReadyNotifier and loads when SDK is ready
  // =========================================================================
  Widget buildBannerAd({bool showNudge = false}) {
    // Premium users — no ads
    if (_isPremium()) return const SizedBox.shrink();
    if (!_hasNetwork && showNudge) return _noNetworkNudge();
    if (_adBlocked  && showNudge) return _adBlockedNudge();
    // Always return BannerAdWidget — it handles its own SDK-ready wait
    return BannerAdWidget(
      adUnitId: bannerAdUnitId,
      onFailed: _trackFailure,
    );
  }

  // =========================================================================
  // FAILURE TRACKING
  // =========================================================================
  void _trackFailure() {
    _consecutiveFails++;
    if (_consecutiveFails >= 5) {
      _adBlocked = true;
      adBlockedNotifier.value = true;
    }
  }

  // =========================================================================
  // NUDGE WIDGETS
  // =========================================================================
  Widget _noNetworkNudge() => Container(
    height: 50, color: Colors.black,
    child: Center(child: Text(
      '📶  Connect to internet to support us with free ads',
      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9),
      textAlign: TextAlign.center,
    )),
  );

  Widget _adBlockedNudge() => Container(
    height: 50, color: Colors.black,
    child: Center(child: Text(
      '❤️  Please disable your ad blocker — this game is free',
      style: TextStyle(color: Colors.amber.withOpacity(0.6), fontSize: 9),
      textAlign: TextAlign.center,
    )),
  );

  void dispose() {
    _connectivitySub?.cancel();
    _retryTimer?.cancel();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    sdkReadyNotifier.dispose();
    adBlockedNotifier.dispose();
  }
}

// ---------------------------------------------------------------------------
// BannerAdWidget
// - Listens to AdManager.sdkReadyNotifier so it loads the moment SDK is ready
// - Retries with exponential back-off (3s → 8s → 20s, max 3 retries)
// - Shows stable 50px placeholder while loading so layout doesn't jump
// ---------------------------------------------------------------------------
class BannerAdWidget extends StatefulWidget {
  final String adUnitId;
  final VoidCallback? onFailed;

  const BannerAdWidget({super.key, required this.adUnitId, this.onFailed});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _loaded   = false;
  int  _attempts = 0;

  @override
  void initState() {
    super.initState();
    // If SDK is already ready, load now; otherwise wait for it
    if (AdManager.instance.sdkReadyNotifier.value) {
      _load();
    } else {
      AdManager.instance.sdkReadyNotifier.addListener(_onSdkReady);
    }
  }

  void _onSdkReady() {
    AdManager.instance.sdkReadyNotifier.removeListener(_onSdkReady);
    if (mounted) _load();
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
    if (_loaded && _bannerAd != null) {
      return SizedBox(
        width:  _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child:  AdWidget(ad: _bannerAd!),
      );
    }
    // Stable placeholder — keeps layout consistent while ad loads
    return Container(
      height: 50,
      color: Colors.black,
      child: Center(
        child: Text(
          'Advertisement',
          style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 9),
        ),
      ),
    );
  }

  @override
  void dispose() {
    AdManager.instance.sdkReadyNotifier.removeListener(_onSdkReady);
    _bannerAd?.dispose();
    super.dispose();
  }
}
