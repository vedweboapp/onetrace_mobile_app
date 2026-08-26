part of '../add_purchase_order.dart';

class _PurchaseLineDraft {
  _PurchaseLineDraft();

  CompositeItemOption? product;
  final qtyController = TextEditingController(text: '1');
  final unitPriceController = TextEditingController();

  double get quantity => double.tryParse(qtyController.text.trim()) ?? 0;

  double get unitPrice => double.tryParse(unitPriceController.text.trim()) ?? 0;

  double get lineTotal =>
      product == null ? 0 : quantity * unitPrice;

  void applyProduct(CompositeItemOption? item) {
    product = item;
    if (item == null) {
      unitPriceController.clear();
      return;
    }
    final qty = item.quantity > 0 ? item.quantity : 1;
    qtyController.text = qty == qty.roundToDouble()
        ? qty.round().toString()
        : qty.toString();
    final price = item.sellingPrice;
    if (price != null) {
      unitPriceController.text = price.toStringAsFixed(2);
    } else {
      unitPriceController.clear();
    }
  }

  void dispose() {
    qtyController.dispose();
    unitPriceController.dispose();
  }
}
