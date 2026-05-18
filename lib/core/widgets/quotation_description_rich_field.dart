import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';

/// Rich-text description: toolbar + bordered editor for add-quotation.
///
/// Uses a [StatefulWidget] with its own [ScrollController] so the outer
/// scroll view does not share scroll state with Quill (avoids viewport /
/// duplicate-GlobalKey issues when the form rebuilds).
class QuotationDescriptionRichField extends StatefulWidget {
  const QuotationDescriptionRichField({
    super.key,
    required this.quillController,
    required this.editorFocusNode,
    this.placeholder = 'Enter project scope and technical requirements...',
    this.editorMinHeight = 120,
    this.editorMaxHeight = 220,
  });

  final QuillController quillController;
  final FocusNode editorFocusNode;
  final String placeholder;
  final double editorMinHeight;
  final double editorMaxHeight;

  @override
  State<QuotationDescriptionRichField> createState() =>
      _QuotationDescriptionRichFieldState();
}

class _QuotationDescriptionRichFieldState extends State<QuotationDescriptionRichField> {
  late final ScrollController _editorScroll;

  @override
  void initState() {
    super.initState();
    _editorScroll = ScrollController();
  }

  @override
  void dispose() {
    _editorScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      scrollable: false,
      expands: false,
      autoFocus: false,
      minHeight: widget.editorMinHeight,
      maxHeight: widget.editorMaxHeight,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      placeholder: widget.placeholder,
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

    return RepaintBoundary(
      child: DecoratedBox(
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
                controller: widget.quillController,
                config: toolbarConfig,
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: borderColor.withValues(alpha: 0.65),
              ),
              QuillEditor.basic(
                controller: widget.quillController,
                focusNode: widget.editorFocusNode,
                scrollController: _editorScroll,
                config: editorConfig,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// See [QuotationDescriptionRichField].
Widget buildQuotationDescriptionRichField({
  Key? key,
  required QuillController quillController,
  required FocusNode editorFocusNode,
  String placeholder = 'Enter project scope and technical requirements...',
  double editorMinHeight = 120,
  double editorMaxHeight = 220,
}) {
  return QuotationDescriptionRichField(
    key: key,
    quillController: quillController,
    editorFocusNode: editorFocusNode,
    placeholder: placeholder,
    editorMinHeight: editorMinHeight,
    editorMaxHeight: editorMaxHeight,
  );
}
