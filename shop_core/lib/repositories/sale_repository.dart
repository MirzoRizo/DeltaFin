import 'package:shop_core/database_helper.dart';
// Если у тебя модель CartItem лежит в кассе, позже мы перенесем её в core,
// а пока используем сырые данные для сохранения.

class SaleRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Проверка и авто-открытие смены
  Future<void> checkAndOpenShift() async {
    final db = await _dbHelper.database;
    final shiftResult = await db.query(
      'shifts',
      where: 'is_open = ?',
      whereArgs: [1],
    );

    if (shiftResult.isEmpty) {
      await db.insert('shifts', {
        'opened_at': DateTime.now().toIso8601String(),
        'is_open': 1,
      });
    }
  }

  // Сохранение чека (транзакция перенесена из UI)
  Future<int> finalizeSale({
    required double totalAmount,
    required String paymentType,
    required List<Map<String, dynamic>> items, // id товара, количество, цена
  }) async {
    final db = await _dbHelper.database;
    int newSaleId = 0;

    await db.transaction((txn) async {
      final shiftResult = await txn.query(
        'shifts',
        where: 'is_open = ?',
        whereArgs: [1],
        limit: 1,
      );

      if (shiftResult.isEmpty) {
        throw Exception('Смена закрыта. Пожалуйста, откройте смену.');
      }

      int currentShiftId = shiftResult.first['id'] as int;

      newSaleId = await txn.insert('sales', {
        'shift_id': currentShiftId,
        'date': DateTime.now().toIso8601String(),
        'total_amount': totalAmount,
        'payment_type': paymentType,
        'is_synced': 0,
      });

      for (var item in items) {
        await txn.insert('sale_items', {
          'sale_id': newSaleId,
          'product_id': item['product_id'],
          'quantity': item['quantity'],
          'price': item['price'],
          'returned_quantity': 0,
        });

        // Списание остатков
        await txn.rawUpdate(
          'UPDATE products SET stock = stock - ?, popularity = popularity + 1 WHERE id = ?',
          [item['quantity'], item['product_id']],
        );
      }
    });

    return newSaleId;
  }
}
