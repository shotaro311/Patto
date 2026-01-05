import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';
import 'supabase_providers.dart';

final authServiceProvider = Provider<AuthService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return AuthService(client);
});

final authUserIdStreamProvider = StreamProvider<String?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return Stream.value(null);
  }
  return client.auth.onAuthStateChange.map((data) => data.session?.user.id);
});

