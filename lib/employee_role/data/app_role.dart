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

  static bool isTechnician(String? value) =>
      fromSlug(value) == AppRole.technician;

  static bool isOperative(String? value) =>
      fromSlug(value) == AppRole.operative;

  static bool isSales(String? value) => fromSlug(value) == AppRole.sales;

  static bool isManager(String? value) => fromSlug(value) == AppRole.manager;
}
