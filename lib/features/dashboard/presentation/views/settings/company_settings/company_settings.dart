library;

import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/constants/app_strings.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/providers/local_storage_provider.dart';
import 'package:red5/core/storage/local_storage_keys.dart';
import 'package:red5/core/storage/organization_id_storage.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/features/dashboard/data/organization_settings_api_client.dart';
import 'package:red5/features/dashboard/data/organization_settings_models.dart';
import 'package:red5/features/dashboard/data/organization_settings_codec.dart';
import 'package:red5/features/dashboard/data/organization_settings_write.dart';
import 'package:red5/features/user_profile/data/user_profile_api_client.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/core/places/place_address.dart';
import 'package:red5/core/widgets/app_address_fields.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/presentation/views/dashboard_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/integration_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/settings_feature_flags.dart';
import 'package:red5/features/dashboard/presentation/views/settings/personal_profile_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/privacy_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/users_settings_page.dart';

part 'company_settings_page.dart';
part 'models/home_currency_settings.dart';
part 'widgets/settings_drawer.dart';
part 'widgets/change_home_currency_page.dart';
part 'widgets/format_mode_chip.dart';

