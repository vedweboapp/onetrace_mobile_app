import 'package:flutter_test/flutter_test.dart';
import 'package:red5/core/auth/user_role_navigation.dart';
import 'package:red5/features/dashboard/presentation/views/dashboard_page.dart';
import 'package:red5/employee_role/employee_home/employee_home_page.dart';

void main() {
  group('UserRoleNavigation.isAdminRoleName', () {
    test('treats admin roles as admin shell', () {
      for (final role in ['Admin', 'administrator', 'CEO', ' ceo ']) {
        expect(UserRoleNavigation.isAdminRoleName(role), isTrue);
      }
    });

    test('treats field roles as employee shell', () {
      for (final role in ['Technician', 'Manager', 'Operative', 'Site']) {
        expect(UserRoleNavigation.isAdminRoleName(role), isFalse);
      }
    });
  });

  group('UserRoleNavigation.homePathForRoleName', () {
    test('CEO opens admin dashboard', () {
      expect(
        UserRoleNavigation.homePathForRoleName('CEO'),
        DashboardPage.homePath,
      );
    });

    test('technician opens employee home', () {
      expect(
        UserRoleNavigation.homePathForRoleName('Technician'),
        TechnicianHomePage.path,
      );
    });
  });
}
