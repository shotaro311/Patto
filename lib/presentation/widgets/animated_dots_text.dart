import 'dart:async';

import 'package:flutter/material.dart';

class AnimatedDotsText extends StatefulWidget {
  const AnimatedDotsText({
    super.key,
    required this.text,
    this.suffix = '',
    this.style,
  });

  final String text;
  final String suffix;
  final TextStyle? style;

  @override
  State<AnimatedDotsText> createState() => _AnimatedDotsTextState();
}

class _AnimatedDotsTextState extends State<AnimatedDotsText> {
  Timer? _timer;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted) return;
      setState(() => _count = (_count + 1) % 4);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _count;
    return Text('${widget.text}$dots${widget.suffix}', style: widget.style);
  }
}
