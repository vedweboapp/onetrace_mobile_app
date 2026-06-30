import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/places/google_places_service.dart';
import 'package:red5/core/places/place_address.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';

/// Address line 1 field with Google Places autocomplete suggestions.
///
/// When the user picks a suggestion, related address fields are filled via
/// [onPlaceSelected] and/or [applyPlaceAddress] helpers.
class PlacesAutocompleteField extends ConsumerStatefulWidget {
  const PlacesAutocompleteField({
    required this.controller,
    required this.hintText,
    super.key,
    this.validator,
    this.enabled = true,
    this.onPlaceSelected,
    this.onChanged,
    this.borderRadius = 10,
    this.textStyle,
    this.hintStyle,
    this.contentPadding,
    this.keyboardType,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String hintText;
  final String? Function(String?)? validator;
  final bool enabled;
  final ValueChanged<PlaceAddress>? onPlaceSelected;
  final ValueChanged<String>? onChanged;
  final double borderRadius;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final EdgeInsetsGeometry? contentPadding;
  final TextInputType? keyboardType;
  final bool readOnly;

  @override
  ConsumerState<PlacesAutocompleteField> createState() =>
      _PlacesAutocompleteFieldState();
}

class _PlacesAutocompleteFieldState
    extends ConsumerState<PlacesAutocompleteField> {
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  List<PlacePrediction> _predictions = const [];
  bool _loading = false;
  bool _suppressSearch = false;
  Timer? _debounce;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      Future<void>.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        _removeOverlay();
      });
      return;
    }
    _scheduleSearch(widget.controller.text);
  }

  void _onTextChanged() {
    if (_suppressSearch) return;
    widget.onChanged?.call(widget.controller.text);
    _scheduleSearch(widget.controller.text);
  }

  void _scheduleSearch(String raw) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      unawaited(_runSearch(raw));
    });
  }

  Future<void> _runSearch(String raw) async {
    final query = raw.trim();
    if (query.length < 2) {
      setState(() {
        _predictions = const [];
        _loading = false;
      });
      _removeOverlay();
      return;
    }
    if (query == _lastQuery && _predictions.isNotEmpty) {
      _showOverlay();
      return;
    }

    setState(() => _loading = true);
    try {
      final results =
          await ref.read(googlePlacesServiceProvider).fetchPredictions(query);
      if (!mounted || widget.controller.text.trim() != query) return;
      setState(() {
        _predictions = results;
        _loading = false;
        _lastQuery = query;
      });
      if (_focusNode.hasFocus && results.isNotEmpty) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _predictions = const [];
        _loading = false;
      });
      _removeOverlay();
    }
  }

  Future<void> _selectPrediction(PlacePrediction prediction) async {
    _removeOverlay();
    setState(() {
      _predictions = const [];
      _loading = true;
    });

    try {
      final place = await ref
          .read(googlePlacesServiceProvider)
          .fetchPlaceAddress(prediction.placeId);
      if (!mounted) return;

      _suppressSearch = true;
      final line1 = place.addressLine1.trim().isNotEmpty
          ? place.addressLine1
          : prediction.mainText;
      widget.controller.text = line1;
      _suppressSearch = false;

      widget.onPlaceSelected?.call(
        PlaceAddress(
          addressLine1: line1,
          addressLine2: place.addressLine2,
          city: place.city,
          state: place.state,
          country: place.country,
          postalCode: place.postalCode,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _suppressSearch = true;
      widget.controller.text = prediction.description;
      _suppressSearch = false;
      widget.onPlaceSelected?.call(
        PlaceAddress(addressLine1: prediction.description),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showOverlay() {
    _removeOverlay();
    if (_predictions.isEmpty || !widget.enabled) return;

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    final width = renderBox?.size.width;
    if (width == null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 52),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            color: AppColors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _predictions.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                itemBuilder: (context, index) {
                  final item = _predictions[index];
                  return InkWell(
                    onTap: () => _selectPrediction(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.mainText,
                            style: AppFonts.bodyMedium(
                              color: AppColors.inkStrong,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (item.secondaryText.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.secondaryText,
                              style: AppFonts.bodySmall(
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: AppTextField(
        controller: widget.controller,
        hintText: widget.hintText,
        validator: widget.validator,
        enabled: widget.enabled,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        borderRadius: widget.borderRadius,
        textStyle: widget.textStyle,
        hintStyle: widget.hintStyle,
        contentPadding: widget.contentPadding,
        keyboardType: widget.keyboardType ?? TextInputType.streetAddress,
        readOnly: widget.readOnly,
        suffixIcon: _loading
            ? const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: AppColors.muted,
                ),
              ),
      ),
    );
  }
}
