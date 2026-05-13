import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/features/clients/data/client_models.dart';
import 'package:red5/features/clients/data/clients_api_client.dart';
import 'package:red5/features/dashboard/presentation/views/create_project_page.dart';

class ClientDetailPage extends ConsumerStatefulWidget {
  const ClientDetailPage({super.key, required this.clientId});

  static const pathPrefix = '/clients';
  static const name = 'client-detail';

  static String pathFor(String id) => '$pathPrefix/$id';

  final String clientId;

  @override
  ConsumerState<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends ConsumerState<ClientDetailPage> {
  ClientModel? _client;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.clientId.trim();
    if (id.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Invalid client id';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(clientsApiClientProvider);
      final data = await api.fetchClientDetail(id);
      if (!mounted) return;
      setState(() {
        _client = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load client details',
        );
      });
    }
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 10),
      child: Text(
        text,
        style: AppFonts.titleMedium(
          color: AppColors.inkStrong,
        ).copyWith(fontWeight: FontWeight.w700, fontSize: 24),
      ),
    );
  }

  Widget _labelValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppFonts.labelMedium(color: AppColors.muted).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.trim().isEmpty ? '—' : value.trim(),
          style: AppFonts.bodyMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w500, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildContent(ClientModel c) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                c.name,
                style: AppFonts.headlineSmall(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w800, fontSize: 28),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: c.isActive
                    ? const Color(0xFFE9F9EE)
                    : const Color(0xFFF1F1F2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                c.isActive ? 'ACTIVE' : 'IN ACTIVE',
                style:
                    AppFonts.labelMedium(
                      color: c.isActive
                          ? const Color(0xFF137333)
                          : const Color(0xFF66666A),
                    ).copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      fontSize: 10,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          c.email,
          style: AppFonts.bodyMedium(
            color: AppColors.muted,
          ).copyWith(fontSize: 15),
        ),
        const SizedBox(height: 18),
        const Divider(height: 1, color: Color(0xFFE2E2E4)),
        _sectionHeader('Basic Info'),
        _labelValue('Client Name', c.name),
        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFE2E2E4)),
        _sectionHeader('Primary Contact'),
        _labelValue('Contact Person', c.contactPerson),
        const SizedBox(height: 14),
        _labelValue('Email', c.email),
        const SizedBox(height: 14),
        _labelValue('Phone', c.phone),
        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFE2E2E4)),
        _sectionHeader('Address'),
        _labelValue('Street Address', c.addressLine1),
        if (c.addressLine2.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            c.addressLine2.trim(),
            style: AppFonts.bodyMedium(
              color: AppColors.muted,
            ).copyWith(fontSize: 16),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _labelValue('City', c.city)),
            const SizedBox(width: 16),
            Expanded(child: _labelValue('State / Province', c.state)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _labelValue('Postal Code', c.pincode)),
            const SizedBox(width: 16),
            Expanded(child: _labelValue('Country', c.country)),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: () => context.push(
              CreateProjectPage.path,
              extra: <String, dynamic>{
                'clientId': int.tryParse(c.id),
                'clientName': c.name,
              },
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.assignment_add, size: 18),
            label: Text(
              'Create New Project',
              style: AppFonts.titleSmall(
                color: AppColors.white,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E2E4)),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          'Client Details',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: _isLoading
          ? Center(
              child: const AppSkeletonScreenBody(
                scrollable: false,
                toastBlockCount: 4,
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppFonts.bodyMedium(color: AppColors.muted),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : _buildContent(_client!),
    );
  }
}
