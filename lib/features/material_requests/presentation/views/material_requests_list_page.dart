import 'package:flutter/material.dart';
import 'package:red5/features/material_requests/presentation/widgets/material_requests_list_body.dart';

/// Material requests list (UI preview until API is available).
class MaterialRequestsListPage extends StatelessWidget {
  const MaterialRequestsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F7),
      body: const MaterialRequestsListBody(),
    );
  }
}
