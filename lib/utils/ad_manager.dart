import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class AdManager {
  bool _isInitialized = false;
  bool _isAdReady = false;
  bool _isAppOpenAdReady = false;

  static const String _gameIdAndroid = '6046109';
  static const String _gameIdIOS = '6046108';

  static const String _interstitialAdUnitIdAndroid = 'Interstitial_Android';
  static const String _interstitialAdUnitIdIOS = 'Interstitial_iOS';

  static const String _rewardedAdUnitIdAndroid = 'Rewarded_Android';
  static const String _rewardedAdUnitIdIOS = 'Rewarded_iOS';

  String get _gameId {
    if (Platform.isAndroid) {
      return _gameIdAndroid;
    } else if (Platform.isIOS) {
      return _gameIdIOS;
    }
    return _gameIdAndroid;
  }

  String get _interstitialAdUnitId {
    if (Platform.isAndroid) {
      return _interstitialAdUnitIdAndroid;
    } else if (Platform.isIOS) {
      return _interstitialAdUnitIdIOS;
    }
    return _interstitialAdUnitIdAndroid;
  }

  String get _rewardedAdUnitId {
    if (Platform.isAndroid) {
      return _rewardedAdUnitIdAndroid;
    } else if (Platform.isIOS) {
      return _rewardedAdUnitIdIOS;
    }
    return _rewardedAdUnitIdAndroid;
  }

  bool get isAdsSupportedPlatform {
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> initialize() async {
    if (!isAdsSupportedPlatform) {
      return;
    }

    if (_isInitialized) {
      return;
    }

    try {
      await UnityAds.init(
        gameId: _gameId,
        testMode: false,
        onComplete: () {
          _isInitialized = true;
          loadAd();
        },
        onFailed: (error, message) {
          _isInitialized = false;
        },
      );
    } catch (e) {
      _isInitialized = false;
    }
  }

  Future<void> loadAd() async {
    if (!isAdsSupportedPlatform || !_isInitialized) {
      return;
    }

    try {
      await UnityAds.load(
        placementId: _interstitialAdUnitId,
        onComplete: (placementId) {
          _isAdReady = true;
        },
        onFailed: (placementId, error, message) {
          _isAdReady = false;
        },
      );
    } catch (e) {
      _isAdReady = false;
    }
  }

  Future<bool> showAd({
    required VoidCallback onAdClosed,
    required VoidCallback onAdFailedToShow,
  }) async {
    if (!isAdsSupportedPlatform || !_isInitialized) {
      onAdClosed();
      return false;
    }

    if (!_isAdReady) {
      onAdFailedToShow();
      return false;
    }

    try {
      await UnityAds.showVideoAd(
        placementId: _interstitialAdUnitId,
        onComplete: (placementId) {
          _isAdReady = false;
          onAdClosed();
          loadAd();
        },
        onFailed: (placementId, error, message) {
          _isAdReady = false;
          onAdFailedToShow();
          loadAd();
        },
        onStart: (placementId) {
        },
        onClick: (placementId) {
        },
        onSkipped: (placementId) {
          _isAdReady = false;
          onAdClosed();
          loadAd();
        },
      );
      return true;
    } catch (e) {
      _isAdReady = false;
      onAdFailedToShow();
      return false;
    }
  }

  bool get isAdReady => _isAdReady && _isInitialized;

  Future<void> loadAppOpenAd() async {
    if (!isAdsSupportedPlatform || !_isInitialized) {
      return;
    }

    try {
      await UnityAds.load(
        placementId: _rewardedAdUnitId,
        onComplete: (placementId) {
          _isAppOpenAdReady = true;
        },
        onFailed: (placementId, error, message) {
          _isAppOpenAdReady = false;
        },
      );
    } catch (e) {
      _isAppOpenAdReady = false;
    }
  }

  Future<bool> showAppOpenAd({
    required VoidCallback onAdClosed,
    required VoidCallback onAdFailedToShow,
  }) async {
    if (!isAdsSupportedPlatform || !_isInitialized) {
      onAdClosed();
      return false;
    }

    if (!_isAppOpenAdReady) {
      onAdFailedToShow();
      return false;
    }

    try {
      await UnityAds.showVideoAd(
        placementId: _rewardedAdUnitId,
        onComplete: (placementId) {
          _isAppOpenAdReady = false;
          onAdClosed();
        },
        onFailed: (placementId, error, message) {
          _isAppOpenAdReady = false;
          onAdFailedToShow();
        },
        onStart: (placementId) {
        },
        onClick: (placementId) {
        },
        onSkipped: (placementId) {
          _isAppOpenAdReady = false;
          onAdClosed();
        },
      );
      return true;
    } catch (e) {
      _isAppOpenAdReady = false;
      onAdFailedToShow();
      return false;
    }
  }

  bool get isAppOpenAdReady => _isAppOpenAdReady && _isInitialized;

  void dispose() {
    _isAdReady = false;
    _isAppOpenAdReady = false;
  }
}
