import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/app/routes/app_router.dart';
import 'package:red5/core/constants/app_strings.dart';
import 'package:red5/core/network/connectivity_ui_scope.dart';
import 'package:red5/core/theme/app_theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
      supportedLocales: FlutterQuillLocalizations.supportedLocales,
      builder: (context, child) {
        return ConnectivityUiScope(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
