import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/app_settings.dart';
import '../../services/sync_service.dart';
import 'app_settings_controller.dart';
import 'sync_providers.dart';

final autoSyncControllerProvider = Provider<AutoSyncController>((ref) {
  final controller = AutoSyncController(ref);
  final settings = ref.read(appSettingsProvider);
  controller.setSyncEnabled(settings.syncEnabled);
  ref.listen<AppSettings>(
    appSettingsProvider,
    (previous, next) => controller.setSyncEnabled(next.syncEnabled),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

class AutoSyncController {
  AutoSyncController(this._ref);

  final Ref _ref;
  Timer? _timer;
  Timer? _pollTimer;
  bool _syncing = false;
  bool _pending = false;
  bool _enabled = false;
  static const Duration _pollInterval = Duration(seconds: 20);

  void setSyncEnabled(bool enabled) {
    if (_enabled == enabled) return;
    _enabled = enabled;
    if (_enabled) {
      _startPolling();
      schedule(delay: Duration.zero);
    } else {
      _stopPolling();
      _pending = false;
      _timer?.cancel();
    }
  }

  void schedule({Duration delay = const Duration(seconds: 1)}) {
    _pending = true;
    _timer?.cancel();
    _timer = Timer(delay, _run);
  }

  void dispose() {
    _timer?.cancel();
    _stopPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      schedule(delay: Duration.zero);
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _run() async {
    if (_syncing || _ref.read(syncInProgressProvider)) {
      if (_pending) {
        schedule(delay: const Duration(seconds: 1));
      }
      return;
    }

    _pending = false;
    final settings = _ref.read(appSettingsProvider);
    if (!settings.syncEnabled) return;

    final service = _ref.read(syncServiceProvider);
    if (service == null) return;

    _syncing = true;
    _ref.read(syncInProgressProvider.notifier).state = true;
    try {
      final result = await service.syncNow(lastSyncAt: settings.lastSyncAt);
      if (result.lastSyncAt != null) {
        await _ref.read(appSettingsProvider.notifier).setLastSyncAt(result.lastSyncAt);
      }

      if (result.conflictDetails.isNotEmpty) {
        _mergeConflicts(result.conflictDetails);
      }
    } catch (_) {
      // 自動同期は失敗してもUIをブロックしない
    } finally {
      _syncing = false;
      _ref.read(syncInProgressProvider.notifier).state = false;
      if (_pending) {
        schedule();
      }
    }
  }

  void _mergeConflicts(List<SyncConflict> conflicts) {
    final existing = _ref.read(syncConflictsProvider);
    final merged = <String, SyncConflict>{
      for (final item in existing) item.local.uuid: item,
      for (final item in conflicts) item.local.uuid: item,
    };
    _ref.read(syncConflictsProvider.notifier).state =
        merged.values.toList(growable: false);
  }
}
