import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Central place for AdMob rewarded ads.
///
/// Uses Google's official TEST ad unit ids by default so the app works
/// immediately without risking an AdMob ban. Before publishing, replace the
/// production ids in [_androidRewardedProd] / [_iosRewardedProd] with the real
/// ad units from your AdMob console.
class AdsService {
  RewardedAd? _rewarded;
  bool _loading = false;

  /// Waiters that are blocked in [showRewarded] until the in-flight load
  /// finishes. Each completer receives whether an ad became available.
  final List<Completer<bool>> _loadWaiters = [];

  // ── Ad unit ids ───────────────────────────────────────────────────────────
  // Google's public TEST rewarded ids — safe to use during development.
  static const String _androidRewardedTest =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _iosRewardedTest =
      'ca-app-pub-3940256099942544/1712485313';

  // Real AdMob rewarded ad unit ids (production).
  static const String _androidRewardedProd =
      'ca-app-pub-6185468394048368/2571248002';
  // iOS not published yet — keep the public test id until a real unit exists.
  static const String _iosRewardedProd = _iosRewardedTest;

  /// While true we always serve TEST ads. Automatically enabled in debug and
  /// disabled in release builds, so production users get real ads while you
  /// keep seeing safe test ads during development.
  static const bool _useTestAds = kDebugMode;

  /// DEV ONLY: when true, on platforms where AdMob is NOT supported (web /
  /// desktop) the rewarded flow is simulated so the reward can be tested
  /// without a real device. Tied to debug mode so it never runs in release.
  static const bool _mockOnUnsupported = kDebugMode;

  /// Whether ads can run at all on the current platform (mobile only).
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Whether the rewarded button should be offered to the user. True on mobile
  /// (real ads) and, in dev, also on web/desktop (mocked).
  bool get canOfferReward => isSupported || _mockOnUnsupported;

  String get _rewardedUnitId {
    final android = _useTestAds ? _androidRewardedTest : _androidRewardedProd;
    final ios = _useTestAds ? _iosRewardedTest : _iosRewardedProd;
    return defaultTargetPlatform == TargetPlatform.iOS ? ios : android;
  }

  /// Whether a rewarded ad is loaded and ready to show.
  bool get isRewardedReady => _rewarded != null;

  /// Preload a rewarded ad so it can be shown instantly later.
  void loadRewarded() {
    if (!isSupported || _loading || _rewarded != null) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: _rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _loading = false;
          _resolveLoadWaiters(true);
        },
        onAdFailedToLoad: (error) {
          _rewarded = null;
          _loading = false;
          debugPrint('Rewarded ad failed to load: $error');
          _resolveLoadWaiters(false);
        },
      ),
    );
  }

  /// Completes everyone waiting on the current load with [available].
  void _resolveLoadWaiters(bool available) {
    if (_loadWaiters.isEmpty) return;
    final waiters = List<Completer<bool>>.from(_loadWaiters);
    _loadWaiters.clear();
    for (final w in waiters) {
      if (!w.isCompleted) w.complete(available);
    }
  }

  /// Waits until the in-flight load finishes (or a short timeout elapses),
  /// returning whether an ad became available. Used so a freshly opened screen
  /// (e.g. the arena battle result) can still show an ad even if it wasn't
  /// preloaded a few seconds earlier.
  Future<bool> _awaitLoad() {
    final completer = Completer<bool>();
    _loadWaiters.add(completer);
    return completer.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () {
        _loadWaiters.remove(completer);
        return _rewarded != null;
      },
    );
  }

  /// Show the loaded rewarded ad.
  ///
  /// Returns true if the user earned the reward, false otherwise (ad not ready,
  /// dismissed early, or unsupported platform). A new ad is preloaded after.
  Future<bool> showRewarded() async {
    if (!isSupported) {
      // Dev fallback: simulate an ad on web/desktop so the reward can be tested.
      if (_mockOnUnsupported) {
        await Future<void>.delayed(const Duration(seconds: 1));
        return true;
      }
      return false;
    }
    final ad = _rewarded;
    if (ad == null) {
      // Not preloaded yet (common when a screen offers the ad only moments
      // after opening, e.g. the arena battle result). Kick off a load and
      // wait for it instead of failing immediately.
      loadRewarded();
      final available = await _awaitLoad();
      if (!available || _rewarded == null) return false;
      return showRewarded();
    }
    _rewarded = null;

    // Completes only once the ad is dismissed, carrying whether the reward was
    // actually earned. `ad.show()` resolves before the user finishes watching,
    // so we must wait for the dismiss/fail callback instead.
    final completer = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewarded();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        loadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await ad.show(
      onUserEarnedReward: (_, _) => earned = true,
    );
    return completer.future;
  }

  void dispose() {
    _resolveLoadWaiters(false);
    _rewarded?.dispose();
    _rewarded = null;
  }
}

/// App-wide singleton for ad serving. Preloads its first ad lazily.
final adsServiceProvider = Provider<AdsService>((ref) {
  final service = AdsService();
  service.loadRewarded();
  ref.onDispose(service.dispose);
  return service;
});
