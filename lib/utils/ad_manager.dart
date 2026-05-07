import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ---------------------------------------------------------------------------
// Ad unit IDs injected at build time via --dart-define.
// Falls back to Google's official test IDs so ads always work during dev/QA.
// ---------------------------------------------------------------------------
const String _kTestBannerAndroid       = 'ca-app-pub-3940256099942544/6300978111';
const String _kTestBannerIos           = 'ca-app-pub-3940256099942544/2934735716';
const String _kTestInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
const String _kTestInterstitialIos     = 'ca-app-pub-3940256099942544/4411468910';
const String _kTestRewardedAndroid     = 'ca-app-pub-3940256099942544/5224354917';
const String _kTestRewardedIos         = 'ca-app-pub-3940256099942544/1712485313';

const String _bannerAndroid =
    String.fromEnvironment('ADMOB_BANNER_ANDROID',       defaultValue: _kTestBannerAndroid);
const String _bannerIos =
    String.fromEnvironment('ADMOB_BANNER_IOS',           defaultValue: _kTestBannerIos);
const String _interstitialAndroid =
    String.fromEnvironment('ADMOB_INTERSTITIAL_ANDROID', defaultValue: _kTestInterstitialAndroid);
const String _interstitialIos =
    String.fromEnvironment('ADMOB_INTERSTITIAL_IOS',     defaultValue: _kTestInterstitialIos);
const String _rewardedAndroid =
    String.fromEnvironment('ADMOB_REWARDED_ANDROID',     defaultValue: _kTestRewardedAndroid);
const String _rewardedIos =
    String.fromEnvironment('ADMOB_REWARDED_IOS',         defaultValue: _kTestRewardedIos);

class AdManager {
  static final AdManager _instance = AdManager._internal();
  static AdManager get instance => _instance;
  AdManager._internal();

  bool _initialized = false;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  int _gameCount = 0;
  bool _premiumUser = false;

  // -------------------------------------------------------------------------
  // Initialize — never blocks the app; 8-second safety timeout
  // -------------------------------------------------------------------------
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize().timeout(
        const Duration(seconds: 8),
        onTimeout: () => InitializationStatus({}),
      );
    } catch (_) {}
    _initialized = true;
    _loadInterstitialAd();
    _loadRewardedAd();
  }

  // -------------------------------------------------------------------------
  // Ad unit IDs
  // -------------------------------------------------------------------------
  static String get bannerAdUnitId =>
      Platform.isAndroid ? _bannerAndroid : _bannerIos;

  static String get interstitialAdUnitId =>
      Platform.isAndroid ? _interstitialAndroid : _interstitialIos;

  static String get rewardedAdUnitId =>
      Platform.isAndroid ? _rewardedAndroid : _rewardedIos;

  // -------------------------------------------------------------------------
  // Interstitial
  // -------------------------------------------------------------------------
  void _loadInterstitialAd() {
    if (!_initialized) return;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAd!.setImmersiveMode(true);
        },
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  void showInterstitialAd() {
    if (_premiumUser || !_initialized) return;
    _gameCount++;
    if (_gameCount % 3 != 0) return;
    if (_interstitialAd == null) {
      _loadInterstitialAd(); // preload for next time
      return;
    }
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd();
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

  // -------------------------------------------------------------------------
  // Rewarded
  // -------------------------------------------------------------------------
  void _loadRewardedAd() {
    if (!_initialized) return;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (_) => _rewardedAd = null,
      ),
    );
  }

  Future<bool> showRewardedAd() async {
    if (!_initialized || _rewardedAd == null) return false;
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

  // -------------------------------------------------------------------------
  // Banner
  // -------------------------------------------------------------------------
  Widget buildBannerAd() {
    if (_premiumUser || !_initialized) return const SizedBox.shrink();
    return BannerAdWidget(adUnitId: bannerAdUnitId);
  }

  void setPremiumUser(bool value) => _premiumUser = value;
  bool get isPremiumUser => _premiumUser;
}

// ---------------------------------------------------------------------------
// Banner widget — auto-retries once on failure
// ---------------------------------------------------------------------------
class BannerAdWidget extends StatefulWidget {
  final String adUnitId;
  const BannerAdWidget({super.key, required this.adUnitId});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _loaded = false;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _bannerAd = null;
          // Retry once after 3 seconds
          if (_retryCount < 1 && mounted) {
            _retryCount++;
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) _loadBannerAd();
            });
          }
        },
      ),
    );
    _bannerAd!.load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _bannerAd == null) return const SizedBox(height: 50);
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}
