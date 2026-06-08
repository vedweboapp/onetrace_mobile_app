import 'package:flutter/material.dart';

/// Drops focus before [Navigator.pop] so disposed [InkWell] / [TextField] widgets
/// do not receive highlight-mode updates on a deactivated element tree.
void popOverlaySafely<T>(BuildContext context, [T? result]) {
  FocusManager.instance.primaryFocus?.unfocus();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    Navigator.of(context).pop<T>(result);
  });
}

void unfocusPrimary() {
  FocusManager.instance.primaryFocus?.unfocus();
}
