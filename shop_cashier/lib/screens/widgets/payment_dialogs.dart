import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shop_core/shop_core.dart';
import '../printer_service.dart';

// === ФОРМА ВЫБОРА ОПЛАТЫ ===
class PaymentSelectionForm extends StatelessWidget {
  final double totalAmount;
  final Color premiumColor;

  const PaymentSelectionForm({
    Key? key,
    required this.totalAmount,
    required this.premiumColor,
  }) : super(key: key);

  Widget _buildPaymentButton(
    BuildContext context,
    String text,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: onTap,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedSum = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '',
      decimalDigits: 2,
    ).format(totalAmount);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Оплата',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context, null),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Итого: $formattedSum',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'НАЛИЧНЫМИ',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          Row(
            children: [
              _buildPaymentButton(
                context,
                'Без сдачи',
                premiumColor,
                () => Navigator.pop(context, {
                  'type': 'Наличные',
                  'cash_given': totalAmount,
                  'change': 0.0,
                }),
              ),
              _buildPaymentButton(
                context,
                'Другая сумма',
                premiumColor,
                () async {
                  final result = await showDialog<Map<String, dynamic>>(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SizedBox(
                        width: 600,
                        child: ChangeCalculatorDialog(
                          totalAmount: totalAmount,
                          premiumColor: premiumColor,
                        ),
                      ),
                    ),
                  );
                  if (result != null) Navigator.pop(context, result);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'КАРТОЙ',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          Row(
            children: [
              _buildPaymentButton(
                context,
                'Картой',
                Colors.blue.shade600,
                () => Navigator.pop(context, {
                  'type': 'Карта',
                  'cash_given': totalAmount,
                  'change': 0.0,
                }),
              ),
              _buildPaymentButton(
                context,
                'Безналичная',
                Colors.blue.shade600,
                () => Navigator.pop(context, {
                  'type': 'Безналичные',
                  'cash_given': totalAmount,
                  'change': 0.0,
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// === КАЛЬКУЛЯТОР СДАЧИ ===
class ChangeCalculatorDialog extends StatefulWidget {
  final double totalAmount;
  final Color premiumColor;

  const ChangeCalculatorDialog({
    Key? key,
    required this.totalAmount,
    required this.premiumColor,
  }) : super(key: key);

  @override
  State<ChangeCalculatorDialog> createState() => _ChangeCalculatorDialogState();
}

class _ChangeCalculatorDialogState extends State<ChangeCalculatorDialog> {
  String _inputAmount = '';

  void _onKeyPressed(String val) {
    setState(() {
      if (val == 'C')
        _inputAmount = '';
      else if (val == '⌫') {
        if (_inputAmount.isNotEmpty)
          _inputAmount = _inputAmount.substring(0, _inputAmount.length - 1);
      } else if (val == '.') {
        if (!_inputAmount.contains('.')) _inputAmount += val;
      } else
        _inputAmount += val;
    });
  }

  void _addQuickCash(double amount) =>
      setState(() => _inputAmount = amount.toStringAsFixed(0));

  Widget _buildNumKey(String label, {Color? color}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: InkWell(
          onTap: () => _onKeyPressed(label),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 75,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color ?? Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickCashKey(double amount) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: InkWell(
          onTap: () => _addQuickCash(amount),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              amount.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double enteredAmount = double.tryParse(_inputAmount) ?? 0.0;
    double change = enteredAmount - widget.totalAmount;
    bool canPay = enteredAmount >= widget.totalAmount;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Расчет сдачи',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context, null),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'К ОПЛАТЕ:',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.totalAmount.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'ВНЕСЕНО:',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border.all(color: widget.premiumColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _inputAmount.isEmpty ? '0.00' : _inputAmount,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: canPay ? widget.premiumColor : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'СДАЧА',
                        style: TextStyle(
                          color: canPay ? Colors.white70 : Colors.grey.shade500,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        canPay ? change.toStringAsFixed(2) : '0.00',
                        style: TextStyle(
                          color: canPay ? Colors.white : Colors.grey.shade500,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.premiumColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: canPay
                        ? () => Navigator.pop(context, {
                            'type': 'Наличные',
                            'cash_given': enteredAmount,
                            'change': change,
                          })
                        : null,
                    child: const Text(
                      'ОПЛАТИТЬ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _buildQuickCashKey(50),
                    _buildQuickCashKey(100),
                    _buildQuickCashKey(200),
                    _buildQuickCashKey(500),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  children: [
                    Row(
                      children: [
                        _buildNumKey('7'),
                        _buildNumKey('8'),
                        _buildNumKey('9'),
                      ],
                    ),
                    Row(
                      children: [
                        _buildNumKey('4'),
                        _buildNumKey('5'),
                        _buildNumKey('6'),
                      ],
                    ),
                    Row(
                      children: [
                        _buildNumKey('1'),
                        _buildNumKey('2'),
                        _buildNumKey('3'),
                      ],
                    ),
                    Row(
                      children: [
                        _buildNumKey('C', color: Colors.red.shade100),
                        _buildNumKey('0'),
                        _buildNumKey('⌫', color: Colors.orange.shade100),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// === ВИЗУАЛЬНЫЙ ДВИЖОК ЧЕКА ===
class ReceiptPreviewDialog extends StatelessWidget {
  final int saleId;
  final List<CartItem> cartItems;
  final double totalAmount;
  final String paymentType;
  final double cashGiven;
  final double change;
  final Color premiumColor;

  const ReceiptPreviewDialog({
    Key? key,
    required this.saleId,
    required this.cartItems,
    required this.totalAmount,
    required this.paymentType,
    required this.cashGiven,
    required this.change,
    required this.premiumColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());
    return Center(
      child: Container(
        width: 350,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'РАШТ ЭКСПРЕСС КАРГО',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Кассовый чек',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontFamily: 'Courier'),
            ),
            Text(
              'Чек №: ${saleId.toString().padLeft(5, '0')}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontFamily: 'Courier'),
            ),
            Text(
              'Дата: $dateStr',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontFamily: 'Courier'),
            ),
            const SizedBox(height: 16),
            const Text(
              '--------------------------------',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Courier', color: Colors.grey),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: cartItems.length,
                itemBuilder: (context, index) {
                  final item = cartItems[index];
                  String displayQty = item.product.isWeight
                      ? item.quantity.toStringAsFixed(3)
                      : item.quantity.toInt().toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Courier',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$displayQty x ${item.product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Courier',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          item.total.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Courier',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '--------------------------------',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Courier', color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ИТОГО:',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Courier',
                  ),
                ),
                Text(
                  totalAmount.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Courier',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ОПЛАТА ($paymentType):',
                  style: const TextStyle(fontSize: 14, fontFamily: 'Courier'),
                ),
                Text(
                  cashGiven.toStringAsFixed(2),
                  style: const TextStyle(fontSize: 14, fontFamily: 'Courier'),
                ),
              ],
            ),
            if (change > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'СДАЧА:',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    change.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            const Text(
              'СПАСИБО ЗА ПОКУПКУ!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: premiumColor),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Новый чек',
                      style: TextStyle(
                        color: premiumColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: premiumColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ищем принтер...')),
                      );
                      List<Map<String, dynamic>> itemsForPrinter = cartItems
                          .map(
                            (item) => {
                              'name': item.product.name,
                              'qty': item.product.isWeight
                                  ? item.quantity.toStringAsFixed(3)
                                  : item.quantity.toInt().toString(),
                              'price': item.product.price.toStringAsFixed(2),
                              'total': item.total.toStringAsFixed(2),
                            },
                          )
                          .toList();
                      String status = await PrinterService.instance
                          .printReceipt(
                            saleId: saleId,
                            items: itemsForPrinter,
                            totalAmount: totalAmount,
                            cashGiven: cashGiven,
                            change: change,
                            paymentType: paymentType,
                          );
                      if (status == "OK")
                        Navigator.pop(context);
                      else
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('🛑 Ошибка: $status'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                    },
                    child: const Text(
                      'Печать',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
