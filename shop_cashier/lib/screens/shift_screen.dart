import 'package:flutter/material.dart';
import 'package:shop_core/shop_core.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

class ShiftScreen extends StatefulWidget {
  const ShiftScreen({Key? key}) : super(key: key);
  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends State<ShiftScreen> {
  final Color _premiumGreen = const Color(0xFF0A7B54);

  bool _isLoading = true;
  Map<String, dynamic>? _activeShift;
  int _salesCount = 0;
  int _returnsCount = 0;
  double _grossSalesTotal = 0;
  double _returnsTotal = 0;
  double _depositsTotal = 0;
  double _withdrawalsTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadShiftData();
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

  Future<void> _loadShiftData() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final shiftResult = await db.query(
        'shifts',
        where: 'is_open = ?',
        whereArgs: [1],
        limit: 1,
      );

      if (shiftResult.isNotEmpty) {
        _activeShift = shiftResult.first;
        int shiftId = _activeShift!['id'];
        final salesRawResult = await db.rawQuery(
          'SELECT COUNT(DISTINCT s.id) as count, SUM(si.quantity * si.price) as total FROM sales s JOIN sale_items si ON s.id = si.sale_id WHERE s.shift_id = ?',
          [shiftId],
        );
        _salesCount = (salesRawResult.first['count'] as int?) ?? 0;
        _grossSalesTotal = (salesRawResult.first['total'] as double?) ?? 0.0;
        final returnsRawResult = await db.rawQuery(
          'SELECT SUM(si.returned_quantity * si.price) as total FROM sale_items si JOIN sales s ON si.sale_id = s.id WHERE s.shift_id = ? AND si.returned_quantity > 0',
          [shiftId],
        );
        _returnsTotal = (returnsRawResult.first['total'] as double?) ?? 0.0;
        final returnsCountRaw = await db.rawQuery(
          "SELECT COUNT(id) as count FROM cash_operations WHERE shift_id = ? AND type LIKE 'Возврат:%'",
          [shiftId],
        );
        _returnsCount = (returnsCountRaw.first['count'] as int?) ?? 0;
        final depResult = await db.rawQuery(
          'SELECT SUM(amount) as total FROM cash_operations WHERE shift_id = ? AND type = ?',
          [shiftId, 'Внесение'],
        );
        _depositsTotal = (depResult.first['total'] as double?) ?? 0.0;
        final withResult = await db.rawQuery(
          'SELECT SUM(amount) as total FROM cash_operations WHERE shift_id = ? AND type = ?',
          [shiftId, 'Выплата'],
        );
        _withdrawalsTotal = ((withResult.first['total'] as double?) ?? 0.0)
            .abs();
      } else {
        _activeShift = null;
        _salesCount = 0;
        _returnsCount = 0;
        _grossSalesTotal = 0;
        _returnsTotal = 0;
        _depositsTotal = 0;
        _withdrawalsTotal = 0;
      }
    } catch (e) {
      _showErrorDialog('Ошибка', 'Не удалось загрузить данные смены: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _openShift() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('shifts', {
        'opened_at': DateTime.now().toIso8601String(),
        'is_open': 1,
      });
      _loadShiftData();
    } catch (e) {
      _showErrorDialog('Ошибка', 'Не удалось открыть смену: $e');
    }
  }

  // === АВТО-БЭКАП ПРИ ЗАКРЫТИИ СМЕНЫ ===
  Future<void> _closeShift() async {
    if (_activeShift == null) return;
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'shifts',
        {'closed_at': DateTime.now().toIso8601String(), 'is_open': 0},
        where: 'id = ?',
        whereArgs: [_activeShift!['id']],
      );

      // КОПИРУЕМ БАЗУ ДАННЫХ
      try {
        final String dbPath = db.path;
        final String backupDirPath = p.join(
          'C:\\ProgramData\\ShopSystem',
          'Backups',
        );
        final backupDir = Directory(backupDirPath);
        if (!await backupDir.exists()) await backupDir.create(recursive: true);

        final String dateStr = DateFormat(
          'yyyy-MM-dd_HH-mm',
        ).format(DateTime.now());
        final String backupFilePath = p.join(
          backupDirPath,
          'shop_core_backup_$dateStr.db',
        );

        await File(dbPath).copy(backupFilePath);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Смена закрыта. Копия базы сохранена (бэкап)!'),
            backgroundColor: _premiumGreen,
            duration: const Duration(seconds: 4),
          ),
        );
      } catch (backupError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Смена закрыта, но создать бэкап не удалось: $backupError',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      _loadShiftData();
    } catch (e) {
      _showErrorDialog('Ошибка', 'Не удалось закрыть смену: $e');
    }
  }

  Future<void> _showCashOperationDialog(String type) async {
    final controller = TextEditingController();
    bool isDeposit = type == 'Внесение';
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isDeposit ? 'Внести деньги' : 'Выплатить деньги',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Сумма',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _premiumGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
    final amount = double.tryParse(controller.text.replaceAll(',', '.'));
    if (amount != null && amount > 0) {
      try {
        final db = await DatabaseHelper.instance.database;
        await db.insert('cash_operations', {
          'shift_id': _activeShift!['id'],
          'type': type,
          'amount': isDeposit ? amount : -amount,
          'created_at': DateTime.now().toIso8601String(),
        });
        _loadShiftData();
      } catch (e) {
        _showErrorDialog('Ошибка', 'Не удалось сохранить операцию: $e');
      }
    }
  }

  Widget _buildSummaryRow(
    String title,
    double amount, {
    bool isBold = false,
    bool isGrey = false,
    String? count,
    bool isRed = false,
  }) {
    Color textColor = isRed
        ? Colors.red
        : (isGrey ? Colors.grey : Colors.black);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: TextStyle(
                fontSize: isBold ? 18 : 16,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: textColor,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: count != null
                ? Text(
                    count,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  )
                : const SizedBox(),
          ),
          Text(
            '${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isBold ? 18 : 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isShiftOpen = _activeShift != null;
    double cashInTill =
        _grossSalesTotal - _returnsTotal + _depositsTotal - _withdrawalsTotal;
    double netSales = _grossSalesTotal - _returnsTotal;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isShiftOpen ? 'Смена открыта' : 'Смена закрыта',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadShiftData,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isShiftOpen)
                        ElevatedButton(
                          onPressed: _closeShift,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade400,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Закрыть смену',
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        ElevatedButton(
                          onPressed: _openShift,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _premiumGreen,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Открыть смену',
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: isShiftOpen
                            ? () => _showCashOperationDialog('Внесение')
                            : null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: isShiftOpen ? _premiumGreen : Colors.grey,
                          ),
                        ),
                        child: Text(
                          'Внести деньги',
                          style: TextStyle(
                            fontSize: 18,
                            color: isShiftOpen ? _premiumGreen : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: isShiftOpen
                            ? () => _showCashOperationDialog('Выплата')
                            : null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: isShiftOpen
                                ? Colors.red.shade400
                                : Colors.grey,
                          ),
                        ),
                        child: Text(
                          'Выплатить деньги',
                          style: TextStyle(
                            fontSize: 18,
                            color: isShiftOpen
                                ? Colors.red.shade400
                                : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSummaryRow(
                        'Продажи',
                        _grossSalesTotal,
                        isBold: true,
                        count: _salesCount.toString(),
                      ),
                      _buildSummaryRow(
                        'Наличными:',
                        _grossSalesTotal,
                        isGrey: true,
                      ),
                      _buildSummaryRow('Безналичными:', 0.00, isGrey: true),
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        'Возвраты',
                        _returnsTotal,
                        isBold: true,
                        count: _returnsCount.toString(),
                        isRed: _returnsTotal > 0,
                      ),
                      _buildSummaryRow(
                        'Наличными:',
                        _returnsTotal,
                        isGrey: true,
                        isRed: _returnsTotal > 0,
                      ),
                      _buildSummaryRow('Безналичными:', 0.00, isGrey: true),
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        'Внесения',
                        _depositsTotal,
                        isBold: true,
                      ),
                      _buildSummaryRow(
                        'Выплаты',
                        _withdrawalsTotal,
                        isBold: true,
                      ),
                      const SizedBox(height: 8),
                      _buildSummaryRow('Выручка', netSales, isBold: true),
                      _buildSummaryRow('Наличными:', netSales, isGrey: true),
                      _buildSummaryRow('Безналичными:', 0.00, isGrey: true),
                      const SizedBox(height: 24),
                      const Divider(thickness: 2),
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        'Денег в кассе',
                        cashInTill,
                        isBold: true,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
