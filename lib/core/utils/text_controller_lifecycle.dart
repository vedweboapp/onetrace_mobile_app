import 'package:flutter/material.dart';

/// Disposes [controllers] after overlay routes finish IME/viewport rebuilds.
///
/// Calling [TextEditingController.dispose] in [State.dispose] or
/// [Future.whenComplete] right when a sheet/dialog pops can race a final
/// rebuild and trigger "used after being disposed".
void scheduleDisposeTextControllers(
  Iterable<TextEditingController> controllers,
) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in controllers) {
        c.dispose();
      }
    });
  });
}
