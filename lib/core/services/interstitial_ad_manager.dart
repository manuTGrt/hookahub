import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/app_logger.dart';

/// Gestor singleton para la precarga y muestra de anuncios intersticiales de AdMob.
/// Utiliza el ID de prueba oficial de Google para Android.
class InterstitialAdManager {
  InterstitialAdManager._internal();
  static final InterstitialAdManager instance = InterstitialAdManager._internal();

  // IDs oficiales de pruebas de Google para Intersticial
  static const String testInterstitialAdUnitIdAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testInterstitialAdUnitIdIOS =
      'ca-app-pub-3940256099942544/4411468910';

  static String get testInterstitialAdUnitId {
    if (Platform.isAndroid) return testInterstitialAdUnitIdAndroid;
    if (Platform.isIOS) return testInterstitialAdUnitIdIOS;
    return '';
  }

  InterstitialAd? _interstitialAd;
  bool _isLoading = false;

  /// Precarga con antelación el anuncio intersticial
  void preload() {
    if ((!Platform.isAndroid && !Platform.isIOS) || _isLoading || _interstitialAd != null) return;

    final adUnitId = testInterstitialAdUnitId;
    if (adUnitId.isEmpty) return;

    _isLoading = true;
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoading = false;
          AppLogger.debug('Anuncio intersticial de prueba precargado con éxito.');
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialAd = null;
          _isLoading = false;
          AppLogger.warning('Fallo al precargar anuncio intersticial: ${error.message}');
        },
      ),
    );
  }

  /// Muestra el anuncio intersticial si está listo y ejecuta [onComplete] al cerrarse o si no está disponible.
  void show({VoidCallback? onComplete}) {
    if ((!Platform.isAndroid && !Platform.isIOS) || _interstitialAd == null) {
      onComplete?.call();
      preload();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        preload(); // Precargar el siguiente
        onComplete?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, AdError error) {
        AppLogger.warning('Fallo al mostrar anuncio intersticial: ${error.message}');
        ad.dispose();
        _interstitialAd = null;
        preload();
        onComplete?.call();
      },
    );

    _interstitialAd!.show();
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
