library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/core/maps/app_map_tiles.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/data/job_models.dart';
import 'package:red5/features/dashboard/data/job_write_payload.dart';
import 'package:red5/features/dashboard/data/quote_summary.dart';
import 'package:red5/features/dashboard/presentation/views/add_job_page.dart';
import 'package:red5/features/dashboard/presentation/views/drawing_canvas_page.dart';
import 'package:red5/features/dashboard/presentation/views/project_details_page.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';
import 'package:url_launcher/url_launcher.dart';

part 'job_details_page.dart';
part 'models/job_drawing_item.dart';
part 'widgets/visible_map_tiles.dart';
part 'widgets/job_qr_scanner_page.dart';
