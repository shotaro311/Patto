import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/tag_dictionary_repository.dart';
import 'tag_dictionary_repository_provider.dart';

final tagSummariesProvider = StreamProvider<List<TagSummary>>((ref) {
  final repo = ref.watch(tagDictionaryRepositoryProvider);
  return repo.watchTagSummaries();
});
