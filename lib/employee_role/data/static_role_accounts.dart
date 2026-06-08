import 'package:red5/employee_role/data/app_role.dart';
import 'package:red5/employee_role/data/role_account.dart';

abstract final class StaticRoleAccounts {
  const StaticRoleAccounts._();

  static const technicianEmail = 'technician@yopmail.com';
  static const technicianPassword = 'Technician@123';

  static const accounts = <RoleAccount>[
    RoleAccount(
      email: technicianEmail,
      password: technicianPassword,
      role: AppRole.technician,
    ),
  ];

  static RoleAccount? authenticate({
    required String email,
    required String password,
  }) {
    for (final account in accounts) {
      if (account.matches(email: email, password: password)) return account;
    }
    return null;
  }

  static bool hasTechnicianAccount() {
    return accounts.any((account) => account.role == AppRole.technician);
  }

  static bool hasOperativeAccount() {
    return accounts.any((account) => account.role == AppRole.operative);
  }

  static bool hasSalesAccount() {
    return accounts.any((account) => account.role == AppRole.sales);
  }

  static bool hasManagerAccount() {
    return accounts.any((account) => account.role == AppRole.manager);
  }
}
