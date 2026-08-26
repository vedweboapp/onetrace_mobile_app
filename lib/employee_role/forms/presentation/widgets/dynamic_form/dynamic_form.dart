library;

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
import 'package:red5/employee_role/forms/data/form_visibility_engine.dart';
import 'package:red5/employee_role/forms/presentation/widgets/form_image_source_sheet.dart';
import 'package:red5/employee_role/forms/presentation/widgets/form_metadata_layout_widgets.dart';
import 'package:red5/core/utils/qr_code_utils.dart';
import 'package:red5/employee_role/forms/presentation/widgets/form_qr_input_sheet.dart';
import 'package:red5/employee_role/forms/presentation/widgets/form_qr_scanner_page.dart';
import 'package:red5/employee_role/forms/data/form_video_recorder_constraints.dart';
import 'package:red5/employee_role/forms/presentation/widgets/form_video_recorder_field.dart';
import 'package:red5/employee_role/forms/presentation/widgets/form_signature_field.dart';
import 'package:red5/employee_role/jobs/data/job_form_models.dart';

part 'dynamic_form_view.dart';
part 'models/picked_file_value.dart';
part 'helpers/field_kind.dart';
part 'widgets/empty_metadata_state.dart';
part 'widgets/image_upload_widgets.dart';
part 'widgets/technician_form_offline_banner.dart';
