// Matrix4 translate/scale cascades still use stable APIs flagged as deprecated in latest SDK.
// ignore_for_file: deprecated_member_use

library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:red5/core/pdf_coordinates/pdf_coordinates.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/constants/app_strings.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/core/network/dio_multipart_transfer.dart';
import 'package:red5/core/providers/local_storage_provider.dart';
import 'package:red5/core/storage/local_storage_keys.dart';
import 'package:red5/core/theme/app_bar_styles.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/theme/app_layout.dart';
import 'package:red5/core/theme/app_screen_size.dart';
import 'package:red5/core/widgets/app_button.dart';
import 'package:red5/core/widgets/app_screen_stack.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/core/widgets/update_block_name_dialog.dart';
import 'package:red5/features/dashboard/presentation/views/dashboard_page.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';
import 'package:red5/features/quote/data/quote_selection_options.dart';
import 'package:red5/features/quote/data/quotations_by_block_store.dart';
import 'package:red5/features/quote/presentation/widgets/initialize_level_dialog.dart';
import 'package:red5/features/quote/presentation/widgets/manage_plot_area_dialog.dart';
import 'package:red5/features/quote/presentation/widgets/new_plot_name_dialog.dart';
import 'package:red5/features/quote/presentation/widgets/pin_detail_sheet.dart';
import 'package:red5/features/quote/presentation/widgets/quote_canvas_markup.dart';

part 'models/uploaded_doc.dart';
part 'quote_project_page.dart';
part 'widgets/document_carousel.dart';
part 'widgets/canvas_toolbar_bits.dart';
part 'widgets/bottom_bar_tags.dart';
