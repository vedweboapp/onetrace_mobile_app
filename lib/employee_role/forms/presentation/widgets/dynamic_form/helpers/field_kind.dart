part of '../dynamic_form.dart';

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
    case 'multi_image_upload':
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
