enum QuickLaunchAction {
  show,
  hide,
}

class QuickLaunchEvent {
  const QuickLaunchEvent({
    required this.action,
    this.source,
  });

  final QuickLaunchAction action;
  final String? source;
}

extension QuickLaunchActionCodec on QuickLaunchAction {
  static QuickLaunchAction fromString(String? raw) {
    return switch (raw) {
      'hide' => QuickLaunchAction.hide,
      _ => QuickLaunchAction.show,
    };
  }

  String toStorageString() {
    return switch (this) {
      QuickLaunchAction.show => 'show',
      QuickLaunchAction.hide => 'hide',
    };
  }
}
