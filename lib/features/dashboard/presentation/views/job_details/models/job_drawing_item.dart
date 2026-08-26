part of '../job_details.dart';

class _JobDrawingItem {
  const _JobDrawingItem({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.updatedLabel,
    this.remoteDrawingUrl,
    this.levelName,
    this.projectId,
    this.levelId,
    this.isLinked = false,
  });

  final String code;
  final String title;
  final String subtitle;
  final String updatedLabel;
  final String? remoteDrawingUrl;
  final String? levelName;
  final String? projectId;
  final String? levelId;
  final bool isLinked;
}
