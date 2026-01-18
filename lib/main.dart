import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/providers.dart';
import 'data/datasources/local/open_isar.dart';

SemanticsHandle? _semanticsHandle;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isMacOS) {
    _semanticsHandle ??= WidgetsBinding.instance.ensureSemantics();
  }

  final prefs = await SharedPreferences.getInstance();
  final isar = await openIsar();
  const secureStorage = FlutterSecureStorage();

  final supabaseConfig = SupabaseConfig.fromEnvOrNull();
  if (supabaseConfig != null) {
    await Supabase.initialize(
      url: supabaseConfig.url,
      anonKey: supabaseConfig.anonKey,
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isarProvider.overrideWithValue(isar),
        secureStorageProvider.overrideWithValue(secureStorage),
        supabaseConfigProvider.overrideWithValue(supabaseConfig),
      ],
      child: const PattoApp(),
    ),
  );
}
