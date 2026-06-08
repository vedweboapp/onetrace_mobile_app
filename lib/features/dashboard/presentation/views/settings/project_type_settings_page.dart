import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/top_snackbar.dart';

/// Meta data → Project type options (local mock until API is wired).
class ProjectTypeSettingsPage extends StatefulWidget {
  const ProjectTypeSettingsPage({super.key});

  static const path = '/settings/metadata/project-type';
  static const name = 'settings-project-type';

  @override
  State<ProjectTypeSettingsPage> createState() =>
      _ProjectTypeSettingsPageState();
}

class _ProjectTypeSettingsPageState extends State<ProjectTypeSettingsPage> {
  final List<String> _items = const [
    'Commercial',
    'Residential',
    'Industrial',
    'Infrastructure',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          'Project Type',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.showTopSnackBar(
            const SnackBar(content: Text('Add project type — API coming soon')),
          );
        },
        backgroundColor: AppColors.inkStrong,
        foregroundColor: AppColors.white,
        child: const Icon(Icons.add, size: 28),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
              itemBuilder: (context, index) {
                final name = _items[index];
                return ListTile(
                  title: Text(
                    name,
                    style: AppFonts.bodyLarge(
                      color: AppColors.inkStrong,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_horiz_rounded),
                    onPressed: () {
                      context.showTopSnackBar(
                        SnackBar(
                          content: Text('Edit "$name" — API coming soon'),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
