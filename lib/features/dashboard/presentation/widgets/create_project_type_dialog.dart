import 'package:flutter/material.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_brand_color_sheet.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_color_utils.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

Future<NamedIdOption?> showCreateProjectTypeDialog({
  required BuildContext context,
  required QuoteProjectApiClient api,
}) {
  return showDialog<NamedIdOption>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _CreateProjectTypeDialog(api: api),
  );
}

class _CreateProjectTypeDialog extends StatefulWidget {
  const _CreateProjectTypeDialog({required this.api});

  final QuoteProjectApiClient api;

  @override
  State<_CreateProjectTypeDialog> createState() =>
      _CreateProjectTypeDialogState();
}

class _CreateProjectTypeDialogState extends State<_CreateProjectTypeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  Color _bgColor = const Color(0xFFDBEAFE);
  Color _textColor = const Color(0xFF1E40AF);
  late final TextEditingController _bgHexController;
  late final TextEditingController _textHexController;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bgHexController = TextEditingController(text: toHexRgb(_bgColor));
    _textHexController = TextEditingController(text: toHexRgb(_textColor));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bgHexController.dispose();
    _textHexController.dispose();
    super.dispose();
  }

  Future<void> _pickColor({
    required Color initial,
    required ValueChanged<Color> onSelected,
    required TextEditingController hexController,
  }) async {
    final picked = await showBrandColorBottomSheet(context, initialColor: initial);
    if (picked == null || !mounted) return;
    setState(() {
      onSelected(picked);
      hexController.text = toHexRgb(picked);
    });
  }

  void _syncHex(Color color, TextEditingController controller) {
    controller.text = toHexRgb(color);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final created = await widget.api.createProjectType(
        projectType: _nameController.text.trim(),
        bgColor: toHexRgb(_bgColor),
        textColor: toHexRgb(_textColor),
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to create project type',
        );
      });
    }
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          text: text,
          children: const [
            TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFE53935)),
            ),
          ],
        ),
        style: AppFonts.bodySmall(
          color: AppColors.inkStrong,
        ).copyWith(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  Widget _colorField({
    required String label,
    required Color color,
    required TextEditingController hexController,
    required ValueChanged<Color> onColorChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        Row(
          children: [
            InkWell(
              onTap: _isSaving
                  ? null
                  : () => _pickColor(
                        initial: color,
                        onSelected: onColorChanged,
                        hexController: hexController,
                      ),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppTextField(
                controller: hexController,
                hintText: '#DBEAFE',
                readOnly: _isSaving,
                onChanged: (value) {
                  final parsed = parseHexColor(value);
                  if (parsed != null) {
                    setState(() => onColorChanged(parsed));
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'New project type',
                        style: AppFonts.titleMedium(
                          color: AppColors.inkStrong,
                        ).copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: AppColors.muted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _label('Name'),
                AppTextField(
                  controller: _nameController,
                  hintText: 'e.g. Commercial Installation',
                  readOnly: _isSaving,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _colorField(
                  label: 'Background color',
                  color: _bgColor,
                  hexController: _bgHexController,
                  onColorChanged: (value) {
                    setState(() {
                      _bgColor = value;
                      _syncHex(value, _bgHexController);
                    });
                  },
                ),
                const SizedBox(height: 16),
                _colorField(
                  label: 'Text color',
                  color: _textColor,
                  hexController: _textHexController,
                  onColorChanged: (value) {
                    setState(() {
                      _textColor = value;
                      _syncHex(value, _textHexController);
                    });
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: AppFonts.bodySmall(color: AppColors.error),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.inkStrong,
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _isSaving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF111111),
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
