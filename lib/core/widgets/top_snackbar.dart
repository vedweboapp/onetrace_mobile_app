import 'dart:async';

import 'package:flutter/material.dart';

extension TopSnackbarX on BuildContext {
  void showTopSnackBar(SnackBar snackBar) {
    final messenger = ScaffoldMessenger.of(this);

    messenger
      ..hideCurrentSnackBar()
      ..clearMaterialBanners();

    final action = snackBar.action;
    final banner = MaterialBanner(
      content: snackBar.content,
      backgroundColor: snackBar.backgroundColor,
      leading: snackBar.showCloseIcon == true ? null : const Icon(Icons.info_outline),
      actions: [
        if (action != null)
          TextButton(
            onPressed: action.onPressed,
            child: Text(action.label),
          ),
        TextButton(
          onPressed: messenger.hideCurrentMaterialBanner,
          child: const Text('Dismiss'),
        ),
      ],
    );

    messenger.showMaterialBanner(banner);

    Timer(snackBar.duration, () {
      messenger.hideCurrentMaterialBanner();
    });
  }
}
