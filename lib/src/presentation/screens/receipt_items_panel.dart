import 'package:flutter/material.dart';

import '../../application/formatters/minor_units_text.dart';
import '../../application/use_cases/update_receipt_items.dart';
import '../../domain/models/receipt_item.dart';
import '../../domain/models/receipt_qr_draft.dart';

final class ReceiptItemsPanel extends StatefulWidget {
  const ReceiptItemsPanel({
    required this.receipt,
    required this.budgetId,
    this.updateItems,
    super.key,
  });

  final ReceiptQrDraft receipt;
  final String budgetId;
  final UpdateReceiptItems? updateItems;

  @override
  State<ReceiptItemsPanel> createState() => _ReceiptItemsPanelState();
}

final class _ReceiptItemsPanelState extends State<ReceiptItemsPanel> {
  late List<ReceiptItem> _items;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _items = widget.receipt.items;
  }

  @override
  void didUpdateWidget(covariant ReceiptItemsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.receipt.receiptId != widget.receipt.receiptId) {
      _items = widget.receipt.items;
    }
  }

  Future<void> _save(List<ReceiptItem> items) async {
    final update = widget.updateItems;
    if (update == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await update(
        budgetId: widget.budgetId,
        receiptId: widget.receipt.receiptId,
        items: items,
      );
      if (mounted) setState(() => _items = saved.items);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Не удалось сохранить товары чека.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit(int? index) async {
    final item = await showDialog<ReceiptItem>(
      context: context,
      builder: (_) =>
          _ReceiptItemDialog(initial: index == null ? null : _items[index]),
    );
    if (item == null || !mounted) return;
    final next = [..._items];
    if (index == null) {
      next.add(item);
    } else {
      next[index] = item;
    }
    await _save(next);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.receipt.totalMinor;
    final complete =
        _items.isNotEmpty &&
        _items.every((item) => item.lineTotalMinor != null);
    final itemTotal = complete
        ? _items.fold<BigInt>(
            BigInt.zero,
            (sum, item) => sum + item.lineTotalMinor!,
          )
        : null;
    final difference = total != null && itemTotal != null
        ? total - itemTotal
        : null;

    return Card(
      key: const ValueKey('receipt-items-panel'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Товары в чеке',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_items.isEmpty)
              const Text(
                'Список товаров недоступен. Сумму и дату можно проверить и сохранить вручную.',
                key: ValueKey('receipt-items-unavailable'),
              ),
            for (var index = 0; index < _items.length; index++)
              ListTile(
                key: ValueKey('receipt-item-$index'),
                contentPadding: EdgeInsets.zero,
                title: Text(_items[index].name),
                subtitle: Text(
                  '${_quantityText(_items[index].quantity)} × '
                  '${_amountText(_items[index].unitPriceMinor)} · '
                  '${_items[index].source == 'ocr' ? 'OCR' : 'Введено вручную'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_amountText(_items[index].lineTotalMinor)),
                    IconButton(
                      key: ValueKey('edit-receipt-item-$index'),
                      tooltip: 'Исправить товар',
                      onPressed: _saving || widget.updateItems == null
                          ? null
                          : () => _edit(index),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      key: ValueKey('remove-receipt-item-$index'),
                      tooltip: 'Не использовать товар',
                      onPressed: _saving || widget.updateItems == null
                          ? null
                          : () => _save([
                              ..._items.take(index),
                              ..._items.skip(index + 1),
                            ]),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            if (itemTotal != null)
              Text(
                'Сумма товаров: ${_amountText(itemTotal)}',
                key: const ValueKey('receipt-items-total'),
              ),
            if (total != null) Text('Сумма чека: ${_amountText(total)}'),
            if (difference != null && difference != BigInt.zero)
              Text(
                'Расхождение: ${_amountText(difference)}',
                key: const ValueKey('receipt-items-difference'),
              ),
            if (_error != null)
              Text(_error!, key: const ValueKey('receipt-items-error')),
            if (widget.updateItems != null)
              TextButton.icon(
                key: const ValueKey('add-receipt-item'),
                onPressed: _saving ? null : () => _edit(null),
                icon: const Icon(Icons.add),
                label: const Text('Добавить товар'),
              ),
          ],
        ),
      ),
    );
  }
}

String _amountText(BigInt? amount) =>
    amount == null ? '—' : formatMinorUnits(amount);

String _quantityText(double quantity) => quantity == quantity.roundToDouble()
    ? quantity.toInt().toString()
    : quantity.toString();

final class _ReceiptItemDialog extends StatefulWidget {
  const _ReceiptItemDialog({this.initial});

  final ReceiptItem? initial;

  @override
  State<_ReceiptItemDialog> createState() => _ReceiptItemDialogState();
}

final class _ReceiptItemDialogState extends State<_ReceiptItemDialog> {
  late final TextEditingController _name;
  late final TextEditingController _quantity;
  late final TextEditingController _unitPrice;
  late final TextEditingController _lineTotal;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _quantity = TextEditingController(
      text: _quantityText(initial?.quantity ?? 1),
    );
    _unitPrice = TextEditingController(
      text: initial?.unitPriceMinor == null
          ? ''
          : formatMinorUnits(initial!.unitPriceMinor!),
    );
    _lineTotal = TextEditingController(
      text: initial?.lineTotalMinor == null
          ? ''
          : formatMinorUnits(initial!.lineTotalMinor!),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    _lineTotal.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final name = _name.text.trim();
      final quantity = double.parse(_quantity.text.replaceAll(',', '.'));
      final unitPrice = _unitPrice.text.trim().isEmpty
          ? null
          : parseMinorUnitsText(_unitPrice.text);
      final lineTotal = _lineTotal.text.trim().isEmpty
          ? null
          : parseMinorUnitsText(_lineTotal.text);
      if (name.isEmpty ||
          quantity <= 0 ||
          !quantity.isFinite ||
          (unitPrice != null && unitPrice < BigInt.zero) ||
          (lineTotal != null && lineTotal < BigInt.zero)) {
        throw const FormatException();
      }
      Navigator.pop(
        context,
        ReceiptItem(
          name: name,
          quantity: quantity,
          unitPriceMinor: unitPrice,
          lineTotalMinor: lineTotal,
          currencyCode: widget.initial?.currencyCode,
          source: 'manual',
        ),
      );
    } on Object {
      setState(() => _error = 'Проверьте название, количество и суммы.');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Добавить товар' : 'Исправить товар'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('receipt-item-name'),
            controller: _name,
            decoration: const InputDecoration(labelText: 'Товар'),
          ),
          TextField(
            key: const ValueKey('receipt-item-quantity'),
            controller: _quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Количество'),
          ),
          TextField(
            key: const ValueKey('receipt-item-unit-price'),
            controller: _unitPrice,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Цена за единицу'),
          ),
          TextField(
            key: const ValueKey('receipt-item-line-total'),
            controller: _lineTotal,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Сумма строки'),
          ),
          if (_error != null)
            Text(_error!, key: const ValueKey('receipt-item-dialog-error')),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        key: const ValueKey('receipt-item-save'),
        onPressed: _submit,
        child: const Text('Сохранить'),
      ),
    ],
  );
}
