import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  // Manual load of .env for the script
  final envFile = File('.env');
  final lines = await envFile.readAsLines();
  String? url;
  String? key;
  for (final line in lines) {
    if (line.startsWith('SUPABASE_URL=')) {
      url = line.split('=')[1];
    } else if (line.startsWith('SUPABASE_ANON_KEY=')) {
      key = line.split('=')[1];
    }
  }

  if (url == null || key == null) {
    print('Error: Could not find SUPABASE_URL or SUPABASE_ANON_KEY in .env');
    return;
  }

  await Supabase.initialize(url: url, anonKey: key);
  final client = Supabase.instance.client;

  print('Fetching first 5 mixes...');
  final response = await client
      .from('mixes')
      .select('id, name, reviews, rating, reviews_real:reviews(count)')
      .limit(5);

  for (final mix in response as List) {
    final name = mix['name'];
    final storedReviews = mix['reviews'];
    final realReviewsList = mix['reviews_real'] as List;
    final realReviewsCount = realReviewsList.isNotEmpty
        ? realReviewsList.first['count']
        : 0;

    print('Mix: $name | Stored: $storedReviews | Real: $realReviewsCount');
    if (storedReviews != realReviewsCount) {
      print('*** MISMATCH DETECTED ***');
    }
  }
  exit(0);
}
