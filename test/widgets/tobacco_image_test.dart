import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/widgets/tobacco_image.dart';

void main() {
  group('TobaccoImage Cache Dimension & Memory Optimization Tests', () {
    test(
      'resolveCacheDimension utiliza constraintSize cuando explicitSize es double.infinity',
      () {
        final cacheWidth = TobaccoImage.resolveCacheDimension(
          explicitSize: double.infinity,
          constraintSize: 160.0,
          devicePixelRatio: 2.0,
        );

        expect(cacheWidth, 320);
      },
    );

    test(
      'resolveCacheDimension aplica el tope máximo maxDefaultCacheDimension (512) para evitar OOM',
      () {
        final cacheWidth = TobaccoImage.resolveCacheDimension(
          explicitSize: double.infinity,
          constraintSize: 400.0,
          devicePixelRatio: 3.0,
        );

        expect(cacheWidth, TobaccoImage.maxDefaultCacheDimension);
      },
    );

    test(
      'resolveCacheDimension retorna maxDefaultCacheDimension cuando tanto explicitSize como constraintSize son infinitos',
      () {
        final cacheWidth = TobaccoImage.resolveCacheDimension(
          explicitSize: double.infinity,
          constraintSize: double.infinity,
          devicePixelRatio: 2.0,
        );

        expect(cacheWidth, TobaccoImage.maxDefaultCacheDimension);
      },
    );

    testWidgets(
      'TobaccoImage muestra el placeholder sin desbordamiento cuando imageUrl es null y dimensiones son double.infinity',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 180,
                height: 140,
                child: TobaccoImage(
                  imageUrl: null,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'TobaccoImage asigna solo memCacheWidth (dejando memCacheHeight en null) y BoxFit.cover para evitar deformación/achatado',
      (tester) async {
        await tester.pumpWidget(
          const MediaQuery(
            data: MediaQueryData(devicePixelRatio: 2.0),
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 160,
                  height: 100,
                  child: TobaccoImage(
                    imageUrl: 'https://example.com/tobacco.jpg',
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            ),
          ),
        );

        final cachedImage = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage),
        );
        expect(cachedImage.fit, BoxFit.cover);
        expect(cachedImage.memCacheWidth, 320);
        expect(cachedImage.memCacheHeight, isNull);
        expect(cachedImage.maxWidthDiskCache, isNull);
        expect(cachedImage.maxHeightDiskCache, isNull);
      },
    );
  });
}

