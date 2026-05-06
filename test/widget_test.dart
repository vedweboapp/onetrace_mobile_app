// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:red5/app/app.dart';
import 'package:red5/core/constants/app_strings.dart';
import 'package:red5/core/network/auth_api_client.dart';
import 'package:red5/core/providers/local_storage_provider.dart';
import 'package:red5/core/storage/shared_preferences_storage.dart';
import 'package:red5/features/login/presentation/views/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

AuthApiClient _fakeAuthApiClient() {
  final dio = Dio(
    BaseOptions(
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 200,
            data: const <String, dynamic>{},
          ),
        );
      },
    ),
  );
  return AuthApiClient(dio: dio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Splash opens login then dashboard', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = SharedPreferencesStorage(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageProvider.overrideWith((ref) => storage),
          authApiClientProvider.overrideWithValue(_fakeAuthApiClient()),
        ],
        child: const App(),
      ),
    );

    expect(find.text('RED5'), findsOneWidget);
    expect(find.text(AppStrings.loginTitle), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.loginTitle), findsAtLeastNWidgets(1));

    await tester.enterText(find.byType(TextFormField).first, 'test@red5.dev');
    await tester.enterText(find.byType(TextFormField).last, '123456');
    await tester.tap(find.byKey(LoginPage.signInButtonKey));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.dashboardTitle), findsOneWidget);
  });
}
