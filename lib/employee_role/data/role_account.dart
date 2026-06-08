import 'package:red5/employee_role/data/app_role.dart';

final class RoleAccount {
  const RoleAccount({
    required this.email,
    required this.password,
    required this.role,
  });

  final String email;
  final String password;
  final AppRole role;

  bool matches({required String email, required String password}) {
    return this.email.toLowerCase() == email.trim().toLowerCase() &&
        this.password == password;
  }
}
