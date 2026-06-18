import 'dart:convert';
import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/utils/phone_number_utils.dart';
import 'package:red5/core/widgets/app_date_picker_dialog.dart';
import 'package:red5/core/widgets/app_phone_text_field.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/employee_role/forms/data/cached_technician_form.dart';
import 'package:red5/employee_role/forms/data/form_metadata_models.dart';
import 'package:red5/employee_role/forms/presentation/widgets/form_image_source_sheet.dart';
import 'package:red5/employee_role/forms/presentation/widgets/form_metadata_layout_widgets.dart';
import 'package:red5/core/utils/qr_code_utils.dart';
import 'package:red5/employee_role/forms/presentation/widgets/form_qr_input_sheet.dart';
import 'package:red5/employee_role/forms/presentation/widgets/form_qr_scanner_page.dart';
import 'package:red5/employee_role/forms/presentation/widgets/form_signature_field.dart';
import 'package:red5/employee_role/jobs/data/job_form_models.dart';

/// Renders sections and fields from form metadata for technicians to fill in.
class DynamicFormView extends StatefulWidget {
  const DynamicFormView({
    super.key,
    required this.bundle,
    this.onChanged,
    this.onQrCodeScanned,
    this.onSignatureDrawingChanged,
  });

  final TechnicianFormBundle bundle;
  final VoidCallback? onChanged;

  /// Called after a QR value is captured; use to register scan + fetch details.
  final Future<void> Function(String qrCode)? onQrCodeScanned;

  /// Notifies when the user starts or stops drawing on a signature pad.
  final ValueChanged<bool>? onSignatureDrawingChanged;

  @override
  State<DynamicFormView> createState() => DynamicFormViewState();
}

class DynamicFormViewState extends State<DynamicFormView> {
  final _formKey = GlobalKey<FormState>();
  final _textControllers = <String, TextEditingController>{};
  final _dateValues = <String, DateTime?>{};
  final _choiceValues = <String, String?>{};
  final _boolValues = <String, bool>{};
  final _fileValues = <String, _PickedFileValue>{};
  final _signatureStrokes = <String, List<List<Offset>>>{};
  final _phoneCountries = <String, CountryCode>{};

  late List<FormMetadataSection> _sections;
  static final _dateFormat = DateFormat('MM/dd/yyyy');

  @override
  void initState() {
    super.initState();
    _sections = filterOperativeFormSections(
      parseFormMetadataSections(widget.bundle.metadata),
    );
    _initFieldState();
  }

  @override
  void didUpdateWidget(covariant DynamicFormView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bundle.contentHash != widget.bundle.contentHash) {
      _disposeControllers();
      _sections = filterOperativeFormSections(
        parseFormMetadataSections(widget.bundle.metadata),
      );
      _dateValues.clear();
      _choiceValues.clear();
      _boolValues.clear();
      _fileValues.clear();
      _signatureStrokes.clear();
      _phoneCountries.clear();
      _initFieldState();
    }
  }

  void _initFieldState() {
    for (final section in _sections) {
      for (final field in section.fields) {
        final key = field.apiName;
        switch (_fieldKind(field)) {
          case _FieldKind.text:
          case _FieldKind.email:
          case _FieldKind.number:
          case _FieldKind.qr:
          case _FieldKind.unsupported:
            _textControllers.putIfAbsent(
              key,
              () => TextEditingController(),
            );
          case _FieldKind.phone:
            _textControllers.putIfAbsent(key, () => TextEditingController());
            _phoneCountries.putIfAbsent(
              key,
              () => PhoneNumberUtils.defaultCountry,
            );
          case _FieldKind.multiLine:
            _textControllers.putIfAbsent(
              key,
              () => TextEditingController(),
            );
          case _FieldKind.date:
            _dateValues[key] = null;
          case _FieldKind.radio:
          case _FieldKind.dropdown:
            _choiceValues[key] = null;
          case _FieldKind.checkbox:
            _boolValues[key] = false;
          case _FieldKind.image:
            break;
          case _FieldKind.signature:
            _signatureStrokes[key] = const [];
        }
      }
    }
  }

  void _disposeControllers() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    _textControllers.clear();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _notifyChanged() {
    widget.onChanged?.call();
    setState(() {});
  }

  /// Validates all visible fields and returns `true` when valid.
  bool validate() => _formKey.currentState?.validate() ?? false;

  /// Current field values keyed by [FormMetadataField.apiName].
  Map<String, dynamic> collectValues() {
    final values = <String, dynamic>{};
    for (final section in _sections) {
      for (final field in section.fields) {
        final key = field.apiName;
        switch (_fieldKind(field)) {
          case _FieldKind.text:
          case _FieldKind.email:
          case _FieldKind.number:
          case _FieldKind.qr:
          case _FieldKind.multiLine:
          case _FieldKind.unsupported:
            values[key] = _textControllers[key]?.text.trim() ?? '';
          case _FieldKind.phone:
            final country =
                _phoneCountries[key] ?? PhoneNumberUtils.defaultCountry;
            values[key] = PhoneNumberUtils.formatFull(
              country,
              _textControllers[key]?.text ?? '',
            );
          case _FieldKind.date:
            final date = _dateValues[key];
            values[key] = date?.toIso8601String();
          case _FieldKind.radio:
          case _FieldKind.dropdown:
            values[key] = _choiceValues[key];
          case _FieldKind.checkbox:
            values[key] = _boolValues[key] ?? false;
          case _FieldKind.image:
            final file = _fileValues[key];
            values[key] = file == null
                ? null
                : <String, dynamic>{
                    'name': file.name,
                    'path': file.path,
                    'size_bytes': file.sizeBytes,
                  };
          case _FieldKind.signature:
            values[key] = signatureValueFromStrokes(
              _signatureStrokes[key] ?? const [],
            );
        }
      }
    }
    return values;
  }

  /// Field values formatted for `POST /jobs/{id}/submit-form/`.
  List<JobFormFieldValue> collectApiValues() {
    final rows = <JobFormFieldValue>[];
    final byApiName = collectValues();
    for (final section in _sections) {
      for (final field in section.fields) {
        if (field.id <= 0) continue;
        final raw = byApiName[field.apiName];
        final value = _serializeFieldForApi(field, raw);
        if (value.trim().isEmpty) continue;
        rows.add(
          JobFormFieldValue(
            fieldId: field.id,
            value: value,
          ),
        );
      }
    }
    return rows;
  }

  /// Restores saved or submitted values keyed by metadata field id.
  void applyFieldValues(List<JobFormFieldValue> values) {
    if (values.isEmpty) return;

    final byFieldId = <int, String>{
      for (final row in values)
        if (row.fieldId > 0) row.fieldId: row.value,
    };

    for (final section in _sections) {
      for (final field in section.fields) {
        final raw = byFieldId[field.id];
        if (raw == null) continue;
        _applyValue(field, raw);
      }
    }
    if (mounted) setState(() {});
  }

  void _applyValue(FormMetadataField field, String raw) {
    final key = field.apiName;
    switch (_fieldKind(field)) {
      case _FieldKind.text:
      case _FieldKind.email:
      case _FieldKind.number:
      case _FieldKind.qr:
      case _FieldKind.multiLine:
      case _FieldKind.unsupported:
        _textControllers[key]?.text = raw;
      case _FieldKind.phone:
        final parsed = PhoneNumberUtils.parse(raw);
        _phoneCountries[key] = parsed.country;
        _textControllers[key]?.text = parsed.nationalDigits;
      case _FieldKind.date:
        _dateValues[key] = DateTime.tryParse(raw);
      case _FieldKind.radio:
      case _FieldKind.dropdown:
        _choiceValues[key] = raw.isEmpty ? null : raw;
      case _FieldKind.checkbox:
        final normalized = raw.trim().toLowerCase();
        _boolValues[key] = normalized == 'true' || normalized == '1';
      case _FieldKind.image:
        break;
      case _FieldKind.signature:
        _signatureStrokes[key] = strokesFromSignatureValue(raw);
    }
  }

  static String _serializeFieldForApi(FormMetadataField field, dynamic value) {
    final serialized = _serializeForApi(value);
    if (_fieldKind(field) == _FieldKind.qr && serialized.trim().isNotEmpty) {
      return QrCodeUtils.normalizeScannedValue(serialized);
    }
    return serialized;
  }

  static String _serializeForApi(dynamic value) {
    if (value == null) return '';
    if (value is bool) return value ? 'true' : 'false';
    if (value is Map || value is List) {
      return jsonEncode(value);
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_sections.isEmpty) {
      return _EmptyMetadataState(formName: widget.bundle.summary.name);
    }

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.bundle.summary.name,
            style: AppFonts.headlineSmall(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w900, fontSize: 22),
          ),
          if (widget.bundle.summary.description?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 6),
            Text(
              widget.bundle.summary.description!.trim(),
              style: AppFonts.bodyMedium(color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 20),
          for (final section in _sections) ...[
            FormSectionPanel(
              section: section,
              fieldBuilder: _wrapField,
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _wrapField(FormMetadataField field) {
    final type = _fieldKind(field);
    final hideLabel = type == _FieldKind.checkbox;
    return FormFieldShell(
      label: field.label,
      required: field.isRequired,
      helpText: field.helpText,
      hideLabel: hideLabel,
      child: _buildField(field),
    );
  }

  Widget _buildField(FormMetadataField field) {
    final type = _fieldKind(field);
    return switch (type) {
      _FieldKind.multiLine => _multiLineField(field),
      _FieldKind.email => _textField(
          field,
          keyboardType: TextInputType.emailAddress,
          emailValidation: true,
        ),
      _FieldKind.number => _numberField(field),
      _FieldKind.phone => _phoneField(field),
      _FieldKind.date => _dateField(field),
      _FieldKind.radio => _radioField(field),
      _FieldKind.dropdown => _dropdownField(field),
      _FieldKind.checkbox => _checkboxField(field),
      _FieldKind.image => _imageField(field),
      _FieldKind.qr => _qrField(field),
      _FieldKind.signature => _signatureField(field),
      _FieldKind.unsupported => _unsupportedField(field),
      _FieldKind.text => _textField(field),
    };
  }

  Future<void> _scanQrIntoField(FormMetadataField field) async {
    if (field.isReadonly) return;
    final code = await openFormQrScanner(context);
    final value = code?.trim();
    if (value == null || value.isEmpty || !mounted) return;
    await _applyScannedQrValue(field, value);
  }

  Future<void> _applyScannedQrValue(
    FormMetadataField field,
    String value,
  ) async {
    final controller = _textControllers[field.apiName];
    if (controller == null) return;

    final qrCode = QrCodeUtils.normalizeScannedValue(value);
    if (qrCode.isEmpty) return;

    if (widget.onQrCodeScanned != null) {
      await widget.onQrCodeScanned!(qrCode);
    }

    if (!mounted) return;
    setState(() => controller.text = qrCode);
    _notifyChanged();
    if (widget.onQrCodeScanned == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR code scanned successfully.')),
      );
    }
  }

  Future<void> _openQrInputOptions(FormMetadataField field) async {
    if (field.isReadonly) return;
    final choice = await showFormQrInputSheet(
      context,
      title: field.label,
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case FormQrInputSource.scan:
        await _scanQrIntoField(field);
      case FormQrInputSource.manual:
        break;
    }
  }

  Widget _qrField(FormMetadataField field) {
    final controller = _textControllers[field.apiName]!;
    final hasValue = controller.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: controller,
          hintText: field.placeholder ?? 'Scan or enter QR code',
          readOnly: field.isReadonly,
          enabled: !field.isReadonly,
          borderRadius: 12,
          onChanged: (_) => _notifyChanged(),
          validator: (value) => _textValidator(field, value),
          suffixIcon: field.isReadonly
              ? null
              : IconButton(
                  tooltip: 'Scan QR code',
                  onPressed: () => _scanQrIntoField(field),
                  icon: const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 22,
                    color: AppColors.inkStrong,
                  ),
                ),
        ),
        if (!field.isReadonly) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _openQrInputOptions(field),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
            label: Text(hasValue ? 'Scan again' : 'Scan QR code'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.inkStrong,
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: AppColors.borderLight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _hasSignature(String apiName) {
    final strokes = _signatureStrokes[apiName] ?? const [];
    return strokes.any((stroke) => stroke.length > 1);
  }

  Widget _signatureField(FormMetadataField field) {
    final strokes = _signatureStrokes[field.apiName] ?? const [];
    return FormField<bool>(
      initialValue: _hasSignature(field.apiName),
      validator: (_) {
        if (field.isRequired && !_hasSignature(field.apiName)) {
          return '${field.label} is required';
        }
        return null;
      },
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormDigitalSignaturePad(
              strokes: strokes,
              readOnly: field.isReadonly,
              onDrawingChanged: widget.onSignatureDrawingChanged,
              onChanged: (updated) {
                setState(() {
                  _signatureStrokes[field.apiName] = updated;
                  state.didChange(_hasSignature(field.apiName));
                });
                widget.onChanged?.call();
              },
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  state.errorText!,
                  style: AppFonts.bodySmall(color: AppColors.error),
                ),
              ),
          ],
        );
      },
    );
  }

  String? _requiredValidator(FormMetadataField field, String? value) {
    if (!field.isRequired) return null;
    if (value == null || value.trim().isEmpty) {
      return '${field.label} is required';
    }
    return null;
  }

  String? _textValidator(FormMetadataField field, String? value) {
    final requiredError = _requiredValidator(field, value);
    if (requiredError != null) return requiredError;
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;

    if (field.minLength != null && text.length < field.minLength!) {
      return 'Minimum ${field.minLength} characters';
    }
    if (field.maxLength != null && text.length > field.maxLength!) {
      return 'Maximum ${field.maxLength} characters';
    }
    return null;
  }

  bool _fieldAllowsDecimal(String fieldType) {
    switch (fieldType) {
      case 'decimal':
      case 'currency':
      case 'amount':
        return true;
      default:
        return false;
    }
  }

  Widget _phoneField(FormMetadataField field) {
    final controller = _textControllers[field.apiName]!;
    final country =
        _phoneCountries[field.apiName] ?? PhoneNumberUtils.defaultCountry;

    return AppPhoneTextField(
      controller: controller,
      hintText: field.placeholder ?? 'Phone number',
      enabled: !field.isReadonly,
      borderRadius: 12,
      initialCountry: country,
      showCountryPicker: !field.isReadonly,
      onCountryChanged: (selected) {
        _phoneCountries[field.apiName] = selected;
        _notifyChanged();
      },
      onChanged: (_) => _notifyChanged(),
      validator: (value) {
        if (!field.isRequired && (value == null || value.trim().isEmpty)) {
          return null;
        }
        final phoneError = PhoneNumberUtils.validateNational(
          national: value,
          emptyMessage: '${field.label} is required',
          invalidMessage: 'Enter a valid phone number',
        );
        if (phoneError != null) return phoneError;
        return _textValidator(field, value);
      },
    );
  }

  Widget _numberField(FormMetadataField field) {
    final controller = _textControllers[field.apiName]!;
    final allowDecimal = _fieldAllowsDecimal(field.fieldType);

    return AppTextField(
      controller: controller,
      hintText: field.placeholder ?? field.label,
      readOnly: field.isReadonly,
      enabled: !field.isReadonly,
      keyboardType: allowDecimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      inputFormatters: allowDecimal
          ? [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ]
          : [FilteringTextInputFormatter.digitsOnly],
      borderRadius: 12,
      onChanged: (_) => _notifyChanged(),
      validator: (value) =>
          _numericValidator(field, value, allowDecimal: allowDecimal),
    );
  }

  String? _numericValidator(
    FormMetadataField field,
    String? value, {
    required bool allowDecimal,
  }) {
    final requiredError = _requiredValidator(field, value);
    if (requiredError != null) return requiredError;
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;

    if (allowDecimal) {
      if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(text)) {
        return 'Enter a valid number';
      }
    } else if (!RegExp(r'^\d+$').hasMatch(text)) {
      return 'Enter numbers only';
    }

    if (field.minLength != null && text.length < field.minLength!) {
      return 'Minimum ${field.minLength} characters';
    }
    if (field.maxLength != null && text.length > field.maxLength!) {
      return 'Maximum ${field.maxLength} characters';
    }
    return null;
  }

  Widget _textField(
    FormMetadataField field, {
    TextInputType? keyboardType,
    bool emailValidation = false,
  }) {
    final controller = _textControllers[field.apiName]!;
    return AppTextField(
      controller: controller,
      hintText: field.placeholder ?? field.label,
      readOnly: field.isReadonly,
      enabled: !field.isReadonly,
      keyboardType: keyboardType,
      borderRadius: 12,
      onChanged: (_) => _notifyChanged(),
      validator: (value) {
        final base = _textValidator(field, value);
        if (base != null) return base;
        if (emailValidation && (value?.trim().isNotEmpty ?? false)) {
          final email = value!.trim();
          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
            return 'Enter a valid email';
          }
        }
        return null;
      },
    );
  }

  Widget _multiLineField(FormMetadataField field) {
    final controller = _textControllers[field.apiName]!;
    return AppTextField(
      controller: controller,
      hintText: field.placeholder ?? 'Enter details...',
      readOnly: field.isReadonly,
      enabled: !field.isReadonly,
      minLines: field.multiLineRows,
      maxLines: field.multiLineRows + 2,
      borderRadius: 12,
      onChanged: (_) => _notifyChanged(),
      validator: (value) => _textValidator(field, value),
    );
  }

  Widget _dateField(FormMetadataField field) {
    final selected = _dateValues[field.apiName];
    final display = selected == null ? '' : _dateFormat.format(selected);
    return FormField<DateTime>(
      initialValue: selected,
      validator: (_) {
        if (field.isRequired && _dateValues[field.apiName] == null) {
          return '${field.label} is required';
        }
        return null;
      },
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: field.isReadonly
                  ? null
                  : () async {
                      final picked = await showAppDatePickerDialog(
                        context,
                        initialDate: selected ?? DateTime.now(),
                        helpText: field.label,
                      );
                      if (picked == null) return;
                      setState(() {
                        _dateValues[field.apiName] = picked;
                        state.didChange(picked);
                      });
                      _notifyChanged();
                    },
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: state.hasError
                        ? AppColors.error
                        : AppColors.textFieldBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        display.isEmpty ? 'mm/dd/yyyy' : display,
                        style: AppFonts.bodyMedium(
                          color: display.isEmpty
                              ? AppColors.textFieldHint
                              : AppColors.inkStrong,
                        ).copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Icon(
                      Icons.calendar_month_outlined,
                      size: 20,
                      color: AppColors.inkStrong,
                    ),
                  ],
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  state.errorText!,
                  style: AppFonts.bodySmall(color: AppColors.error),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _radioField(FormMetadataField field) {
    final selected = _choiceValues[field.apiName];
    return FormField<String>(
      initialValue: selected,
      validator: (_) {
        if (field.isRequired && (_choiceValues[field.apiName] == null)) {
          return '${field.label} is required';
        }
        return null;
      },
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...field.options.map((option) {
              return RadioListTile<String>(
                value: option,
                groupValue: selected,
                onChanged: field.isReadonly
                    ? null
                    : (value) {
                        setState(() {
                          _choiceValues[field.apiName] = value;
                          state.didChange(value);
                        });
                        _notifyChanged();
                      },
                title: Text(
                  option,
                  style: AppFonts.bodyMedium(color: AppColors.inkStrong),
                ),
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: AppColors.inkStrong,
              );
            }),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  state.errorText!,
                  style: AppFonts.bodySmall(color: AppColors.error),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _dropdownField(FormMetadataField field) {
    final selected = _choiceValues[field.apiName];
    return DropdownButtonFormField<String>(
      value: field.options.contains(selected) ? selected : null,
      decoration: InputDecoration(
        hintText: field.placeholder ?? 'Choose from list...',
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.textFieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.textFieldBorder),
        ),
      ),
      items: field.options
          .map(
            (option) => DropdownMenuItem<String>(
              value: option,
              child: Text(option),
            ),
          )
          .toList(),
      onChanged: field.isReadonly
          ? null
          : (value) {
              setState(() => _choiceValues[field.apiName] = value);
              _notifyChanged();
            },
      validator: (value) {
        if (field.isRequired && (value == null || value.isEmpty)) {
          return '${field.label} is required';
        }
        return null;
      },
    );
  }

  Widget _checkboxField(FormMetadataField field) {
    final checked = _boolValues[field.apiName] ?? false;
    return CheckboxListTile(
      value: checked,
      onChanged: field.isReadonly
          ? null
          : (value) {
              setState(() => _boolValues[field.apiName] = value ?? false);
              _notifyChanged();
            },
      title: Text.rich(
        TextSpan(
          text: field.label,
          style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w600,
          ),
          children: field.isRequired
              ? [
                  TextSpan(
                    text: ' *',
                    style: AppFonts.bodyMedium(
                      color: AppColors.accentRed,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ]
              : const [],
        ),
      ),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      activeColor: AppColors.inkStrong,
    );
  }

  Widget _imageField(FormMetadataField field) {
    final picked = _fileValues[field.apiName];
    return FormField<_PickedFileValue>(
      initialValue: picked,
      validator: (_) {
        if (field.isRequired && _fileValues[field.apiName] == null) {
          return '${field.label} is required';
        }
        return null;
      },
      builder: (state) {
        final borderColor =
            state.hasError ? AppColors.error : AppColors.border;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DottedBorder(
              options: RoundedRectDottedBorderOptions(
                color: borderColor,
                strokeWidth: 1.2,
                dashPattern: const [5, 4],
                radius: const Radius.circular(12),
                padding: EdgeInsets.zero,
              ),
              child: InkWell(
                onTap: field.isReadonly ? null : () => _pickImage(field, state),
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: double.infinity,
                  height: picked == null ? 128 : 148,
                  child: picked == null
                      ? _ImageUploadPlaceholder(
                          hint: field.placeholder ?? 'Tap to upload image',
                        )
                      : _ImageUploadPreview(
                          picked: picked,
                          readOnly: field.isReadonly,
                          onRemove: () {
                            setState(() {
                              _fileValues.remove(field.apiName);
                              state.didChange(null);
                            });
                            _notifyChanged();
                          },
                        ),
                ),
              ),
            ),
            if (field.maxFileSizeMb != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Max file size: ${field.maxFileSizeMb} MB',
                  style: AppFonts.bodySmall(color: AppColors.muted),
                ),
              ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  state.errorText!,
                  style: AppFonts.bodySmall(color: AppColors.error),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _pickImage(
    FormMetadataField field,
    FormFieldState<_PickedFileValue> state,
  ) async {
    final source = await showFormImageSourceSheet(
      context,
      title: field.label,
    );
    if (!mounted || source == null) return;

    _PickedFileValue? value;
    switch (source) {
      case FormImagePickSource.camera:
      case FormImagePickSource.gallery:
        final picker = ImagePicker();
        final file = await picker.pickImage(
          source: source == FormImagePickSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
          imageQuality: 85,
        );
        if (file != null) {
          value = _PickedFileValue(
            name: file.name,
            path: file.path,
            sizeBytes: await file.length(),
          );
        }
      case FormImagePickSource.file:
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        final file = result?.files.single;
        if (file != null) {
          value = _PickedFileValue(
            name: file.name,
            path: file.path,
            sizeBytes: file.size,
          );
        }
    }

    if (value == null) return;
    if (field.maxFileSizeMb != null &&
        value.sizeBytes > field.maxFileSizeMb! * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File must be ${field.maxFileSizeMb} MB or smaller'),
        ),
      );
      return;
    }

    setState(() {
      _fileValues[field.apiName] = value!;
      state.didChange(value);
    });
    _notifyChanged();
  }

  Widget _unsupportedField(FormMetadataField field) {
    return AppTextField(
      controller: _textControllers[field.apiName]!,
      hintText: field.placeholder ?? field.label,
      readOnly: field.isReadonly,
      enabled: !field.isReadonly,
      borderRadius: 12,
      onChanged: (_) => _notifyChanged(),
      validator: (value) => _textValidator(field, value),
    );
  }
}

class _EmptyMetadataState extends StatelessWidget {
  const _EmptyMetadataState({required this.formName});

  final String formName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          formName,
          style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.textFieldBorder,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.description_outlined, size: 40, color: AppColors.muted),
              const SizedBox(height: 8),
              Text(
                'No fields configured for this form.',
                textAlign: TextAlign.center,
                style: AppFonts.bodyMedium(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PickedFileValue {
  const _PickedFileValue({
    required this.name,
    this.path,
    this.sizeBytes = 0,
  });

  final String name;
  final String? path;
  final int sizeBytes;
}

class _ImageUploadPlaceholder extends StatelessWidget {
  const _ImageUploadPlaceholder({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.add_photo_alternate_outlined,
                size: 26,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Camera, gallery, or files',
              style: AppFonts.bodySmall(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageUploadPreview extends StatelessWidget {
  const _ImageUploadPreview({
    required this.picked,
    required this.readOnly,
    required this.onRemove,
  });

  final _PickedFileValue picked;
  final bool readOnly;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hasFile =
        picked.path != null && File(picked.path!).existsSync();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasFile)
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.file(
              File(picked.path!),
              fit: BoxFit.cover,
            ),
          )
        else
          Center(
            child: Icon(Icons.image_outlined, size: 40, color: AppColors.muted),
          ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    picked.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.bodySmall(
                      color: AppColors.white,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (!readOnly)
                  GestureDetector(
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _FieldKind {
  text,
  multiLine,
  email,
  number,
  phone,
  date,
  radio,
  dropdown,
  checkbox,
  image,
  qr,
  signature,
  unsupported,
}

_FieldKind _fieldKind(FormMetadataField field) {
  final type = _normalizedType(field.fieldType);
  final api = field.apiName.trim().toLowerCase();
  final label = field.label.trim().toLowerCase();

  if (type == _FieldKind.signature || _looksLikeSignatureField(api, label)) {
    return _FieldKind.signature;
  }

  if (type != _FieldKind.text && type != _FieldKind.unsupported) return type;

  if (api.contains('qr') ||
      label.contains('qr code') ||
      label.contains('scan qr') ||
      label == 'qr') {
    return _FieldKind.qr;
  }
  return type;
}

bool _looksLikeSignatureField(String api, String label) {
  if (api.contains('signature')) return true;
  if (api.endsWith('_sign') || api == 'sign') return true;
  if (label.contains('signature')) return true;
  if (label.contains('sign here') || label.contains('enter your sign')) {
    return true;
  }
  return false;
}

_FieldKind _normalizedType(String raw) {
  switch (raw) {
    case 'single_line':
    case 'text':
    case 'string':
    case 'url':
      return _FieldKind.text;
    case 'multi_line':
    case 'textarea':
    case 'long_text':
      return _FieldKind.multiLine;
    case 'email':
      return _FieldKind.email;
    case 'number':
    case 'integer':
    case 'decimal':
    case 'currency':
    case 'amount':
      return _FieldKind.number;
    case 'phone':
    case 'phone_number':
      return _FieldKind.phone;
    case 'date':
    case 'datetime':
    case 'date_time':
      return _FieldKind.date;
    case 'radio':
    case 'choice':
      return _FieldKind.radio;
    case 'dropdown':
    case 'select':
    case 'picklist':
      return _FieldKind.dropdown;
    case 'checkbox':
    case 'boolean':
    case 'bool':
      return _FieldKind.checkbox;
    case 'image_upload':
    case 'image':
    case 'file':
    case 'file_upload':
      return _FieldKind.image;
    case 'qr_code':
    case 'qr':
    case 'qrcode':
    case 'barcode':
    case 'qr_scan':
      return _FieldKind.qr;
    case 'signature':
    case 'digital_signature':
    case 'sign':
    case 'esign':
      return _FieldKind.signature;
    default:
      return _FieldKind.unsupported;
  }
}

final class TechnicianFormOfflineBanner extends StatelessWidget {
  const TechnicianFormOfflineBanner({
    super.key,
    required this.visible,
    this.isSyncing = false,
  });

  final bool visible;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final message = isSyncing
        ? 'Back online — refreshing form…'
        : 'Offline — showing saved form';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF2D38B)),
      ),
      child: Row(
        children: [
          Icon(
            isSyncing ? Icons.sync_rounded : Icons.cloud_off_rounded,
            size: 18,
            color: const Color(0xFF8A6D1D),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppFonts.bodySmall(
                color: const Color(0xFF8A6D1D),
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
