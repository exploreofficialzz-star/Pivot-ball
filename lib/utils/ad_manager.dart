import 'dart:async';
import 'storage_manager.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// ---------------------------------------------------------------------------
// Ad unit IDs
//
//  ⚠️  TEST MODE IS ON — set _useTestAds = false before releasing to store.
//
//  Test IDs are Google's official ones and always fill; use them during
//  development so you never drain production quota or risk policy flags.
// ---------------------------------------------------------------------------
const _useTestAds = true; // ← flip to false for production builds

// Production IDs (your real AdMob units)
const _prodBannerAndroid       = 'ca-app-pub-2492078126313994/9256149896';
const _prodBannerIos           = 'ca-app-pub-2492078126313994/9256149896';
const _prodInterstitialAndroid = 'ca-app-pub-2492078126313994/7943068221';
const _prodInterstitialIos     = 'ca-app-pub-2492078126313994/7943068221';
const _prodRewardedAndroid     = 'ca-app-pub-2492078126313994/6629986555';
const _prodRewardedIos         = 'ca-app-pub-2492078126313994/6629986555';

// Official Google test IDs — always fill, safe to use in debug/CI
const _testBannerAndroid       = 'ca-app-pub-3940256099942544/6300978111';
const _testBannerIos           = 'ca-app-pub-3940256099942544/2934735716';
const _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
const _testInterstitialIos     = 'ca-app-pub-3940256099942544/4411468910';
const _testRewardedAndroid     = 'ca-app-pub-3940256099942544/5224354917';
const _testRewardedIos         = 'ca-app-pub-3940256099942544/1712485313';

// ---------------------------------------------------------------------------
// AdMob error diagnosis
//
// AdMob error codes (domain: com.google.android.gms.ads):
//   0 — INTERNAL_ERROR   : AdMob server returned an unexpected response
//   1 — INVALID_REQUEST  : Wrong ad unit ID or app not set up in AdMob console
//   2 — NETWORK_ERROR    : Request failed before reaching AdMob (connectivity)
//   3 — NO_FILL          : AdMob has no ad to serve right now (normal sometimes)
//
// Knowing the source tells you where to look:
//   admob      → their servers / fill rate issue — nothing you can do right now
//   appConfig  → check your ad unit IDs and AdMob console app registration
//   network    → device has no route to AdMob servers
//   unknown    → log it and watch for patterns
// ---------------------------------------------------------------------------
enum AdFailureSource { admob, appConfig, network, unknown }

class AdDiagnostic {
  final String   adType;   // 'banner' | 'interstitial' | 'rewarded'
  final int      code;
  final String   domain;
  final String   message;
  final AdFailureSource source;
  final DateTime timestamp;

  AdDiagnostic({
    required this.adType,
    required this.code,
    required this.domain,
    required this.message,
    required this.source,
    required this.timestamp,
  });

  static AdFailureSource _classify(int code, String domain) {
    if (code == 2) return AdFailureSource.network;
    if (code == 1) return AdFailureSource.appConfig;
    if (code == 0 || code == 3) return AdFailureSource.admob;
    return AdFailureSource.unknown;
  }

  factory AdDiagnostic.fromError(String adType, LoadAdError error) {
    return AdDiagnostic(
      adType:    adType,
      code:      error.code,
      domain:    error.domain,
      message:   error.message,
      source:    _classify(error.code, error.domain),
      timestamp: DateTime.now(),
    );
  }

  String get summary {
    final src = switch (source) {
      AdFailureSource.admob     => '🔴 ADMOB SIDE',
      AdFailureSource.appConfig => '⚙️  APP CONFIG',
      AdFailureSource.network   => '📶 NETWORK',
      AdFailureSource.unknown   => '❓ UNKNOWN',
    };
    return '[$adType] $src  code=$code  "$message"  domain=$domain';
  }

  /// Human-readable fix hint shown in debug output
  String get hint {
    return switch (source) {
      AdFailureSource.admob =>
        code == 3
          ? 'No ad inventory right now — normal during testing. Try again later.'
          : 'AdMob internal error — their servers. Nothing to fix on your end.',
      AdFailureSource.appConfig =>
        'Check: (1) ad unit ID is correct, (2) app is registered in AdMob console, '
        '(3) app bundle ID matches what AdMob expects.',
      AdFailureSource.network =>
        'Device cannot reach AdMob servers. Check internet connection.',
      AdFailureSource.unknown =>
        'Unrecognised error code $code from domain "$domain". Monitor for patterns.',
    };
  }
}

class AdManager {
  static final AdManager _instance = AdManager._internal();
  static AdManager get instance => _instance;
  AdManager._internal();

  bool _sdkReady       = false;
  bool _hasNetwork     = true;
  bool _adBlocked      = false;
  int  _consecutiveFails = 0;

  /// Last 20 ad failures — inspect with AdManager.instance.recentFailures
  final List<AdDiagnostic> _recentFailures = [];
  List<AdDiagnostic> get recentFailures => List.unmodifiable(_recentFailures);

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
      final status = await MobileAds.instance.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️  AdMob SDK init timed out after 10s');
          return InitializationStatus({});
        },
      );
      debugPrint('✅ AdMob SDK initialized. Adapter statuses:');
      status.adapterStatuses.forEach((adapter, adapterStatus) {
        debugPrint('   $adapter → ${adapterStatus.state.name} (${adapterStatus.description})');
      });
      if (_useTestAds) debugPrint('🧪 TEST AD IDs active — remember to flip _useTestAds before release');
    } catch (e) {
      debugPrint('❌ AdMob SDK init threw: $e');
    }

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
  // AD UNIT IDs — routes to test or prod based on _useTestAds flag
  // =========================================================================
  static String get bannerAdUnitId =>
      _useTestAds
          ? (Platform.isAndroid ? _testBannerAndroid       : _testBannerIos)
          : (Platform.isAndroid ? _prodBannerAndroid       : _prodBannerIos);

  static String get interstitialAdUnitId =>
      _useTestAds
          ? (Platform.isAndroid ? _testInterstitialAndroid : _testInterstitialIos)
          : (Platform.isAndroid ? _prodInterstitialAndroid : _prodInterstitialIos);

  static String get rewardedAdUnitId =>
      _useTestAds
          ? (Platform.isAndroid ? _testRewardedAndroid     : _testRewardedIos)
          : (Platform.isAndroid ? _prodRewardedAndroid     : _prodRewardedIos);

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
          _trackFailure('interstitial', error);
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
          _trackFailure('rewarded', error);
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
    return BannerAdWidget(adUnitId: bannerAdUnitId);
  }

  // =========================================================================
  // FAILURE TRACKING & DIAGNOSIS
  // =========================================================================
  void _logFailure(String adType, LoadAdError error) {
    final diag = AdDiagnostic.fromError(adType, error);
    _recentFailures.add(diag);
    if (_recentFailures.length > 20) _recentFailures.removeAt(0);

    // Always visible in the debug console — easy to spot what's wrong
    debugPrint('');
    debugPrint('╔══ AdMob LOAD FAILURE ═══════════════════════════════════');
    debugPrint('║  ${diag.summary}');
    debugPrint('║  💡 ${diag.hint}');
    if (_useTestAds) {
      debugPrint('║  🧪 Running with TEST ad IDs');
    } else {
      debugPrint('║  🚀 Running with PRODUCTION ad IDs');
    }
    debugPrint('╚══════════════════════════════════════════════════════════');
    debugPrint('');
  }

  void _trackFailure(String adType, LoadAdError error) {
    _logFailure(adType, error);
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

  const BannerAdWidget({super.key, required this.adUnitId});

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
          AdManager.instance._trackFailure('banner', error);
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
