import 'package:flutter/material.dart';
import 'package:shop_core/shop_core.dart';
import 'package:intl/intl.dart';

class HistoryEvent {
  final int id;
  final String title;
  final String dateStr;
  final double amount;
  final String type;
  final int? refSaleId;
  HistoryEvent({
    required this.id,
    required this.title,
    required this.dateStr,
    required this.amount,
    required this.type,
    this.refSaleId,
  });
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final Color _premiumGreen = const Color(0xFF0A7B54);
  bool _isLoading = true;
  List<HistoryEvent> _events = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _premiumGreen),
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      List<HistoryEvent> loadedEvents = [];

      final sales = await db.query('sales');
      for (var s in sales) {
        loadedEvents.add(
          HistoryEvent(
            id: s['id'] as int,
            title: 'Продажа №${s['id'].toString().padLeft(5, '0')}',
            dateStr: s['date'] as String,
            amount: s['total_amount'] as double,
            type: 'sale',
            refSaleId: s['id'] as int,
          ),
        );
      }

      final ops = await db.query('cash_operations');
      for (var op in ops) {
        String rawType = op['type'] as String;
        if (rawType.startsWith('Возврат:')) {
          int refId = int.parse(rawType.split(':')[1]);
          loadedEvents.add(
            HistoryEvent(
              id: op['id'] as int,
              title: 'Возврат №${op['id'].toString().padLeft(5, '0')}',
              dateStr: op['created_at'] as String,
              amount: op['amount'] as double,
              type: 'return',
              refSaleId: refId,
            ),
          );
        } else {
          bool isDeposit = rawType == 'Внесение';
          loadedEvents.add(
            HistoryEvent(
              id: op['id'] as int,
              title: '$rawType №${op['id'].toString().padLeft(5, '0')}',
              dateStr: op['created_at'] as String,
              amount: op['amount'] as double,
              type: isDeposit ? 'deposit' : 'withdrawal',
            ),
          );
        }
      }

      final shifts = await db.query('shifts');
      for (var sh in shifts) {
        loadedEvents.add(
          HistoryEvent(
            id: sh['id'] as int,
            title: 'Смена №${sh['id'].toString().padLeft(5, '0')} • Открыта',
            dateStr: sh['opened_at'] as String,
            amount: 0,
            type: 'shift_open',
          ),
        );
      }

      loadedEvents.sort(
        (a, b) =>
            DateTime.parse(b.dateStr).compareTo(DateTime.parse(a.dateStr)),
      );
      setState(() {
        _events = loadedEvents;
        _isLoading = false;
      });
    } catch (e) {
      _showErrorDialog('Ошибка', 'Не удалось загрузить историю: $e');
      setState(() => _isLoading = false);
    }
  }

  void _openDetails(HistoryEvent event) async {
    if (event.type == 'sale' || event.type == 'return') {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SaleDetailsScreen(saleId: event.refSaleId!),
        ),
      );
      if (result == true) _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'История/Возврат',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadHistory,
            tooltip: 'Обновить',
          ),
        ], // КНОПКА ОБНОВИТЬ
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  itemCount: _events.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.grey.shade300,
                  ),
                  itemBuilder: (context, index) {
                    final ev = _events[index];
                    bool isReturn = ev.type == 'return';
                    bool isShift = ev.type == 'shift_open';
                    String amountText = !isShift
                        ? ((isReturn || ev.type == 'withdrawal')
                              ? '-${ev.amount.toStringAsFixed(2)}'
                              : ev.amount.toStringAsFixed(2))
                        : '';

                    return Container(
                      color: isShift ? Colors.grey.shade100 : Colors.white,
                      child: ListTile(
                        title: Text(
                          ev.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          '${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(ev.dateStr))} • Администратор',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: isShift
                            ? null
                            : Text(
                                amountText,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                        onTap: () => _openDetails(ev),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

// === ОСТАЛЬНОЙ КОД ДЛЯ ЧЕКОВ (Без изменений) ===
class SaleDetailsScreen extends StatefulWidget {
  final int saleId;
  const SaleDetailsScreen({super.key, required this.saleId});
  @override
  State<SaleDetailsScreen> createState() => _SaleDetailsScreenState();
}

class _SaleDetailsScreenState extends State<SaleDetailsScreen> {
  final Color _premiumGreen = const Color(0xFF0A7B54);
  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];
  double _saleTotal = 0;
  double _returnedTotal = 0;
  String _paymentType = 'Наличными';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT si.product_id, si.quantity, si.returned_quantity, si.price, p.name FROM sale_items si JOIN products p ON si.product_id = p.id WHERE si.sale_id = ?',
      [widget.saleId],
    );
    final saleResult = await db.query(
      'sales',
      where: 'id = ?',
      whereArgs: [widget.saleId],
      limit: 1,
    );
    if (saleResult.isNotEmpty) {
      _paymentType = saleResult.first['payment_type'] as String;
    }

    double sTotal = 0;
    double rTotal = 0;
    for (var row in result) {
      sTotal += (row['quantity'] as num) * (row['price'] as num);
      rTotal += (row['returned_quantity'] as num) * (row['price'] as num);
    }
    setState(() {
      _items = result;
      _saleTotal = sTotal;
      _returnedTotal = rTotal;
      _isLoading = false;
    });
  }

  void _goToPartialReturn() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PartialReturnScreen(saleId: widget.saleId, items: _items),
      ),
    );
    if (result == true) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    bool canReturnMore = _items.any(
      (item) => (item['quantity'] - item['returned_quantity']) > 0,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Продажа №${widget.saleId.toString().padLeft(5, '0')}',
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (canReturnMore)
                      OutlinedButton(
                        onPressed: _goToPartialReturn,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: _premiumGreen),
                        ),
                        child: Text(
                          'Создать возврат',
                          style: TextStyle(fontSize: 18, color: _premiumGreen),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Text(
                          'ТОВАРЫ ВОЗВРАЩЕНЫ',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    ..._items.map((item) {
                      double total = item['quantity'] * item['price'];
                      double retQty = item['returned_quantity'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${item['quantity']} x ${item['price'].toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                if (retQty > 0)
                                  Text(
                                    'Оформлен возврат: $retQty шт.',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              total.toStringAsFixed(2),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    }).toList(),

                    const Divider(thickness: 1, color: Colors.grey),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Итого продажа:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _saleTotal.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (_returnedTotal > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'В том числе возврат:',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '-${_returnedTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Тип оплаты:',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          _paymentType,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Кассир:',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        Text(
                          'Администратор',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
        ),
      ),
    );
  }
}

class PartialReturnScreen extends StatefulWidget {
  final int saleId;
  final List<Map<String, dynamic>> items;
  const PartialReturnScreen({
    Key? key,
    required this.saleId,
    required this.items,
  }) : super(key: key);
  @override
  State<PartialReturnScreen> createState() => _PartialReturnScreenState();
}

class _PartialReturnScreenState extends State<PartialReturnScreen> {
  final Color _premiumGreen = const Color(0xFF0A7B54);
  Map<int, double> _returnQuantities = {};
  @override
  void initState() {
    super.initState();
    for (var item in widget.items) {
      _returnQuantities[item['product_id']] = 0.0;
    }
  }

  void _increment(int productId, double maxAvailable) {
    setState(() {
      if (_returnQuantities[productId]! < maxAvailable) {
        _returnQuantities[productId] = _returnQuantities[productId]! + 1;
      }
    });
  }

  void _decrement(int productId) {
    setState(() {
      if (_returnQuantities[productId]! > 0) {
        _returnQuantities[productId] = _returnQuantities[productId]! - 1;
      }
    });
  }

  double get _totalReturnAmount {
    double total = 0;
    for (var item in widget.items) {
      total += (_returnQuantities[item['product_id']] ?? 0) * item['price'];
    }
    return total;
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _premiumGreen),
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _processReturn() async {
    if (_totalReturnAmount <= 0) return;
    try {
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        final shiftResult = await txn.query(
          'shifts',
          where: 'is_open = ?',
          whereArgs: [1],
          limit: 1,
        );
        int currentShiftId = shiftResult.isNotEmpty
            ? shiftResult.first['id'] as int
            : 0;
        for (var item in widget.items) {
          int productId = item['product_id'];
          double retQty = _returnQuantities[productId] ?? 0;
          if (retQty > 0) {
            await txn.rawUpdate(
              'UPDATE sale_items SET returned_quantity = returned_quantity + ? WHERE sale_id = ? AND product_id = ?',
              [retQty, widget.saleId, productId],
            );
            await txn.rawUpdate(
              'UPDATE products SET stock = stock + ? WHERE id = ?',
              [retQty, productId],
            );
          }
        }
        await txn.insert('cash_operations', {
          'shift_id': currentShiftId,
          'type': 'Возврат:${widget.saleId}',
          'amount': _totalReturnAmount,
          'created_at': DateTime.now().toIso8601String(),
        });
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Возврат успешно оформлен!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showErrorDialog('Ошибка', 'Не удалось оформить возврат: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Новый Возврат',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    int productId = item['product_id'];
                    double available =
                        item['quantity'] - item['returned_quantity'];
                    double currentRet = _returnQuantities[productId] ?? 0;
                    if (available <= 0) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.blue.shade50,
                                      child: Text(
                                        item['name'].substring(0, 2),
                                        style: TextStyle(color: _premiumGreen),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['name'],
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            'Доступно: ${available.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                item['price'].toStringAsFixed(2),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'КОЛИЧЕСТВО',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _decrement(productId),
                                  child: Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: currentRet > 0
                                          ? _premiumGreen
                                          : Colors.grey.shade400,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(4),
                                        bottomLeft: Radius.circular(4),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.remove,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border.symmetric(
                                      horizontal: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    currentRet.toStringAsFixed(0),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _increment(productId, available),
                                  child: Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: currentRet < available
                                          ? _premiumGreen
                                          : Colors.grey.shade400,
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(4),
                                        bottomRight: Radius.circular(4),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _totalReturnAmount > 0 ? _processReturn : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _premiumGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                    child: Text(
                      'К возврату: ${_totalReturnAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
