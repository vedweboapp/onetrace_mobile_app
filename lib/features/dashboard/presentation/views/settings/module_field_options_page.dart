import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/providers/local_storage_provider.dart';
import 'package:red5/core/storage/local_storage_keys.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';

class ModuleFieldOptionsPage extends ConsumerStatefulWidget {
  const ModuleFieldOptionsPage({super.key});

  static const path = '/settings/metadata/options';
  static const name = 'settings-metadata-options';

  @override
  ConsumerState<ModuleFieldOptionsPage> createState() =>
      _ModuleFieldOptionsPageState();
}

class _ModuleFieldOptionsPageState
    extends ConsumerState<ModuleFieldOptionsPage> {
  late Map<String, bool> _modulesEnabled;
  late Map<String, Map<String, bool>> _fieldsEnabled;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final storage = ref.read(localStorageProvider);
    _modulesEnabled = _readBoolMap(
      storage.getString(LocalStorageKeys.adminModulesEnabled),
    )..addAll(_defaultModulesEnabled);

    _fieldsEnabled = _readNestedBoolMap(
      storage.getString(LocalStorageKeys.adminFieldsEnabled),
    );
    for (final module in _defaultFieldsEnabled.entries) {
      _fieldsEnabled.putIfAbsent(module.key, () => <String, bool>{});
      _fieldsEnabled[module.key]!.addAll(module.value);
    }

    setState(() => _loaded = true);
  }

  Future<void> _persist() async {
    final storage = ref.read(localStorageProvider);
    await storage.setString(
      LocalStorageKeys.adminModulesEnabled,
      jsonEncode(_modulesEnabled),
    );
    await storage.setString(
      LocalStorageKeys.adminFieldsEnabled,
      jsonEncode(_fieldsEnabled),
    );
  }

  Future<void> _toggleModule(String module, bool value) async {
    setState(() => _modulesEnabled[module] = value);
    await _persist();
  }

  Future<void> _toggleField(String module, String fieldKey, bool value) async {
    setState(() {
      _fieldsEnabled.putIfAbsent(module, () => <String, bool>{});
      _fieldsEnabled[module]![fieldKey] = value;
    });
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: AppColors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          surfaceTintColor: AppColors.white,
          scrolledUnderElevation: 0,
          elevation: 0,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
          ),
          title: Text(
            'Meta data',
            style: AppFonts.titleMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(49),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                TabBar(
                  labelColor: AppColors.inkStrong,
                  unselectedLabelColor: AppColors.muted,
                  indicatorColor: AppColors.inkStrong,
                  indicatorWeight: 2,
                  labelStyle: AppFonts.labelMedium(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w800),
                  unselectedLabelStyle: AppFonts.labelMedium(
                    color: AppColors.muted,
                  ).copyWith(fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Modules'),
                    Tab(text: 'Fields'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _ModulesTab(
              modules: _allModules,
              enabled: _modulesEnabled,
              onChanged: _toggleModule,
            ),
            _FieldsTab(
              modules: _allModules,
              modulesEnabled: _modulesEnabled,
              enabled: _fieldsEnabled,
              onChanged: _toggleField,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModulesTab extends StatelessWidget {
  const _ModulesTab({
    required this.modules,
    required this.enabled,
    required this.onChanged,
  });

  final List<_AdminModule> modules;
  final Map<String, bool> enabled;
  final Future<void> Function(String module, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          'ENABLE MODULES',
          style: AppFonts.labelMedium(
            color: const Color(0xFF9CA3AF),
          ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
        ),
        const SizedBox(height: 12),
        for (final m in modules) ...[
          _SwitchTile(
            title: m.label,
            subtitle: m.subtitle,
            value: enabled[m.slug] ?? true,
            onChanged: (v) => onChanged(m.slug, v),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _FieldsTab extends StatelessWidget {
  const _FieldsTab({
    required this.modules,
    required this.modulesEnabled,
    required this.enabled,
    required this.onChanged,
  });

  final List<_AdminModule> modules;
  final Map<String, bool> modulesEnabled;
  final Map<String, Map<String, bool>> enabled;
  final Future<void> Function(String module, String fieldKey, bool value)
  onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          'FIELDS',
          style: AppFonts.labelMedium(
            color: const Color(0xFF9CA3AF),
          ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
        ),
        const SizedBox(height: 12),
        for (final m in modules) ...[
          _ModuleFieldsCard(
            module: m,
            moduleEnabled: modulesEnabled[m.slug] ?? true,
            enabled: enabled[m.slug] ?? const {},
            onChanged: (fieldKey, v) => onChanged(m.slug, fieldKey, v),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ModuleFieldsCard extends StatelessWidget {
  const _ModuleFieldsCard({
    required this.module,
    required this.moduleEnabled,
    required this.enabled,
    required this.onChanged,
  });

  final _AdminModule module;
  final bool moduleEnabled;
  final Map<String, bool> enabled;
  final void Function(String fieldKey, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    final fields = _defaultFieldsEnabled[module.slug] ?? const <String, bool>{};
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  module.label,
                  style: AppFonts.bodyLarge(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: moduleEnabled
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  moduleEnabled ? 'Enabled' : 'Disabled',
                  style: AppFonts.labelSmall(
                    color: moduleEnabled
                        ? AppColors.inkStrong
                        : AppColors.muted,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final entry in fields.entries) ...[
            _CompactSwitchRow(
              title: _fieldLabel(entry.key),
              value: enabled[entry.key] ?? entry.value,
              disabled: !moduleEnabled,
              onChanged: (v) => onChanged(entry.key, v),
            ),
            if (entry.key != fields.keys.last) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.bodyLarge(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppFonts.bodySmall(
                    color: AppColors.muted,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.inkStrong,
          ),
        ],
      ),
    );
  }
}

class _CompactSwitchRow extends StatelessWidget {
  const _CompactSwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.disabled,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final effectiveValue = disabled ? false : value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: disabled ? const Color(0xFFF9FAFB) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppFonts.bodyMedium(
                color: disabled ? AppColors.muted : AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Switch.adaptive(
            value: effectiveValue,
            onChanged: disabled ? null : onChanged,
            activeThumbColor: AppColors.inkStrong,
          ),
        ],
      ),
    );
  }
}

final class _AdminModule {
  const _AdminModule({
    required this.slug,
    required this.label,
    required this.subtitle,
  });

  final String slug;
  final String label;
  final String subtitle;
}

const _allModules = <_AdminModule>[
  _AdminModule(
    slug: 'projects',
    label: 'Projects',
    subtitle: 'Project tracking and job lists',
  ),
  _AdminModule(
    slug: 'quotations',
    label: 'Quotations',
    subtitle: 'Quotes, tags, and approvals',
  ),
  _AdminModule(
    slug: 'clients',
    label: 'Clients',
    subtitle: 'Customer profiles and billing',
  ),
  _AdminModule(
    slug: 'sites',
    label: 'Sites',
    subtitle: 'Site addresses and contacts',
  ),
  _AdminModule(
    slug: 'contacts',
    label: 'Contacts',
    subtitle: 'People and roles',
  ),
  _AdminModule(
    slug: 'groups',
    label: 'Groups',
    subtitle: 'Teams and assignments',
  ),
  _AdminModule(
    slug: 'items',
    label: 'Items',
    subtitle: 'Products and materials',
  ),
  _AdminModule(
    slug: 'composite_items',
    label: 'Composite Items',
    subtitle: 'Bundles and templates',
  ),
];

const _defaultModulesEnabled = <String, bool>{
  'projects': true,
  'quotations': true,
  'clients': true,
  'sites': true,
  'contacts': true,
  'groups': true,
  'items': true,
  'composite_items': true,
};

const _defaultFieldsEnabled = <String, Map<String, bool>>{
  'sites': {
    'site_name': true,
    'client_name': true,
    'street_address': true,
    'city': true,
    'state': true,
    'postal_code': true,
    'country': true,
  },
  'projects': {
    'project_name': true,
    'client': true,
    'site': true,
    'status': true,
    'due_date': true,
  },
  'clients': {
    'client_name': true,
    'phone': true,
    'email': true,
    'address': true,
  },
};

Map<String, bool> _readBoolMap(String? raw) {
  if (raw == null || raw.trim().isEmpty) return <String, bool>{};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return <String, bool>{};
    return decoded.map((k, v) => MapEntry(k.toString(), v == true));
  } catch (_) {
    return <String, bool>{};
  }
}

Map<String, Map<String, bool>> _readNestedBoolMap(String? raw) {
  if (raw == null || raw.trim().isEmpty) return <String, Map<String, bool>>{};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return <String, Map<String, bool>>{};
    final out = <String, Map<String, bool>>{};
    for (final entry in decoded.entries) {
      final key = entry.key.toString();
      final val = entry.value;
      if (val is Map) {
        out[key] = val.map((k, v) => MapEntry(k.toString(), v == true));
      }
    }
    return out;
  } catch (_) {
    return <String, Map<String, bool>>{};
  }
}

String _fieldLabel(String key) {
  return switch (key) {
    'site_name' => 'Site name',
    'client_name' => 'Client name',
    'street_address' => 'Street address',
    'city' => 'City',
    'state' => 'State / province',
    'postal_code' => 'Postal code',
    'country' => 'Country',
    'project_name' => 'Project name',
    'client' => 'Client',
    'site' => 'Site',
    'status' => 'Status',
    'due_date' => 'Due date',
    'phone' => 'Phone',
    'email' => 'Email',
    'address' => 'Address',
    _ => key.replaceAll('_', ' '),
  };
}
