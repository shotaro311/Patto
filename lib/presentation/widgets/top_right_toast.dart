import 'package:flutter/material.dart';

void showTopRightToast(BuildContext context, String message) {
  final overlay = Overlay.of(context, rootOverlay: true);

  final entry = OverlayEntry(
    builder: (context) => Positioned(
      top: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  Future<void>.delayed(const Duration(seconds: 3), entry.remove);
}
