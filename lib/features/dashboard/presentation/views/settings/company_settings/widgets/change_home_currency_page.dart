part of '../company_settings.dart';

class _ChangeHomeCurrencyPage extends StatefulWidget {
  const _ChangeHomeCurrencyPage({required this.initial, required this.options});

  final HomeCurrencySettings initial;
  final List<String> options;

  @override
  State<_ChangeHomeCurrencyPage> createState() =>
      _ChangeHomeCurrencyPageState();
}

class _ChangeHomeCurrencyPageState extends State<_ChangeHomeCurrencyPage> {
  static const _labelGrey = Color(0xFF6B7280);
  static const _fieldBorder = Color(0xFFE5E7EB);
  static const _fieldFill = Color(0xFFF9FAFB);
  static const _toggleBg = Color(0xFFE5E7EB);

  static const _symbolPositions = <String>['Before Value', 'After Value'];

  static const _digitSeparators = <String>[
    '12,34,567.89',
    '1,234,567.89',
    '1.234.567,89',
  ];

  late String _homeCurrency;
  late CurrencyFormatMode _formatMode;
  late String _symbolPosition;
  late String _digitSeparator;
  late final TextEditingController _symbolController;
  late final TextEditingController _decimalPlacesController;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _homeCurrency = widget.options.contains(s.homeCurrency)
        ? s.homeCurrency
        : widget.options.first;
    _formatMode = s.formatMode;
    _symbolPosition = _symbolPositions.contains(s.symbolPosition)
        ? s.symbolPosition
        : _symbolPositions.first;
    _digitSeparator = _digitSeparators.contains(s.digitSeparator)
        ? s.digitSeparator
        : _digitSeparators.first;
    _symbolController = TextEditingController(text: s.symbol);
    _decimalPlacesController = TextEditingController(
      text: s.decimalPlaces.toString(),
    );
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _decimalPlacesController.dispose();
    super.dispose();
  }

  HomeCurrencySettings get _draft => HomeCurrencySettings(
    homeCurrency: _homeCurrency,
    formatMode: _formatMode,
    symbol: _symbolController.text.trim().isEmpty
        ? HomeCurrencySettings.defaultSymbolFor(_homeCurrency)
        : _symbolController.text.trim(),
    symbolPosition: _symbolPosition,
    digitSeparator: _digitSeparator,
    decimalPlaces: int.tryParse(_decimalPlacesController.text.trim()) ?? 2,
  );

  InputDecoration _inputDecoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: AppColors.textFieldFocusBorder,
          width: 1.2,
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppFonts.bodyMedium(
          color: _labelGrey,
        ).copyWith(fontWeight: FontWeight.w500, fontSize: 13),
      ),
    );
  }

  Widget _formatModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _toggleBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FormatModeChip(
              label: 'Symbol',
              selected: _formatMode == CurrencyFormatMode.symbol,
              onTap: () =>
                  setState(() => _formatMode = CurrencyFormatMode.symbol),
            ),
          ),
          Expanded(
            child: _FormatModeChip(
              label: 'Code',
              selected: _formatMode == CurrencyFormatMode.code,
              onTap: () =>
                  setState(() => _formatMode = CurrencyFormatMode.code),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewBox() {
    return DottedBorder(
      options: RoundedRectDottedBorderOptions(
        radius: const Radius.circular(12),
        strokeWidth: 1.4,
        color: const Color(0xFFD1D5DB),
        dashPattern: const [5, 4],
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: const Color(0xFFF9FAFB),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _fieldBorder),
              ),
              child: const Icon(
                Icons.visibility_outlined,
                color: Color(0xFF6B7280),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PREVIEW',
                    style: AppFonts.labelMedium(color: _labelGrey).copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _draft.formatPreview(),
                    style: AppFonts.headlineSmall(
                      color: AppColors.inkStrong,
                    ).copyWith(fontWeight: FontWeight.w800, fontSize: 24),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirm() {
    Navigator.of(context).pop(_draft);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          'Change Home Currency',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: AppColors.inkStrong),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              children: [
                _fieldLabel('Home Currency'),
                InputDecorator(
                  decoration: _inputDecoration(),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _homeCurrency,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF6B7280),
                      ),
                      style: AppFonts.bodyMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w500, fontSize: 15),
                      dropdownColor: AppColors.white,
                      items: widget.options
                          .map(
                            (e) => DropdownMenuItem<String>(
                              value: e,
                              child: Text(e),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _homeCurrency = v;
                          _symbolController.text =
                              HomeCurrencySettings.defaultSymbolFor(v);
                          _digitSeparator =
                              HomeCurrencySettings.defaultSeparatorFor(v);
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [_fieldLabel('Format'), _formatModeToggle()],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _fieldLabel('Symbol'),
                          TextField(
                            controller: _symbolController,
                            enabled: _formatMode == CurrencyFormatMode.symbol,
                            onChanged: (_) => setState(() {}),
                            style:
                                AppFonts.bodyMedium(
                                  color: AppColors.inkStrong,
                                ).copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                            decoration: _inputDecoration(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _fieldLabel('Symbol Position'),
                InputDecorator(
                  decoration: _inputDecoration(),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _symbolPosition,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF6B7280),
                      ),
                      style: AppFonts.bodyMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w500, fontSize: 15),
                      items: _symbolPositions
                          .map(
                            (e) => DropdownMenuItem<String>(
                              value: e,
                              child: Text(e),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _symbolPosition = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _fieldLabel('Digit Separators'),
                          InputDecorator(
                            decoration: _inputDecoration(),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _digitSeparator,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF6B7280),
                                  size: 20,
                                ),
                                style:
                                    AppFonts.bodyMedium(
                                      color: AppColors.inkStrong,
                                    ).copyWith(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                items: _digitSeparators
                                    .map(
                                      (e) => DropdownMenuItem<String>(
                                        value: e,
                                        child: Text(
                                          e,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _digitSeparator = v);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _fieldLabel('Decimal Places'),
                          TextField(
                            controller: _decimalPlacesController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(1),
                            ],
                            onChanged: (_) => setState(() {}),
                            style:
                                AppFonts.bodyMedium(
                                  color: AppColors.inkStrong,
                                ).copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                            decoration: _inputDecoration(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _previewBox(),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _confirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.inkStrong,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Confirm Changes',
                      style: AppFonts.labelLarge(
                        color: Colors.white,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.inkStrong,
                      side: const BorderSide(color: _fieldBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: AppFonts.labelLarge(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

