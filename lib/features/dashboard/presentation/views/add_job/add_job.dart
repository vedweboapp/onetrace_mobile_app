library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_date_picker_dialog.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/data/job_models.dart';
import 'package:red5/features/dashboard/data/job_write_payload.dart';
import 'package:red5/features/dashboard/presentation/jobs_list_refresh.dart';
import 'package:red5/features/dashboard/presentation/views/project_details_page.dart';
import 'package:red5/features/forms/data/form_picker_utils.dart';
import 'package:red5/features/forms/data/forms_api_client.dart';
import 'package:red5/features/items/data/items_api_client.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';
import 'package:red5/features/sites/data/site_models.dart';
import 'package:red5/features/sites/data/sites_api_client.dart';
import 'package:red5/features/user_profile/data/user_profile_api_client.dart';
import 'package:red5/features/dashboard/presentation/widgets/forms_multi_picker_sheet.dart';
import 'package:red5/features/user_profile/data/user_profile_models.dart';

part 'add_job_page.dart';
part 'models/material_line.dart';
part 'widgets/job_qr_scanner_page.dart';

