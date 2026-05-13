import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';

/// Rich-text description control: toolbar (bold, italic, bullets, link) and
/// bordered editor with placeholder, aligned with the add-quotation design.
Widget buildQuotationDescriptionRichField({
  required QuillController quillController,
  required FocusNode editorFocusNode,
  required ScrollController editorScrollController,
  String placeholder = 'Enter project scope and technical requirements...',
  double editorMinHeight = 120,
  double editorMaxHeight = 220,
}) {
  const borderColor = AppColors.textFieldBorder;

  final toolbarConfig = QuillSimpleToolbarConfig(
    multiRowsDisplay: false,
    showDividers: false,
    showUndo: false,
    showRedo: false,
    showFontFamily: false,
    showFontSize: false,
    showUnderLineButton: false,
    showStrikeThrough: false,
    showInlineCode: false,
    showColorButton: false,
    showBackgroundColorButton: false,
    showClearFormat: false,
    showHeaderStyle: false,
    showListNumbers: false,
    showListBullets: true,
    showListCheck: false,
    showCodeBlock: false,
    showQuote: false,
    showIndent: false,
    showSearchButton: false,
    showSubscript: false,
    showSuperscript: false,
    showBoldButton: true,
    showItalicButton: true,
    showLink: true,
    showAlignmentButtons: false,
    decoration: const BoxDecoration(
      color: Color(0xFFF5F5F5),
    ),
    iconTheme: QuillIconTheme(
      iconButtonUnselectedData: IconButtonData(
        color: AppColors.textFieldHint,
        iconSize: 20,
      ),
      iconButtonSelectedData: IconButtonData(
        color: AppColors.inkStrong,
        iconSize: 20,
      ),
    ),
  );

  final editorStyle = AppFonts.bodyMedium().copyWith(
    color: AppColors.textFieldForeground,
    fontWeight: FontWeight.w500,
    fontSize: 15,
    height: 1.45,
  );

  final editorConfig = QuillEditorConfig(
    scrollable: true,
    expands: false,
    autoFocus: false,
    minHeight: editorMinHeight,
    maxHeight: editorMaxHeight,
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
    placeholder: placeholder,
    customStyles: DefaultStyles(
      paragraph: DefaultTextBlockStyle(
        editorStyle,
        HorizontalSpacing.zero,
        const VerticalSpacing(0, 6),
        VerticalSpacing.zero,
        null,
      ),
      placeHolder: DefaultTextBlockStyle(
        AppFonts.bodyMedium().copyWith(
          color: AppColors.textFieldHint,
          fontWeight: FontWeight.w400,
          fontSize: 15,
          height: 1.45,
        ),
        HorizontalSpacing.zero,
        VerticalSpacing.zero,
        VerticalSpacing.zero,
        null,
      ),
    ),
  );

  return DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppTextField.defaultBorderRadius),
      border: Border.all(color: borderColor),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppTextField.defaultBorderRadius),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuillSimpleToolbar(
            controller: quillController,
            config: toolbarConfig,
          ),
          Divider(height: 1, thickness: 1, color: borderColor.withValues(alpha: 0.65)),
          QuillEditor.basic(
            controller: quillController,
            focusNode: editorFocusNode,
            scrollController: editorScrollController,
            config: editorConfig,
          ),
        ],
      ),
    ),
  );
}
