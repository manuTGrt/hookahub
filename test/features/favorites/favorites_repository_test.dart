import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/models/mix.dart';
import 'package:hookahub/features/favorites/data/favorites_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testMix1 = Mix(
    id: 'mix-1',
    name: 'Love 66',
    author: 'HookahMaster',
    rating: 4.8,
    ingredients: ['Sandía', 'Melón', 'Menta'],
    color: Colors.red,
  );

  const testMix2 = Mix(
    id: 'mix-2',
    name: 'Mi Amor',
    author: 'ShishaFan',
    rating: 4.5,
    ingredients: ['Plátano', 'Piña', 'Menta'],
    color: Colors.green,
  );

  group('FavoritesRepository Multi-User Isolation Tests', () {
    test('Los favoritos de user-1 y user-2 se almacenan de forma completamente aislada', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = FavoritesRepository();

      // Guardar mix1 para user-1
      await repo.saveFavorites([testMix1], userId: 'user-1');

      // Guardar mix2 para user-2
      await repo.saveFavorites([testMix2], userId: 'user-2');

      // Cargar favoritos de cada usuario
      final user1Favs = await repo.loadFavorites(userId: 'user-1');
      final user2Favs = await repo.loadFavorites(userId: 'user-2');

      expect(user1Favs.length, 1);
      expect(user1Favs.first.id, 'mix-1');

      expect(user2Favs.length, 1);
      expect(user2Favs.first.id, 'mix-2');

      // Verificar que las claves en SharedPreferences están separadas
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('favorites_mixes_user-1'), isTrue);
      expect(prefs.containsKey('favorites_mixes_user-2'), isTrue);
      expect(prefs.containsKey('favorites_mixes'), isFalse);
    });

    test('El Top 5 de user-1 y user-2 están aislados', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = FavoritesRepository();

      await repo.saveTop5Ids(['mix-1'], userId: 'user-1');
      await repo.saveTop5Ids(['mix-2'], userId: 'user-2');

      final user1Top5 = await repo.loadTop5Ids(userId: 'user-1');
      final user2Top5 = await repo.loadTop5Ids(userId: 'user-2');

      expect(user1Top5, ['mix-1']);
      expect(user2Top5, ['mix-2']);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('top5_mix_ids_user-1'), isTrue);
      expect(prefs.containsKey('top5_mix_ids_user-2'), isTrue);
    });

    test('Usuario anónimo (guest) no interfiere con usuarios autenticados', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = FavoritesRepository();

      await repo.saveFavorites([testMix1], userId: null);
      await repo.saveFavorites([testMix2], userId: 'user-1');

      final guestFavs = await repo.loadFavorites(userId: null);
      final user1Favs = await repo.loadFavorites(userId: 'user-1');

      expect(guestFavs.first.id, 'mix-1');
      expect(user1Favs.first.id, 'mix-2');
    });

    test('Migración: datos legacy en favorites_mixes se leen sin pérdidas', () async {
      // Simular datos preexistentes de una versión anterior
      SharedPreferences.setMockInitialValues({
        'favorites_mixes': [jsonEncode(testMix1.toMap())],
        'top5_mix_ids': ['mix-1'],
      });

      final repo = FavoritesRepository();

      // Cargar favoritos para user-legacy (al fallar la red o no tener en nube, usa fallback de migración)
      final favs = await repo.loadFavorites(userId: 'user-legacy');

      expect(favs.isNotEmpty, isTrue);
      expect(favs.first.id, 'mix-1');
    });
  });
}
