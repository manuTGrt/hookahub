import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/utils/app_logger.dart';

/// Widget de Banner de AdMob reutilizable.
/// Utiliza el Ad Unit ID de prueba oficial de Google para Android.
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  // IDs oficiales de pruebas de Google para Banner
  static const String testBannerAdUnitIdAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String testBannerAdUnitIdIOS =
      'ca-app-pub-3940256099942544/2934735716';

  static String get testBannerAdUnitId {
    if (Platform.isAndroid) return testBannerAdUnitIdAndroid;
    if (Platform.isIOS) return testBannerAdUnitIdIOS;
    return '';
  }

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final adUnitId = AdBannerWidget.testBannerAdUnitId;
    if (adUnitId.isEmpty) return;

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          AppLogger.warning('Fallo al cargar Banner Ad: ${error.message}');
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
              _isLoaded = false;
            });
          }
        },
      ),
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
