import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/models/mix.dart';
import 'package:hookahub/core/models/tobacco.dart';
import 'package:hookahub/features/catalog/data/tobacco_repository.dart';
import 'package:hookahub/features/catalog/domain/catalog_filters.dart';
import 'package:hookahub/core/providers/database_health_provider.dart';
import 'package:hookahub/core/services/database_health_service.dart';
import 'package:hookahub/features/community/data/community_repository.dart';
import 'package:hookahub/features/search/search_provider.dart';

class FakeTobaccoRepository implements TobaccoRepository {
  bool shouldThrow = false;
  final List<Tobacco> tobaccos = const [
    Tobacco(
      id: 'tobacco-1',
      name: 'Love 66',
      brand: 'Adalya',
      description: 'Mezcla tropical con menta',
      flavors: ['Frutas tropicales', 'Menta'],
    ),
  ];

  @override
  Future<List<Tobacco>> fetchTobaccos({
    required int offset,
    int limit = 20,
    String? query,
    CatalogFilter? filter,
  }) async {
    if (shouldThrow) {
      throw Exception('Fallo en TobaccoRepository');
    }
    if (query != null && query.isNotEmpty) {
      return tobaccos
          .where((t) => t.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    return tobaccos;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCommunityRepository implements CommunityRepository {
  bool shouldThrow = false;
  final List<Mix> mixes = const [
    Mix(
      id: 'mix-1',
      name: 'Brisa Marina',
      author: 'Tester',
      rating: 4.5,
      ingredients: ['Love 66', 'Menta'],
      color: Colors.blue,
      reviews: 2,
    ),
  ];

  @override
  Future<List<Mix>> fetchMixes({
    String orderBy = 'recent',
    int limit = 20,
    int offset = 0,
    String? tobaccoName,
    String? tobaccoBrand,
  }) async {
    if (shouldThrow) {
      throw Exception('Fallo en CommunityRepository');
    }
    return mixes;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDatabaseHealthService implements DatabaseHealthService {
  @override
  Future<bool> checkDatabaseConnection() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHealthProvider healthProvider;
  late FakeTobaccoRepository fakeTobaccoRepo;
  late FakeCommunityRepository fakeCommunityRepo;
  late SearchProvider searchProvider;

  setUp(() {
    healthProvider = DatabaseHealthProvider(
      healthService: FakeDatabaseHealthService(),
    );
    fakeTobaccoRepo = FakeTobaccoRepository();
    fakeCommunityRepo = FakeCommunityRepository();
    searchProvider = SearchProvider(
      tobaccoRepository: fakeTobaccoRepo,
      communityRepository: fakeCommunityRepo,
    );
  });

  tearDown(() {
    searchProvider.dispose();
    healthProvider.dispose();
  });

  group('SearchProvider Sealed State Transitions', () {
    test('inicia en SearchInitial', () {
      expect(searchProvider.state, isA<SearchInitial>());
      expect(searchProvider.isSearching, isFalse);
      expect(searchProvider.tobaccoResults, isEmpty);
      expect(searchProvider.mixResults, isEmpty);
      expect(searchProvider.lastQuery, isEmpty);
      expect(searchProvider.totalResults, 0);
      expect(searchProvider.error, isNull);
    });

    test('búsqueda vacía resetea a SearchInitial', () async {
      await searchProvider.search('   ');
      expect(searchProvider.state, isA<SearchInitial>());
      expect(searchProvider.tobaccoResults, isEmpty);
    });

    test('búsqueda exitosa transita a SearchSuccess', () async {
      await searchProvider.search('Love');

      expect(searchProvider.state, isA<SearchSuccess>());
      final successState = searchProvider.state as SearchSuccess;
      expect(successState.query, 'Love');
      expect(successState.tobaccos.length, 1);
      expect(successState.tobaccos.first.name, 'Love 66');
      expect(successState.mixes.length, 1);
      expect(searchProvider.isSearching, isFalse);
      expect(searchProvider.lastQuery, 'Love');
      expect(searchProvider.totalResults, 2);

      searchProvider.clear();
      expect(searchProvider.state, isA<SearchInitial>());
      expect(searchProvider.totalResults, 0);
    });

    test('búsqueda con error transita a SearchError', () async {
      fakeTobaccoRepo.shouldThrow = true;

      await searchProvider.search('error');

      expect(searchProvider.state, isA<SearchError>());
      final errorState = searchProvider.state as SearchError;
      expect(errorState.query, 'error');
      expect(errorState.message, contains('Fallo en TobaccoRepository'));
      expect(searchProvider.error, isNotNull);
      expect(searchProvider.isSearching, isFalse);
      expect(searchProvider.tobaccoResults, isEmpty);
    });
  });
}
