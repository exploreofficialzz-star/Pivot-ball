import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ---------------------------------------------------------------------------
// Ad unit IDs are injected at build time via --dart-define flags.
// In CI/CD these come from GitHub Secrets.  Locally, either pass them with
// --dart-define or the test IDs below are used as safe defaults.
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

  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    _loadInterstitialAd();
    _loadRewardedAd();
  }

  static String get bannerAdUnitId =>
      Platform.isAndroid ? _bannerAndroid : _bannerIos;

  static String get interstitialAdUnitId =>
      Platform.isAndroid ? _interstitialAndroid : _interstitialIos;

  static String get rewardedAdUnitId =>
      Platform.isAndroid ? _rewardedAndroid : _rewardedIos;

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
        },
      ),
    );
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
        },
      ),
    );
  }

  void showInterstitialAd() {
    if (_premiumUser) return;
    _gameCount++;
    if (_gameCount % 3 != 0) return;

    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
      _loadInterstitialAd();
    }
  }

  Future<bool> showRewardedAd() async {
    if (_rewardedAd != null) {
      final completer = Completer<bool>();
      _rewardedAd!.show(
        onUserEarnedReward: (_, reward) {
          completer.complete(true);
        },
      );
      _rewardedAd = null;
      _loadRewardedAd();
      return completer.future;
    }
    return false;
  }

  Widget buildBannerAd() {
    if (_premiumUser) return const SizedBox.shrink();
    return BannerAdWidget(adUnitId: bannerAdUnitId);
  }

  void setPremiumUser(bool value) {
    _premiumUser = value;
  }

  bool get isPremiumUser => _premiumUser;
}

class BannerAdWidget extends StatefulWidget {
  final String adUnitId;

  const BannerAdWidget({super.key, required this.adUnitId});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() {
              _loaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    _bannerAd!.load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _bannerAd == null) {
      return const SizedBox(height: 50);
    }
    return Container(
      alignment: Alignment.center,
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
