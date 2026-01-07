import 'package:flutter_riverpod/flutter_riverpod.dart';

final quickLaunchEventProvider = StateProvider<int>((ref) => 0);
final quickLaunchSourceProvider = StateProvider<String?>((ref) => null);
