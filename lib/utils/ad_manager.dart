import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Manages interstitial and app open ads
class AdManager {
  InterstitialAd? _interstitialAd;
  bool _isAdLoading = false;
  bool _isAdReady = false;

  AppOpenAd? _appOpenAd;
  bool _isAppOpenAdLoading = false;
  bool _isAppOpenAdReady = false;

  // 🔧 DEBUG MODE FLAG - Set to false when your AdMob account is approved
  // true  = Use Google test ads (works immediately, no revenue)
  // false = Use your production ads (requires approved AdMob account, real revenue)
  static const bool _useDebugTestAds = true;

  // Test ad unit IDs - Google's official test IDs
  static const String _testAdUnitIdAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testAdUnitIdIOS = 'ca-app-pub-3940256099942544/4411468910';
  static const String _testAppOpenAdUnitIdAndroid = 'ca-app-pub-3940256099942544/9257395921';
  static const String _testAppOpenAdUnitIdIOS = 'ca-app-pub-3940256099942544/5575463023';

  // Production ad unit ID from your AdMob account (Interstitial)
  static const String _productionAdUnitId = 'ca-app-pub-3354986806928390/8062430911';
  
  // Production ad unit ID for App Open ads - Using same as interstitial for now
  // You may want to create a separate App Open ad unit in AdMob console
  static const String _productionAppOpenAdUnitId = 'ca-app-pub-3354986806928390/8062430911';

  /// Get the appropriate ad unit ID based on debug flag
  String get _adUnitId {
    if (_useDebugTestAds) {
      // Use Google's test ads during development
      if (Platform.isAndroid) {
        return _testAdUnitIdAndroid;
      } else if (Platform.isIOS) {
        return _testAdUnitIdIOS;
      }
    }
    // Use production ads when AdMob account is approved
    return _productionAdUnitId;
  }

  /// Get the appropriate app open ad unit ID based on debug flag
  String get _appOpenAdUnitId {
    if (_useDebugTestAds) {
      // Use Google's test ads during development
      if (Platform.isAndroid) {
        return _testAppOpenAdUnitIdAndroid;
      } else if (Platform.isIOS) {
        return _testAppOpenAdUnitIdIOS;
      }
    }
    // Use production ads when AdMob account is approved
    return _productionAppOpenAdUnitId;
  }

  /// Check if ads are supported on current platform
  bool get isAdsSupportedPlatform {
    // Only show ads on mobile platforms (Android phones/tablets, iOS)
    // Skip on Android TV, Linux, macOS, Windows
    if (Platform.isAndroid) {
      // TODO: Add more sophisticated check for Android TV if needed
      // For now, we'll show ads on all Android devices
      return true;
    }
    return Platform.isIOS;
  }

  /// Load an interstitial ad
  Future<void> loadAd() async {
    if (!isAdsSupportedPlatform) {
      print('Ads not supported on this platform');
      return;
    }

    if (_isAdLoading) {
      print('Ad is already loading');
      return;
    }

    if (_isAdReady) {
      print('Ad is already loaded');
      return;
    }

    _isAdLoading = true;
    final adMode = _useDebugTestAds ? 'TEST (Google test ads)' : 'PRODUCTION (Real ads)';
    print('Loading interstitial ad in $adMode mode with unit ID: $_adUnitId');

    await InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          print('Interstitial ad loaded successfully');
          _interstitialAd = ad;
          _isAdReady = true;
          _isAdLoading = false;

          // Set up full screen content callback
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (InterstitialAd ad) {
              print('Interstitial ad showed full screen content');
            },
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              print('Interstitial ad dismissed');
              ad.dispose();
              _interstitialAd = null;
              _isAdReady = false;
              // Preload next ad
              loadAd();
            },
            onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
              print('Interstitial ad failed to show: $error');
              ad.dispose();
              _interstitialAd = null;
              _isAdReady = false;
              // Try to load next ad
              loadAd();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('Failed to load interstitial ad: $error');
          _interstitialAd = null;
          _isAdReady = false;
          _isAdLoading = false;
        },
      ),
    );
  }

  /// Show the interstitial ad if ready
  /// Returns true if ad was shown or attempted, false if not ready
  Future<bool> showAd({
    required VoidCallback onAdClosed,
    required VoidCallback onAdFailedToShow,
  }) async {
    if (!isAdsSupportedPlatform) {
      print('Ads not supported - proceeding without ad');
      onAdClosed();
      return false;
    }

    if (!_isAdReady || _interstitialAd == null) {
      print('Ad not ready - proceeding without ad');
      onAdFailedToShow();
      return false;
    }

    // Set up callbacks before showing
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) {
        print('Interstitial ad showed full screen content');
      },
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        print('Interstitial ad dismissed - proceeding with action');
        ad.dispose();
        _interstitialAd = null;
        _isAdReady = false;
        onAdClosed();
        // Preload next ad
        loadAd();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        print('Interstitial ad failed to show: $error');
        ad.dispose();
        _interstitialAd = null;
        _isAdReady = false;
        onAdFailedToShow();
        // Try to load next ad
        loadAd();
      },
    );

    try {
      await _interstitialAd!.show();
      return true;
    } catch (e) {
      print('Error showing ad: $e');
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _isAdReady = false;
      onAdFailedToShow();
      return false;
    }
  }

  /// Dispose of the ad
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isAdReady = false;
    _isAdLoading = false;
    
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _isAppOpenAdReady = false;
    _isAppOpenAdLoading = false;
  }

  /// Check if ad is ready to be shown
  bool get isAdReady => _isAdReady && _interstitialAd != null;

  /// Load an app open ad for app launch
  Future<void> loadAppOpenAd() async {
    if (!isAdsSupportedPlatform) {
      print('App open ads not supported on this platform');
      return;
    }

    if (_isAppOpenAdLoading) {
      print('App open ad is already loading');
      return;
    }

    if (_isAppOpenAdReady) {
      print('App open ad is already loaded');
      return;
    }

    _isAppOpenAdLoading = true;
    final adMode = _useDebugTestAds ? 'TEST (Google test ads)' : 'PRODUCTION (Real ads)';
    print('Loading app open ad in $adMode mode with unit ID: $_appOpenAdUnitId');

    await AppOpenAd.load(
      adUnitId: _appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (AppOpenAd ad) {
          print('App open ad loaded successfully');
          _appOpenAd = ad;
          _isAppOpenAdReady = true;
          _isAppOpenAdLoading = false;

          // Set up full screen content callback
          _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (AppOpenAd ad) {
              print('App open ad showed full screen content');
            },
            onAdDismissedFullScreenContent: (AppOpenAd ad) {
              print('App open ad dismissed');
              ad.dispose();
              _appOpenAd = null;
              _isAppOpenAdReady = false;
            },
            onAdFailedToShowFullScreenContent: (AppOpenAd ad, AdError error) {
              print('App open ad failed to show: $error');
              ad.dispose();
              _appOpenAd = null;
              _isAppOpenAdReady = false;
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('Failed to load app open ad: $error');
          _appOpenAd = null;
          _isAppOpenAdReady = false;
          _isAppOpenAdLoading = false;
        },
      ),
    );
  }

  /// Show the app open ad if ready
  /// Returns true if ad was shown or attempted, false if not ready
  Future<bool> showAppOpenAd({
    required VoidCallback onAdClosed,
    required VoidCallback onAdFailedToShow,
  }) async {
    if (!isAdsSupportedPlatform) {
      print('App open ads not supported - proceeding without ad');
      onAdClosed();
      return false;
    }

    if (!_isAppOpenAdReady || _appOpenAd == null) {
      print('App open ad not ready - proceeding without ad');
      onAdFailedToShow();
      return false;
    }

    // Set up callbacks before showing
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (AppOpenAd ad) {
        print('App open ad showed full screen content');
      },
      onAdDismissedFullScreenContent: (AppOpenAd ad) {
        print('App open ad dismissed - proceeding with app');
        ad.dispose();
        _appOpenAd = null;
        _isAppOpenAdReady = false;
        onAdClosed();
      },
      onAdFailedToShowFullScreenContent: (AppOpenAd ad, AdError error) {
        print('App open ad failed to show: $error');
        ad.dispose();
        _appOpenAd = null;
        _isAppOpenAdReady = false;
        onAdFailedToShow();
      },
    );

    try {
      await _appOpenAd!.show();
      return true;
    } catch (e) {
      print('Error showing app open ad: $e');
      _appOpenAd?.dispose();
      _appOpenAd = null;
      _isAppOpenAdReady = false;
      onAdFailedToShow();
      return false;
    }
  }

  /// Check if app open ad is ready to be shown
  bool get isAppOpenAdReady => _isAppOpenAdReady && _appOpenAd != null;
}
