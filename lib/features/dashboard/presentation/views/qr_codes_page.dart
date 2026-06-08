import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/utils/debounced_search.dart';
import 'package:red5/features/dashboard/data/qr_code_models.dart';
import 'package:red5/features/dashboard/data/qr_codes_api_client.dart';

class QrCodesPage extends ConsumerStatefulWidget {
  const QrCodesPage({super.key});

  static const path = '/qr-codes';
  static const name = 'qr-codes';

  @override
  ConsumerState<QrCodesPage> createState() => _QrCodesPageState();
}

class _QrCodesPageState extends ConsumerState<QrCodesPage> {
  final TextEditingController _searchController = TextEditingController();
  final _searchDebounce = DebouncedSearch();
  List<QrCodeModel> _items = const [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    unawaited(_loadQrCodes());
  }

  void _onSearchChanged() {
    setState(() {});
    _searchDebounce.schedule(_loadQrCodes);
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadQrCodes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(qrCodesApiClientProvider);
      final items = await api.fetchAllQrCodes(
        search: _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _openGenerateScreen() async {
    final generated = await Navigator.of(context).push<List<QrCodeModel>>(
      MaterialPageRoute<List<QrCodeModel>>(
        builder: (_) => const _GenerateQrCodesPage(),
      ),
    );
    if (generated == null || generated.isEmpty || !mounted) return;
    setState(() {
      final existingIds = _items.map((item) => item.id).toSet();
      final fresh = generated.where((item) => !existingIds.contains(item.id));
      _items = [...fresh, ..._items];
    });
  }

  Future<void> _openDetails(QrCodeModel item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => _QrCodeDetailsPage(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F6F7),
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          'QR Code',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.transparent,
              scrolledUnderElevation: 0,
              titleSpacing: 0,
              title: Text(
                'Project QR Codes',
                style: AppFonts.titleMedium(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              actions: [
                IconButton(
                  onPressed: _openGenerateScreen,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  color: AppColors.inkStrong,
                  tooltip: 'Create QR',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search QR codes...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFFEFEFF1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openGenerateScreen,
        backgroundColor: const Color(0xFF111111),
        child: const Icon(Icons.add, color: AppColors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Failed to load QR codes',
                style: AppFonts.titleSmall(color: AppColors.inkStrong),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppFonts.bodySmall(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadQrCodes,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.trim().isEmpty
              ? 'No QR codes found'
              : 'No QR codes match your search',
          style: AppFonts.bodyMedium(color: AppColors.muted),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadQrCodes,
      color: const Color(0xFF121212),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
        itemCount: _items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _items[index];
          return InkWell(
            onTap: () => _openDetails(item),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  _QrImagePreview(
                    imageUrl: item.qrImageUrl,
                    size: 42,
                    borderRadius: 6,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.qrCodeId,
                          style: AppFonts.titleSmall(
                            color: AppColors.inkStrong,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Job: ${item.assignedJobLabel}',
                          style: AppFonts.bodySmall(color: AppColors.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${item.scanCount} scans  ·  ${_scanMeta(item)}',
                          style: AppFonts.bodySmall(
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusPill(item),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statusPill(QrCodeModel item) {
    final isActive = item.isActiveStatus;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF111111) : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        item.statusLabel,
        style: AppFonts.labelSmall(
          color: isActive ? AppColors.white : AppColors.inkStrong,
        ).copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _QrCodeDetailsPage extends StatelessWidget {
  const _QrCodeDetailsPage({required this.item});

  final QrCodeModel item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F6F7),
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          item.qrCodeId,
          style: AppFonts.titleSmall(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QR Info',
              style: AppFonts.titleMedium(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _openFullScreenQr(context),
              child: _QrImagePreview(
                imageUrl: item.qrImageUrl,
                size: 110,
                borderRadius: 10,
                heroTag: _qrHeroTag(item.id),
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap QR code to view full screen',
              style: AppFonts.bodySmall(color: AppColors.muted),
            ),
            _infoRow('QR ID', item.qrCodeId),
            _infoRow('Status', item.statusLabel),
            const Divider(height: 28),
            Text(
              'Usage Details',
              style: AppFonts.titleSmall(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _infoRow('Assigned job', item.assignedJobLabel),
            _infoRow('Scans', '${item.scanCount}'),
            _infoRow(
              'Last scanned',
              item.lastScannedAt == null
                  ? '--'
                  : _formatDateTime(item.lastScannedAt!),
            ),
            _infoRow('Record ID', '${item.id}'),
            const Divider(height: 28),
            Text(
              'System Metadata',
              style: AppFonts.titleSmall(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _infoRow(
              'Created',
              item.createdAt == null ? '--' : _formatDateTime(item.createdAt!),
            ),
            _infoRow(
              'Last updated',
              item.modifiedAt == null ? '--' : _formatDateTime(item.modifiedAt!),
            ),
            _infoRow('Created by', item.createdByUsername ?? '--'),
            _infoRow('Creator email', item.createdByEmail ?? '--'),
            _infoRow(
              'Modified by',
              item.modifiedByUsername ?? 'Not modified yet',
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppFonts.labelSmall(color: const Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppFonts.bodyMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Future<void> _openFullScreenQr(BuildContext context) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _QrCodeFullScreenViewer(
            item: item,
            heroTag: _qrHeroTag(item.id),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

class _QrCodeFullScreenViewer extends StatelessWidget {
  const _QrCodeFullScreenViewer({
    required this.item,
    required this.heroTag,
  });

  final QrCodeModel item;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final maxSize = MediaQuery.sizeOf(context).width * 0.82;
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.92),
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Hero(
                  tag: heroTag,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: maxSize,
                      height: maxSize,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x40000000),
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: _QrImageBody(
                        imageUrl: item.qrImageUrl,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: AppColors.white),
                  tooltip: 'Close',
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 28,
                child: Text(
                  item.qrCodeId,
                  textAlign: TextAlign.center,
                  style: AppFonts.titleMedium(
                    color: AppColors.white,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenerateQrCodesPage extends ConsumerStatefulWidget {
  const _GenerateQrCodesPage();

  @override
  ConsumerState<_GenerateQrCodesPage> createState() =>
      _GenerateQrCodesPageState();
}

class _GenerateQrCodesPageState extends ConsumerState<_GenerateQrCodesPage> {
  final TextEditingController _countController = TextEditingController(text: '5');
  bool _isGenerating = false;

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final count = int.tryParse(_countController.text.trim());
    if (count == null || count < 1 || count > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a value between 1 and 500')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final api = ref.read(qrCodesApiClientProvider);
      final generated = await api.generateQrCodes(count: count);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            generated.length == 1
                ? '1 QR code generated successfully'
                : '${generated.length} QR codes generated successfully',
          ),
        ),
      );
      Navigator.of(context).pop(generated);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate QR codes: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F6F7),
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          'Generate QR codes',
          style: AppFonts.titleSmall(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Number of QR codes',
              style: AppFonts.titleSmall(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _countController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter a value between 1 and 500.',
              style: AppFonts.bodySmall(color: AppColors.muted),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isGenerating ? null : _generate,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF111111),
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 16),
                label: Text(_isGenerating ? 'Generating...' : 'Generate'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.inkStrong,
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrImagePreview extends StatelessWidget {
  const _QrImagePreview({
    required this.imageUrl,
    required this.size,
    required this.borderRadius,
    this.heroTag,
    this.fit = BoxFit.cover,
  });

  final String? imageUrl;
  final double size;
  final double borderRadius;
  final String? heroTag;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    Widget preview = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: const Color(0xFFF4F4F5),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: _QrImageBody(imageUrl: imageUrl, fit: fit),
    );

    if (heroTag != null) {
      preview = Hero(
        tag: heroTag!,
        child: Material(color: Colors.transparent, child: preview),
      );
    }

    return preview;
  }
}

class _QrImageBody extends StatelessWidget {
  const _QrImageBody({
    required this.imageUrl,
    required this.fit,
  });

  final String? imageUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return const Center(
        child: Icon(Icons.qr_code_2_rounded, color: AppColors.inkStrong),
      );
    }

    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(Icons.qr_code_2_rounded, color: AppColors.inkStrong),
        );
      },
    );
  }
}

String _qrHeroTag(int id) => 'qr-code-image-$id';

String _scanMeta(QrCodeModel item) {
  if (item.lastScannedAt != null) {
    return 'Last: ${_timeAgo(item.lastScannedAt!)}';
  }
  if (item.createdAt != null) {
    return 'Created: ${_timeAgo(item.createdAt!)}';
  }
  return '--';
}

String _timeAgo(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inDays >= 1) {
    return diff.inDays == 1 ? '1 day ago' : '${diff.inDays} days ago';
  }
  if (diff.inHours >= 1) {
    return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
  }
  return 'Just now';
}

String _formatDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  final month = switch (value.month) {
    1 => 'Jan',
    2 => 'Feb',
    3 => 'Mar',
    4 => 'Apr',
    5 => 'May',
    6 => 'Jun',
    7 => 'Jul',
    8 => 'Aug',
    9 => 'Sep',
    10 => 'Oct',
    11 => 'Nov',
    _ => 'Dec',
  };
  final hour =
      value.hour > 12 ? value.hour - 12 : (value.hour == 0 ? 12 : value.hour);
  final amPm = value.hour >= 12 ? 'PM' : 'AM';
  return '$month ${two(value.day)}, ${value.year} · ${two(hour)}:${two(value.minute)} $amPm';
}
