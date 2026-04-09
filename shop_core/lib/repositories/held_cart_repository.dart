import 'package:shop_core/database_helper.dart';

class HeldCartRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Сохранить чек в "отложенные"
  Future<void> holdCart(
    double totalAmount,
    List<Map<String, dynamic>> items,
  ) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final heldId = await txn.insert('held_carts', {
        'date': DateTime.now().toIso8601String(),
        'total_amount': totalAmount,
      });

      for (var item in items) {
        await txn.insert('held_cart_items', {
          'held_cart_id': heldId,
          'product_id': item['product_id'],
          'quantity': item['quantity'],
        });
      }
    });
  }

  // Получить список всех отложенных чеков (шапки)
  Future<List<Map<String, dynamic>>> getHeldCarts() async {
    final db = await _dbHelper.database;
    return await db.query('held_carts', orderBy: 'id DESC');
  }

  // Получить товары конкретного отложенного чека
  Future<List<Map<String, dynamic>>> getHeldCartItems(int cartId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery(
      'SELECT hci.quantity, p.* FROM held_cart_items hci JOIN products p ON hci.product_id = p.id WHERE hci.held_cart_id = ?',
      [cartId],
    );
  }

  // Удалить чек из отложенных (когда мы его вернули в кассу)
  Future<void> deleteHeldCart(int cartId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(
        'held_cart_items',
        where: 'held_cart_id = ?',
        whereArgs: [cartId],
      );
      await txn.delete('held_carts', where: 'id = ?', whereArgs: [cartId]);
    });
  }
}
