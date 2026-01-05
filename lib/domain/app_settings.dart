enum QuickLaunchOpenMode {
  newNote,
  lastNote,
}

enum MacModifierKey {
  command,
  control,
  option,
  shift,
}

class AppSettings {
  const AppSettings({
    required this.clientId,
    required this.syncEnabled,
    required this.quickLaunchOpenMode,
    required this.macModifierKey,
    required this.aiEnabled,
    required this.lastOpenedNoteId,
    required this.lastSyncAt,
  });

  final String clientId;
  final bool syncEnabled;
  final QuickLaunchOpenMode quickLaunchOpenMode;
  final MacModifierKey macModifierKey;
  final bool aiEnabled;
  final String? lastOpenedNoteId;
  final DateTime? lastSyncAt;

  AppSettings copyWith({
    bool? syncEnabled,
    QuickLaunchOpenMode? quickLaunchOpenMode,
    MacModifierKey? macModifierKey,
    bool? aiEnabled,
    String? lastOpenedNoteId,
    DateTime? lastSyncAt,
  }) {
    return AppSettings(
      clientId: clientId,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      quickLaunchOpenMode: quickLaunchOpenMode ?? this.quickLaunchOpenMode,
      macModifierKey: macModifierKey ?? this.macModifierKey,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      lastOpenedNoteId: lastOpenedNoteId,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}

extension QuickLaunchOpenModeCodec on QuickLaunchOpenMode {
  static QuickLaunchOpenMode fromString(String? raw) {
    return switch (raw) {
      'lastNote' => QuickLaunchOpenMode.lastNote,
      _ => QuickLaunchOpenMode.newNote,
    };
  }

  String toStorageString() {
    return switch (this) {
      QuickLaunchOpenMode.newNote => 'newNote',
      QuickLaunchOpenMode.lastNote => 'lastNote',
    };
  }
}

extension MacModifierKeyCodec on MacModifierKey {
  static MacModifierKey fromString(String? raw) {
    return switch (raw) {
      'control' => MacModifierKey.control,
      'option' => MacModifierKey.option,
      'shift' => MacModifierKey.shift,
      _ => MacModifierKey.command,
    };
  }

  String toStorageString() {
    return switch (this) {
      MacModifierKey.command => 'command',
      MacModifierKey.control => 'control',
      MacModifierKey.option => 'option',
      MacModifierKey.shift => 'shift',
    };
  }
}

