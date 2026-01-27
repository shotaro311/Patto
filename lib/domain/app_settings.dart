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

enum AiPromptSendKey {
  enter,
  ctrlEnter,
}

class MacKeyBinding {
  const MacKeyBinding({
    required this.keyCode,
    required this.keyLabel,
    required this.command,
    required this.control,
    required this.option,
    required this.shift,
  });

  final int keyCode;
  final String keyLabel;
  final bool command;
  final bool control;
  final bool option;
  final bool shift;

  Map<String, dynamic> toMap() {
    return {
      'keyCode': keyCode,
      'keyLabel': keyLabel,
      'command': command,
      'control': control,
      'option': option,
      'shift': shift,
    };
  }

  static MacKeyBinding? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final keyCode = raw['keyCode'];
    final keyLabel = raw['keyLabel'];
    if (keyCode is! int || keyLabel is! String) return null;
    return MacKeyBinding(
      keyCode: keyCode,
      keyLabel: keyLabel,
      command: raw['command'] == true,
      control: raw['control'] == true,
      option: raw['option'] == true,
      shift: raw['shift'] == true,
    );
  }

  String displayLabel() {
    final parts = <String>[];
    if (control) parts.add('Ctrl');
    if (option) parts.add('Option');
    if (shift) parts.add('Shift');
    if (command) parts.add('Cmd');
    final label = keyLabel.isEmpty ? keyCode.toString() : keyLabel;
    parts.add(label.toUpperCase());
    return parts.join('+');
  }
}

class AiPromptPreset {
  const AiPromptPreset({
    required this.name,
    required this.prompt,
  });

  final String name;
  final String prompt;

  bool get isEmpty => name.trim().isEmpty || prompt.trim().isEmpty;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'prompt': prompt,
    };
  }

  static AiPromptPreset? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name'];
    final prompt = raw['prompt'];
    if (name is! String || prompt is! String) return null;
    return AiPromptPreset(name: name, prompt: prompt);
  }
}

class AppSettings {
  static const _unset = Object();

  const AppSettings({
    required this.clientId,
    required this.syncEnabled,
    required this.quickLaunchOpenMode,
    required this.macModifierKey,
    required this.macShowHideKeyBinding,
    required this.charCountEnabled,
    required this.charCountExcludeSymbols,
    required this.aiAppleIntelligenceEnabled,
    required this.aiExternalApiEnabled,
    required this.aiPreviewEnabled,
    required this.aiEditKeyBinding,
    required this.aiPromptSendKey,
    required this.aiPromptPresets,
    required this.lastOpenedNoteId,
    required this.lastSyncAt,
  });

  final String clientId;
  final bool syncEnabled;
  final QuickLaunchOpenMode quickLaunchOpenMode;
  final MacModifierKey macModifierKey;
  final MacKeyBinding? macShowHideKeyBinding;
  final bool charCountEnabled;
  final bool charCountExcludeSymbols;
  final bool aiAppleIntelligenceEnabled;
  final bool aiExternalApiEnabled;
  final bool aiPreviewEnabled;
  final MacKeyBinding? aiEditKeyBinding;
  final AiPromptSendKey aiPromptSendKey;
  final List<AiPromptPreset> aiPromptPresets;
  final String? lastOpenedNoteId;
  final DateTime? lastSyncAt;

  bool get aiEnabled => aiAppleIntelligenceEnabled || aiExternalApiEnabled;

  AppSettings copyWith({
    bool? syncEnabled,
    QuickLaunchOpenMode? quickLaunchOpenMode,
    MacModifierKey? macModifierKey,
    Object? macShowHideKeyBinding = _unset,
    bool? charCountEnabled,
    bool? charCountExcludeSymbols,
    bool? aiAppleIntelligenceEnabled,
    bool? aiExternalApiEnabled,
    bool? aiPreviewEnabled,
    Object? aiEditKeyBinding = _unset,
    AiPromptSendKey? aiPromptSendKey,
    List<AiPromptPreset>? aiPromptPresets,
    Object? lastOpenedNoteId = _unset,
    Object? lastSyncAt = _unset,
  }) {
    return AppSettings(
      clientId: clientId,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      quickLaunchOpenMode: quickLaunchOpenMode ?? this.quickLaunchOpenMode,
      macModifierKey: macModifierKey ?? this.macModifierKey,
      macShowHideKeyBinding: identical(macShowHideKeyBinding, _unset)
          ? this.macShowHideKeyBinding
          : macShowHideKeyBinding as MacKeyBinding?,
      charCountEnabled: charCountEnabled ?? this.charCountEnabled,
      charCountExcludeSymbols:
          charCountExcludeSymbols ?? this.charCountExcludeSymbols,
      aiAppleIntelligenceEnabled:
          aiAppleIntelligenceEnabled ?? this.aiAppleIntelligenceEnabled,
      aiExternalApiEnabled:
          aiExternalApiEnabled ?? this.aiExternalApiEnabled,
      aiPreviewEnabled: aiPreviewEnabled ?? this.aiPreviewEnabled,
      aiEditKeyBinding: identical(aiEditKeyBinding, _unset)
          ? this.aiEditKeyBinding
          : aiEditKeyBinding as MacKeyBinding?,
      aiPromptSendKey: aiPromptSendKey ?? this.aiPromptSendKey,
      aiPromptPresets: aiPromptPresets ?? this.aiPromptPresets,
      lastOpenedNoteId: identical(lastOpenedNoteId, _unset)
          ? this.lastOpenedNoteId
          : lastOpenedNoteId as String?,
      lastSyncAt: identical(lastSyncAt, _unset)
          ? this.lastSyncAt
          : lastSyncAt as DateTime?,
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
      _ => MacModifierKey.shift,
    };
  }

  static MacModifierKey? fromStringOrNull(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return fromString(raw);
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

extension AiPromptSendKeyCodec on AiPromptSendKey {
  static AiPromptSendKey fromString(String? raw) {
    return switch (raw) {
      'enter' => AiPromptSendKey.enter,
      _ => AiPromptSendKey.ctrlEnter,
    };
  }

  String toStorageString() {
    return switch (this) {
      AiPromptSendKey.enter => 'enter',
      AiPromptSendKey.ctrlEnter => 'ctrlEnter',
    };
  }
}
