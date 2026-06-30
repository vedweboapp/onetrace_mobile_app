import 'package:flutter/material.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_colour_type_settings_page.dart';

/// Meta data → Project type (`GET/POST /api/v1/project-type/`, `PUT/DELETE …/{id}/`).
class ProjectTypeSettingsPage extends StatelessWidget {
  const ProjectTypeSettingsPage({super.key});

  static const path = '/settings/metadata/project-type';
  static const name = 'settings-project-type';

  @override
  Widget build(BuildContext context) {
    return const MetadataColourTypeSettingsPage(
      kind: MetadataColourKind.projectType,
    );
  }
}
