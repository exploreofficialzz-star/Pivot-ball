import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// ---------------------------------------------------------------------------
// Ad unit IDs — injected at build time via --dart-define.
// Google official test IDs are the fallback (work on any device).
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
  final ValueNotifier<bool> sdkReadyNotifier = ValueNotifier(false);

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

  /// Show interstitial ad. Call on every game-over.
  /// If not loaded yet, queues load for next game-over automatically.
  void showInterstitialAd() {
    if (!_sdkReady) return;

    if (_interstitialAd == null) {
      // Not ready — reload so next game-over will have one
      _loadInterstitialAd();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd(); // immediately queue next
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
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
    if (_consecutiveFails >= 5) _adBlocked = true;
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
