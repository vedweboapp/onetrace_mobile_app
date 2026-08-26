library;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_date_picker_dialog.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/quotation_description_rich_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/clients/data/client_models.dart';
import 'package:red5/features/clients/data/clients_api_client.dart';
import 'package:red5/features/contacts/data/contact_models.dart';
import 'package:red5/features/contacts/data/contacts_api_client.dart';
import 'package:red5/features/dashboard/data/crm_quotes_api_provider.dart';
import 'package:red5/features/dashboard/data/quote_list_page_result.dart';
import 'package:red5/features/dashboard/data/quote_summary.dart';
import 'package:red5/features/quotations/data/quotation_models.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';
import 'package:red5/features/quotations/data/quotations_api_client.dart';
import 'package:red5/features/quotations/presentation/widgets/quotation_block_sections_panel.dart';
import 'package:red5/features/quotations/presentation/widgets/quotation_map_block_sheet.dart';
import 'package:red5/features/sites/data/site_models.dart';
import 'package:red5/features/user_profile/data/user_profile_api_client.dart';
import 'package:red5/features/user_profile/data/user_profile_models.dart';


part 'add_quotation_page.dart';
