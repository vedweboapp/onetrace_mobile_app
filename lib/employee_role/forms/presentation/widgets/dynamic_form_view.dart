import 'dart:async';
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
import 'package:red5/employee_role/forms/data/signature_form_value.dart';
import 'package:red5/employee_role/forms/data/form_video_recorder_constraints.dart';
import 'package:red5/employee_role/forms/presentation/widgets/form_video_recorder_field.dart';
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
    this.hideQrFields = false,
  });

  final TechnicianFormBundle bundle;
  final VoidCallback? onChanged;

  /// Called after a QR value is captured; use to register scan + fetch details.
  final Future<void> Function(String qrCode)? onQrCodeScanned;

  /// Notifies when the user starts or stops drawing on a signature pad.
  final ValueChanged<bool>? onSignatureDrawingChanged;

  /// When true, QR fields are omitted from the form UI (e.g. pin QR handled
  /// separately at the bottom of the job form page).
  final bool hideQrFields;

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
  final _videoValues = <String, FormPickedVideoValue>{};
  final _signatureStrokes = <String, List<List<Offset>>>{};
  final _signaturePngBase64 = <String, String>{};
  final _signatureFiles = <String, _PickedFileValue>{};
  final _signatureDrawing = <String, bool>{};
  final _phoneCountries = <String, CountryCode>{};

  late List<FormMetadataSection> _sections;
  static final _dateFormat = DateFormat('MM/dd/yyyy');
  static final _dateTimeFormat = DateFormat('MM/dd/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _sections = _parseSections();
    _initFieldState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onChanged?.call();
    });
  }

  @override
  void didUpdateWidget(covariant DynamicFormView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bundleChanged =
        oldWidget.bundle.contentHash != widget.bundle.contentHash;
    final hideQrChanged = oldWidget.hideQrFields != widget.hideQrFields;
    if (bundleChanged || hideQrChanged) {
      _disposeControllers();
      _sections = _parseSections();
      _dateValues.clear();
      _choiceValues.clear();
      _boolValues.clear();
      _fileValues.clear();
      _videoValues.clear();
      _signatureStrokes.clear();
      _signaturePngBase64.clear();
      _signatureFiles.clear();
      _signatureDrawing.clear();
      _phoneCountries.clear();
      _initFieldState();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onChanged?.call();
      });
    }
  }

  List<FormMetadataSection> _parseSections() {
    final filtered = filterOperativeFormSections(
      parseFormMetadataSections(widget.bundle.metadata),
    );
    if (!widget.hideQrFields) return filtered;
    return [
      for (final section in filtered)
        FormMetadataSection(
          id: section.id,
          name: section.name,
          sequence: section.sequence,
          columnCount: section.columnCount,
          isActive: section.isActive,
          fields: section.fields
              .where((field) => !isQrFormField(field))
              .toList(growable: false),
        ),
    ];
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
          case _FieldKind.dateTime:
            _dateValues[key] = null;
          case _FieldKind.radio:
          case _FieldKind.dropdown:
            _choiceValues[key] = null;
          case _FieldKind.checkbox:
            _boolValues[key] = false;
          case _FieldKind.image:
            break;
          case _FieldKind.video:
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
  /// Forms with no input fields (empty/null metadata) always pass validation.
  bool validate() {
    if (!hasInputFields) return true;
    return _formKey.currentState?.validate() ?? true;
  }

  /// Whether every required visible field has a value (without Form validators).
  /// Used to reveal pin QR scan after the operative finishes required inputs.
  bool areRequiredFieldsComplete({bool ignoreQrFields = false}) {
    for (final section in _sections) {
      for (final field in section.fields) {
        if (!field.isRequired || field.isReadonly) continue;
        if (ignoreQrFields && isQrFormField(field)) continue;
        if (!_isFieldFilled(field)) return false;
      }
    }
    return true;
  }

  bool _isFieldFilled(FormMetadataField field) {
    final key = field.apiName;
    switch (_fieldKind(field)) {
      case _FieldKind.text:
      case _FieldKind.email:
      case _FieldKind.number:
      case _FieldKind.qr:
      case _FieldKind.multiLine:
      case _FieldKind.unsupported:
        return (_textControllers[key]?.text.trim().isNotEmpty ?? false);
      case _FieldKind.phone:
        return (_textControllers[key]?.text.trim().isNotEmpty ?? false);
      case _FieldKind.date:
      case _FieldKind.dateTime:
        return _dateValues[key] != null;
      case _FieldKind.radio:
      case _FieldKind.dropdown:
        return (_choiceValues[key]?.trim().isNotEmpty ?? false);
      case _FieldKind.checkbox:
        return _boolValues[key] == true;
      case _FieldKind.image:
        return _fileValues[key] != null;
      case _FieldKind.video:
        return _videoValues[key] != null;
      case _FieldKind.signature:
        return _hasSignature(key);
    }
  }

  /// Whether the form has any fields the operative can fill in.
  bool get hasInputFields =>
      _sections.any((section) => section.fields.isNotEmpty);

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
            values[key] = _formatDateForApi(_dateValues[key]);
          case _FieldKind.dateTime:
            values[key] = _formatDateTimeForApi(_dateValues[key]);
          case _FieldKind.radio:
          case _FieldKind.dropdown:
            values[key] = _choiceValues[key];
          case _FieldKind.checkbox:
            values[key] = _boolValues[key] ?? false;
          case _FieldKind.image:
            values[key] = _fileValues[key]?.name;
          case _FieldKind.video:
            values[key] = _videoValues[key]?.name;
          case _FieldKind.signature:
            values[key] = _signatureFiles[key]?.name ?? '';
        }
      }
    }
    return values;
  }

  /// Ensures signature fields are exported to PNG files before submit/draft.
  Future<void> ensureSignaturesReady() async {
    for (final section in _sections) {
      for (final field in section.fields) {
        if (_fieldKind(field) != _FieldKind.signature) continue;
        final key = field.apiName;
        if ((_signatureFiles[key]?.name.trim().isNotEmpty ?? false)) continue;
        final strokes = _signatureStrokes[key] ?? const [];
        if (!strokes.any((stroke) => stroke.length >= 2)) continue;
        await _refreshSignaturePngCache(field, strokes);
      }
    }
  }

  String? _localFilePathForField(FormMetadataField field) {
    switch (_fieldKind(field)) {
      case _FieldKind.signature:
        return _signatureFiles[field.apiName]?.path;
      case _FieldKind.image:
        return _fileValues[field.apiName]?.path;
      case _FieldKind.video:
        final path = _videoValues[field.apiName]?.path?.trim();
        if (path == null || path.isEmpty) return null;
        return path;
      default:
        return null;
    }
  }

  Future<void> _refreshSignaturePngCache(
    FormMetadataField field,
    List<List<Offset>> strokes,
  ) async {
    final apiName = field.apiName;
    final export = await exportSignaturePngFile(
      fieldId: field.id,
      strokes: strokes,
    );
    if (!mounted) return;
    if (export == null) {
      _signatureFiles.remove(apiName);
      _signaturePngBase64.remove(apiName);
    } else {
      _signatureFiles[apiName] = _PickedFileValue(
        name: export.filename,
        path: export.path,
        sizeBytes: export.bytes.length,
      );
      _signaturePngBase64[apiName] = base64Encode(export.bytes);
    }
    setState(() {});
  }

  /// Field values formatted for `POST /jobs/{id}/submit-form/`.
  List<JobFormFieldValue> collectApiValues() {
    final rows = <JobFormFieldValue>[];
    final byApiName = collectValues();
    for (final section in _sections) {
      for (final field in section.fields) {
        if (field.id <= 0) continue;
        final raw = byApiName[field.apiName];
        final localFilePath = _localFilePathForField(field);
        var value = _serializeFieldForApi(field, raw);
        if (value.trim().isEmpty &&
            (localFilePath == null || localFilePath.trim().isEmpty)) {
          continue;
        }
        if (value.trim().isEmpty && localFilePath != null) {
          final parts = localFilePath.split(Platform.pathSeparator);
          value = parts.isNotEmpty ? parts.last : value;
        }
        rows.add(
          JobFormFieldValue(
            fieldId: field.id,
            value: value,
            localFilePath: localFilePath,
            fieldType: field.fieldType,
          ),
        );
      }
    }
    return rows;
  }

  /// Like [collectApiValues] but writes signature pads to PNG files first.
  Future<List<JobFormFieldValue>> collectApiValuesAsync() async {
    await ensureSignaturesReady();
    return collectApiValues();
  }

  /// Restores saved or submitted values keyed by metadata field id.
  void applyFieldValues(List<JobFormFieldValue> values) {
    if (values.isEmpty) return;

    final byFieldId = <int, JobFormFieldValue>{
      for (final row in values)
        if (row.fieldId > 0) row.fieldId: row,
    };

    for (final section in _sections) {
      for (final field in section.fields) {
        final row = byFieldId[field.id];
        if (row == null) continue;
        _applyValue(field, row);
      }
    }
    if (mounted) setState(() {});
  }

  void _applyValue(FormMetadataField field, JobFormFieldValue row) {
    final raw = row.value;
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
        _dateValues[key] = _parseDateValue(raw);
      case _FieldKind.dateTime:
        _dateValues[key] = _parseDateTimeValue(raw);
      case _FieldKind.radio:
      case _FieldKind.dropdown:
        _choiceValues[key] = raw.isEmpty ? null : raw;
      case _FieldKind.checkbox:
        final normalized = raw.trim().toLowerCase();
        _boolValues[key] = normalized == 'true' || normalized == '1';
      case _FieldKind.image:
        final localPath = row.localFilePath?.trim();
        if (localPath != null &&
            localPath.isNotEmpty &&
            File(localPath).existsSync()) {
          _fileValues[key] = _PickedFileValue(
            name: raw.trim().isNotEmpty
                ? raw.trim()
                : localPath.split(Platform.pathSeparator).last,
            path: localPath,
            sizeBytes: File(localPath).lengthSync(),
          );
        } else if (raw.trim().isNotEmpty) {
          _fileValues[key] = _PickedFileValue(
            name: raw.trim(),
            path: null,
          );
        }
      case _FieldKind.video:
        final localPath = row.localFilePath?.trim();
        if (localPath != null &&
            localPath.isNotEmpty &&
            File(localPath).existsSync()) {
          _videoValues[key] = FormPickedVideoValue(
            name: raw.trim().isNotEmpty
                ? raw.trim()
                : localPath.split(Platform.pathSeparator).last,
            path: localPath,
            sizeBytes: File(localPath).lengthSync(),
            duration: Duration.zero,
          );
        } else if (raw.trim().isNotEmpty) {
          _videoValues[key] = FormPickedVideoValue(
            name: raw.trim(),
            path: '',
            sizeBytes: 0,
            duration: Duration.zero,
          );
        }
      case _FieldKind.signature:
        final localPath = row.localFilePath?.trim();
        if (localPath != null &&
            localPath.isNotEmpty &&
            File(localPath).existsSync()) {
          final filename = raw.trim().isNotEmpty
              ? raw.trim()
              : localPath.split(Platform.pathSeparator).last;
          _signatureFiles[key] = _PickedFileValue(
            name: filename,
            path: localPath,
            sizeBytes: File(localPath).lengthSync(),
          );
          _signatureStrokes[key] = const [];
          break;
        }
        final display = parseSignatureDisplayValue(raw);
        if (display.hasImage) {
          if (display.bytes != null) {
            _signaturePngBase64[key] = base64Encode(display.bytes!);
          } else {
            _signaturePngBase64[key] = raw.trim();
          }
          if (display.bytes != null && field.id > 0) {
            _signatureFiles[key] = _PickedFileValue(
              name: signatureFilenameForField(field.id),
              path: null,
              sizeBytes: display.bytes!.length,
            );
          } else if (raw.trim().toLowerCase().endsWith('.png')) {
            _signatureFiles[key] = _PickedFileValue(
              name: raw.trim(),
              path: null,
            );
          }
          _signatureStrokes[key] = const [];
          break;
        }
        _signatureStrokes[key] = strokesFromSignatureValue(raw);
        _signaturePngBase64.remove(key);
        _signatureFiles.remove(key);
        final restored = _signatureStrokes[key] ?? const [];
        if (restored.any((stroke) => stroke.length >= 2)) {
          unawaited(_refreshSignaturePngCache(field, restored));
        }
    }
  }

  static String _serializeFieldForApi(FormMetadataField field, dynamic value) {
    if (_fieldKind(field) == _FieldKind.date) {
      return _serializeDateForApi(value);
    }
    if (_fieldKind(field) == _FieldKind.dateTime) {
      return _serializeDateTimeForApi(value);
    }
    if (_fieldKind(field) == _FieldKind.signature) {
      if (value == null) return '';
      final text = value.toString().trim();
      if (text.isEmpty) return '';
      return text;
    }
    final serialized = _serializeForApi(value);
    if (_fieldKind(field) == _FieldKind.qr && serialized.trim().isNotEmpty) {
      return QrCodeUtils.normalizeScannedValue(serialized);
    }
    return serialized;
  }

  static String _serializeDateTimeForApi(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) {
      return _formatDateTimeForApi(value) ?? '';
    }
    final text = value.toString().trim();
    if (text.isEmpty) return '';
    return normalizeJobFormDateTimeValue(text);
  }

  static String _serializeDateForApi(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) {
      return _formatDateForApi(value) ?? '';
    }
    final text = value.toString().trim();
    if (text.isEmpty) return '';
    return normalizeJobFormDateValue(text);
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
      _FieldKind.dateTime => _dateTimeField(field),
      _FieldKind.radio => _radioField(field),
      _FieldKind.dropdown => _dropdownField(field),
      _FieldKind.checkbox => _checkboxField(field),
      _FieldKind.image => _imageField(field),
      _FieldKind.video => _videoField(field),
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
    if (_signatureFiles[apiName]?.name.trim().isNotEmpty ?? false) return true;
    if (_signaturePngBase64[apiName]?.trim().isNotEmpty ?? false) return true;
    final strokes = _signatureStrokes[apiName] ?? const [];
    return strokes.any((stroke) => stroke.length > 1);
  }

  Widget _signatureField(FormMetadataField field) {
    final apiName = field.apiName;
    final strokes = _signatureStrokes[apiName] ?? const [];
    final stored =
        _signaturePngBase64[apiName] ?? _signatureFiles[apiName]?.name ?? '';
    final display = parseSignatureDisplayValue(stored);
    final isDrawing = _signatureDrawing[apiName] ?? false;
    final showPreview = display.hasImage && !isDrawing;

    if (showPreview) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _signaturePreview(display),
          if (!field.isReadonly) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _signaturePngBase64.remove(apiName);
                    _signatureFiles.remove(apiName);
                    _signatureStrokes[apiName] = const [];
                    _signatureDrawing[apiName] = false;
                  });
                  widget.onChanged?.call();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Sign again'),
              ),
            ),
          ],
        ],
      );
    }

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
              onDrawingChanged: (drawing) {
                _signatureDrawing[apiName] = drawing;
                widget.onSignatureDrawingChanged?.call(drawing);
                if (!drawing && mounted) setState(() {});
              },
              onChanged: (updated) {
                setState(() {
                  _signatureStrokes[apiName] = updated;
                  state.didChange(_hasSignature(apiName));
                });
                widget.onChanged?.call();
                unawaited(_refreshSignaturePngCache(field, updated));
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

  Widget _signaturePreview(SignatureDisplaySource display) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.textFieldBorder, width: 1.2),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: display.bytes != null
            ? Image.memory(
                display.bytes!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text(
                  'Could not display signature image',
                  style: AppFonts.bodySmall(color: AppColors.muted),
                ),
              )
            : Image.network(
                display.imageUrl!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Text(
                  'Could not load signature image',
                  style: AppFonts.bodySmall(color: AppColors.muted),
                ),
              ),
      ),
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

  bool _fieldAllowsDecimal(FormMetadataField field) {
    final type = field.fieldType.trim().toLowerCase();
    switch (type) {
      case 'decimal':
      case 'currency':
      case 'amount':
      case 'money':
      case 'price':
      case 'float':
      case 'double':
      case 'numeric':
        return true;
      default:
        break;
    }
    final api = field.apiName.trim().toLowerCase();
    final label = field.label.trim().toLowerCase();
    return api.contains('amount') ||
        api.contains('currency') ||
        api.contains('price') ||
        label.contains('amount') ||
        label.contains('currency') ||
        label.contains('price');
  }

  List<String> _dropdownOptions(FormMetadataField field) {
    final options = List<String>.from(field.options);
    final selected = _choiceValues[field.apiName];
    if (selected != null &&
        selected.trim().isNotEmpty &&
        !options.contains(selected)) {
      options.insert(0, selected);
    }
    return options;
  }

  static String? _formatDateTimeForApi(DateTime? date) {
    if (date == null) return null;
    return formatJobFormDateTimeForApi(date);
  }

  static String? _formatDateForApi(DateTime? date) {
    if (date == null) return null;
    return formatJobFormDateForApi(date);
  }

  static DateTime? _parseDateTimeValue(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$').hasMatch(trimmed)) {
      try {
        final datePart = trimmed.substring(0, 10);
        final timePart = trimmed.substring(11);
        final parts = timePart.split(':');
        final year = int.parse(datePart.substring(0, 4));
        final month = int.parse(datePart.substring(5, 7));
        final day = int.parse(datePart.substring(8, 10));
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return DateTime(year, month, day, hour, minute);
      } catch (_) {}
    }

    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return iso;

    return _parseDateValue(trimmed);
  }

  static DateTime? _parseDateValue(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (RegExp(r'^\d{8}$').hasMatch(trimmed)) {
      try {
        final year = int.parse(trimmed.substring(0, 4));
        final month = int.parse(trimmed.substring(4, 6));
        final day = int.parse(trimmed.substring(6, 8));
        return DateTime(year, month, day);
      } catch (_) {}
    }

    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return iso;

    for (final format in [
      DateFormat('MM/dd/yyyy'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('MM-dd-yyyy'),
    ]) {
      try {
        return format.parseStrict(trimmed);
      } catch (_) {}
    }
    return null;
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
    final allowDecimal = _fieldAllowsDecimal(field);

    return AppTextField(
      controller: controller,
      hintText: field.placeholder ?? field.label,
      readOnly: field.isReadonly,
      enabled: !field.isReadonly,
      keyboardType: allowDecimal
          ? const TextInputType.numberWithOptions(
              decimal: true,
              signed: false,
            )
          : const TextInputType.numberWithOptions(
              decimal: false,
              signed: false,
            ),
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

  Widget _dateTimeField(FormMetadataField field) {
    final selected = _dateValues[field.apiName];
    final display = selected == null ? '' : _dateTimeFormat.format(selected);
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
                  : () => _pickDateTime(field, state),
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
                        display.isEmpty ? 'mm/dd/yyyy hh:mm' : display,
                        style: AppFonts.bodyMedium(
                          color: display.isEmpty
                              ? AppColors.textFieldHint
                              : AppColors.inkStrong,
                        ).copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Icon(
                      Icons.event_available_outlined,
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

  Future<void> _pickDateTime(
    FormMetadataField field,
    FormFieldState<DateTime> state,
  ) async {
    final current = _dateValues[field.apiName] ?? DateTime.now();
    final pickedDate = await showAppDatePickerDialog(
      context,
      initialDate: current,
      helpText: field.label,
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() {
      _dateValues[field.apiName] = combined;
      state.didChange(combined);
    });
    _notifyChanged();
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
    final options = _dropdownOptions(field);
    return DropdownButtonFormField<String>(
      value: selected != null && options.contains(selected) ? selected : null,
      decoration: InputDecoration(
        hintText: field.placeholder ?? 'Select ${field.label}',
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
      items: options
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
          var path = file.path;
          if ((path == null || path.trim().isEmpty) &&
              file.bytes != null &&
              file.bytes!.isNotEmpty) {
            path = await _writePickedBytesToCache(
              fieldId: field.id,
              filename: file.name,
              bytes: file.bytes!,
            );
          }
          value = _PickedFileValue(
            name: file.name,
            path: path,
            sizeBytes: file.size > 0 ? file.size : (file.bytes?.length ?? 0),
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

  Future<String> _writePickedBytesToCache({
    required int fieldId,
    required String filename,
    required List<int> bytes,
  }) async {
    final dir = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}red5_job_form_attachments',
    );
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final safeName = filename.trim().isNotEmpty ? filename.trim() : 'f$fieldId';
    final path =
        '${dir.path}${Platform.pathSeparator}pick_f${fieldId}_$safeName';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  Widget _videoField(FormMetadataField field) {
    return FormVideoRecorderField(
      label: field.label,
      hint: field.placeholder ?? 'Tap to record a short video',
      readOnly: field.isReadonly,
      required: field.isRequired,
      value: _videoValues[field.apiName],
      onChanged: (value) {
        setState(() {
          if (value == null) {
            _videoValues.remove(field.apiName);
          } else {
            _videoValues[field.apiName] = value;
          }
        });
        _notifyChanged();
      },
      validator: (value) {
        if (field.isRequired && value == null) {
          return '${field.label} is required';
        }
        if (value == null || value.path.trim().isEmpty) return null;
        return FormVideoRecorderConstraints.validate(
          duration: value.duration,
          bytes: value.sizeBytes,
        );
      },
    );
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
                'No fields configured for this form. You can still add remarks and save.',
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
  dateTime,
  radio,
  dropdown,
  checkbox,
  image,
  video,
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

  if (isVideoRecorderFieldType(field.fieldType) || _looksLikeVideoField(api, label)) {
    return _FieldKind.video;
  }

  if (type != _FieldKind.text && type != _FieldKind.unsupported) return type;

  if (_looksLikeDateTimeField(api, label, field.fieldType)) {
    return _FieldKind.dateTime;
  }
  if (_looksLikeDateField(api, label, field.fieldType)) {
    return _FieldKind.date;
  }
  if (_looksLikeCurrencyField(api, label, field.fieldType)) {
    return _FieldKind.number;
  }

  if (api.contains('qr') ||
      label.contains('qr code') ||
      label.contains('scan qr') ||
      label == 'qr') {
    return _FieldKind.qr;
  }
  return type;
}

bool _looksLikeDateTimeField(String api, String label, String fieldType) {
  final type = fieldType.trim().toLowerCase();
  if (type == 'datetime' || type == 'date_time') return true;
  if (api.contains('date_&_time') ||
      api.contains('date_time') ||
      api.contains('datetime')) {
    return true;
  }
  if (label.contains('date & time') || label.contains('date and time')) {
    return true;
  }
  return false;
}

bool _looksLikeDateField(String api, String label, String fieldType) {
  final type = fieldType.trim().toLowerCase();
  if (type == 'datetime' || type == 'date_time') return false;
  const dateTypes = {
    'date',
    'date_picker',
    'datepicker',
    'birth_date',
    'birthdate',
    'due_date',
  };
  if (dateTypes.contains(type)) return true;
  if (api.contains('date_&_time') ||
      api.contains('date_time') ||
      api.contains('datetime')) {
    return false;
  }
  if (api == 'dob' || api.endsWith('_date') || api.contains('due_date')) {
    return true;
  }
  if (label.contains('date & time') || label.contains('date and time')) {
    return false;
  }
  if (label.contains('due date') ||
      label.contains('birth date') ||
      label.contains('date of birth')) {
    return true;
  }
  return false;
}

bool _looksLikeCurrencyField(String api, String label, String fieldType) {
  final type = fieldType.trim().toLowerCase();
  if (type == 'currency' ||
      type == 'amount' ||
      type == 'money' ||
      type == 'price' ||
      type == 'decimal' ||
      type == 'float' ||
      type == 'double' ||
      type == 'numeric') {
    return true;
  }
  return api.contains('amount') ||
      api.contains('currency') ||
      api.contains('price') ||
      label.contains('amount') ||
      label.contains('currency') ||
      label.contains('price');
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

bool _looksLikeVideoField(String api, String label) {
  if (api.contains('video')) return true;
  if (label.contains('video')) return true;
  if (label.contains('record video')) return true;
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
    case 'money':
    case 'price':
    case 'float':
    case 'double':
    case 'numeric':
      return _FieldKind.number;
    case 'phone':
    case 'phone_number':
      return _FieldKind.phone;
    case 'date':
    case 'date_picker':
    case 'datepicker':
    case 'birth_date':
    case 'birthdate':
    case 'due_date':
      return _FieldKind.date;
    case 'datetime':
    case 'date_time':
      return _FieldKind.dateTime;
    case 'radio':
    case 'choice':
      return _FieldKind.radio;
    case 'dropdown':
    case 'select':
    case 'picklist':
    case 'multi_select':
    case 'multi-select':
    case 'multiselect':
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
    case 'video_recorder':
    case 'video_recording':
    case 'video_record':
    case 'video':
    case 'video_upload':
      return _FieldKind.video;
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
