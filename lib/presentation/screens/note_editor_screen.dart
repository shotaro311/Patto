import 'package:flutter/material.dart';

import 'note_editor_pane.dart';

class NoteEditorScreen extends StatelessWidget {
  const NoteEditorScreen({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: NoteEditorPane(noteId: noteId),
    );
  }
}

