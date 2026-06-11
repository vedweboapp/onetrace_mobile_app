import 'package:red5/employee_role/data/app_role.dart';
import 'package:red5/features/user_profile/data/role_models.dart';
import 'package:red5/features/user_profile/data/user_profile_models.dart';

/// Local-only profile data for technician / worker settings (no `/user-profile/` API).
abstract final class EmployeePersonalProfilePlaceholder {
  static const _technicianRoleId = '2';

  static List<RoleModel> rolesFor(String roleLabel) {
    return [
      RoleModel(id: _technicianRoleId, roleName: roleLabel),
    ];
  }

  static UserProfileModel profile({
    required String roleLabel,
    String? firstName,
    String? lastName,
  }) {
    const appearance = AppearanceSettingsModel(
      themeMode: 'light',
      language: 'en',
      accentType: 'preset',
      accentPresetId: 'black',
      accentCustomHex: '',
      languageOptions: [
        AppearanceOptionModel(id: 'en', label: 'English (United States)'),
      ],
      themeModeOptions: [
        AppearanceOptionModel(id: 'light', label: 'Light'),
        AppearanceOptionModel(id: 'dark', label: 'Dark'),
      ],
      accentPresets: [
        AppearanceOptionModel(id: 'black', label: 'Black', hex: '#000000'),
        AppearanceOptionModel(id: 'orange', label: 'Orange', hex: '#F97316'),
        AppearanceOptionModel(id: 'blue', label: 'Blue', hex: '#2563EB'),
        AppearanceOptionModel(id: 'green', label: 'Green', hex: '#059669'),
        AppearanceOptionModel(id: 'gray', label: 'Gray', hex: '#4B5563'),
      ],
    );

    return UserProfileModel(
      id: 'local-employee-profile',
      userDetail: UserDetail(
        id: 'local-employee-profile',
        uuid: '',
        firstName: firstName ?? 'Alex',
        lastName: lastName ?? 'Rivera',
        email: 'alex.rivera@example.com',
        phoneNumber: '+1 555 010 2244',
        gender: 'Male',
        userImage: '',
        inviteStatus: '',
        invitationSentAt: '',
        invitationExpired: false,
      ),
      role: roleLabel,
      roleId: _technicianRoleId,
      organizationDetail: const OrganizationDetailModel(
        id: '1',
        uuid: '',
        companyName: 'Simho Construction',
      ),
      appearanceSettings: appearance,
      dateOfBirth: '03/15/1992',
      addressLine1: '1200 Harbor View Drive',
      addressLine2: 'Suite 4B',
      city: 'Austin',
      state: 'TX',
      country: 'United States',
      postalCode: '78701',
      communications: const [
        UserCommunicationModel(
          id: 'local-comm-1',
          phone: '+1 555 010 2244',
          email: 'alex.rivera@example.com',
          isPrimary: true,
        ),
      ],
      addresses: const [
        UserAddressModel(
          id: 'local-addr-1',
          address1: '1200 Harbor View Drive',
          address2: 'Suite 4B',
          city: 'Austin',
          state: 'TX',
          pincode: '78701',
          isPrimary: true,
        ),
      ],
    );
  }

  static String roleLabelFromStorage(String? roleSlugOrName) {
    final stored = roleSlugOrName?.trim() ?? '';
    if (stored.isEmpty) return 'Technician';
    final fromSlug = AppRole.fromSlug(stored);
    if (fromSlug != null) return fromSlug.label;
    final fromName = AppRole.fromRoleName(stored);
    if (fromName != null) return fromName.label;
    return stored;
  }
}
