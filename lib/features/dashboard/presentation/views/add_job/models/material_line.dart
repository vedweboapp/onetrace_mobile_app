part of '../add_job.dart';

class _MaterialLine {
  _MaterialLine()
    : sectionController = TextEditingController(
        text: 'Main Electrical Panel',
      ),
      qtyController = TextEditingController(text: '1'),
      priceController = TextEditingController();

  final TextEditingController sectionController;
  CompositeItemOption? compositeItem;
  final TextEditingController qtyController;
  final TextEditingController priceController;

  String get sectionName => sectionController.text.trim();

  double get quantity {
    return double.tryParse(qtyController.text.trim()) ?? 0;
  }

  double get unitPrice {
    final raw = priceController.text.trim().replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(raw) ?? 0;
  }

  double get lineTotal => quantity * unitPrice;

  void applyCompositeItem(CompositeItemOption? item) {
    compositeItem = item;
    if (item == null) {
      priceController.clear();
      return;
    }
    final price = item.sellingPrice;
    if (price != null) {
      priceController.text = price.toStringAsFixed(2);
    } else {
      priceController.clear();
    }
    final qty = item.quantity;
    qtyController.text =
        qty == qty.roundToDouble() ? qty.round().toString() : qty.toString();
  }

  void dispose() {
    sectionController.dispose();
    qtyController.dispose();
    priceController.dispose();
  }
}
