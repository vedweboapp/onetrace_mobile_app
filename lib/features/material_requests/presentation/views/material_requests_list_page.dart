import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/features/material_requests/presentation/views/create_material_request_page.dart';
import 'package:red5/features/material_requests/presentation/widgets/material_requests_list_body.dart';

/// Material requests list (UI preview until API is available).
class MaterialRequestsListPage extends StatelessWidget {
  const MaterialRequestsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F7),
      body: const MaterialRequestsListBody(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        heroTag: 'material_requests_create_fab',
        onPressed: () => context.push(CreateMaterialRequestPage.path),
        backgroundColor: const Color(0xFF121212),
        foregroundColor: AppColors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
