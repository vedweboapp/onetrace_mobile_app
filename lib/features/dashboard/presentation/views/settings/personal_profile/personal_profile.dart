library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/preferences/nav_menu_style_preference.dart';
import 'package:red5/core/storage/local_storage_keys.dart';
import 'package:red5/core/storage/organization_id_storage.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:red5/core/utils/phone_number_utils.dart';
import 'package:red5/core/widgets/app_phone_text_field.dart';
import 'package:red5/core/widgets/app_address_fields.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/core/providers/local_storage_provider.dart';
import 'package:red5/employee_role/employee_home/employee_home_page.dart';
import 'package:red5/employee_role/presentation/employee_technician_settings_routes.dart';
import 'package:red5/employee_role/presentation/widgets/technician_settings_drawer.dart';
import 'package:red5/features/dashboard/presentation/views/dashboard_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/company_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/integration_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/settings_feature_flags.dart';
import 'package:red5/features/dashboard/presentation/views/settings/privacy_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/users_settings_page.dart';
import 'package:red5/features/user_profile/data/role_models.dart';
import 'package:red5/features/user_profile/data/roles_api_client.dart';
import 'package:red5/features/user_profile/data/user_profile_api_client.dart';
import 'package:red5/features/user_profile/data/user_profile_models.dart'
    show AppearanceSettingsModel, UserAddressModel, UserProfileModel;

part 'personal_profile_page.dart';
part 'widgets/appearance_button.dart';
