import 'package:flutter/material.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_colour_type_settings_page.dart';

/// Meta data → Installation type (`GET/POST /api/v1/installation-type/`, `PUT/DELETE …/{id}/`).
class InstallationTypeSettingsPage extends StatelessWidget {
  const InstallationTypeSettingsPage({super.key});

  static const path = '/settings/metadata/installation-type';
  static const name = 'settings-installation-type';

  @override
  Widget build(BuildContext context) {
    return const MetadataColourTypeSettingsPage(
      kind: MetadataColourKind.installationType,
    );
  }
}
