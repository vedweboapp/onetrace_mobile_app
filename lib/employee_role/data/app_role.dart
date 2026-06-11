enum AppRole {
  technician,
  operative,
  sales,
  manager;

  String get slug {
    switch (this) {
      case AppRole.technician:
        return 'technician';
      case AppRole.operative:
        return 'operative';
      case AppRole.sales:
        return 'sales';
      case AppRole.manager:
        return 'manager';
    }
  }

  String get label {
    switch (this) {
      case AppRole.technician:
        return 'Technician';
      case AppRole.operative:
        return 'Operative';
      case AppRole.sales:
        return 'Sales';
      case AppRole.manager:
        return 'Manager';
    }
  }

  String get description {
    switch (this) {
      case AppRole.technician:
        return 'Field jobs, materials, forms, and QR tasks.';
      case AppRole.operative:
        return 'Daily operation tasks and site progress.';
      case AppRole.sales:
        return 'Leads, quotations, clients, and follow-ups.';
      case AppRole.manager:
        return 'Team overview, approvals, and reporting.';
    }
  }

  static AppRole? fromSlug(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    for (final role in AppRole.values) {
      if (role.slug == normalized) return role;
    }
    return null;
  }

  /// Maps API `role_detail.role_name` (or similar) to the closest [AppRole] for UI copy.
  static AppRole? fromRoleName(String? roleName) {
    final normalized = roleName?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return null;
    if (normalized.contains('technician')) return AppRole.technician;
    if (normalized.contains('manager')) return AppRole.manager;
    if (normalized.contains('site')) return AppRole.technician;
    if (normalized.contains('operative')) return AppRole.operative;
    if (normalized.contains('sales')) return AppRole.sales;
    return fromSlug(normalized);
  }
}
