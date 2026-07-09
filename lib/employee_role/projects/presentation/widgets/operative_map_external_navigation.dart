import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the device maps app for turn-by-turn navigation to a site pin.
Future<void> openOperativeMapExternalNavigation(
  BuildContext context, {
  required double latitude,
  required double longitude,
}) async {
  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '$latitude,$longitude',
    'travelmode': 'driving',
  });
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Could not open navigation app.')),
  );
}
