part of '../dynamic_form.dart';

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
