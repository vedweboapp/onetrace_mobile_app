library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/quotations/data/quotation_models.dart';
import 'package:red5/features/quotations/data/quotations_api_client.dart';
import 'package:url_launcher/url_launcher.dart';

part 'quotation_detail_page.dart';
part 'helpers/scope_parsers.dart';
part 'models/scope_quote_vms.dart';
part 'models/scope_parsed_models.dart';
part 'widgets/scope_pricing_tab.dart';
part 'widgets/scope_cards.dart';
part 'widgets/scope_quoted_widgets.dart';
