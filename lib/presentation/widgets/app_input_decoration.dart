import 'package:flutter/material.dart';

InputDecoration appInputDecoration({
  String? labelText,
  String? hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  bool? isDense,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    border: const OutlineInputBorder(),
    isDense: isDense,
  );
}
