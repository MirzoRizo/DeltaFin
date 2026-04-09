//import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shop_core/shop_core.dart';

class InventoryManager {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  //final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveProduct(Product product) async {
    if (product.barcode.isEmpty)
      throw Exception('Штрихкод не может быть пустым. Отказ системы.');
    if (product.price <= 0)
      throw Exception('Розничная цена должна быть больше нуля.');
    if (product.stock < 0)
      throw Exception('Остаток не может быть отрицательным.');

    final db = await _dbHelper.database;

    try {
      final existing = await db.query(
        'products',
        where: 'barcode = ?',
        whereArgs: [product.barcode],
      );

      if (existing.isNotEmpty) {
        int localId = existing.first['id'] as int;
        await db.rawUpdate(
          'UPDATE products SET stock = stock + ?, cost_price = ?, price = ? WHERE id = ?',
          [product.stock, product.costPrice, product.price, localId],
        );
      } else {
        await db.insert('products', product.toMap());
      }
    } catch (e) {
      throw Exception('Критическая ошибка базы данных: $e');
    }
  }

  Future<List<Category>> getCategories() async {
    final db = await _dbHelper.database;
    final maps = await db.query('categories', orderBy: 'name ASC');
    return maps.map((map) => Category.fromMap(map)).toList();
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
    if (result.isNotEmpty) return Product.fromMap(result.first);
    return null;
  }

  Future<String> generateSmartPLU(int categoryPrefix) async {
    final db = await _dbHelper.database;
    int minRange = categoryPrefix * 1000;
    int maxRange = minRange + 999;

    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT barcode FROM products WHERE CAST(barcode AS INTEGER) >= ? AND CAST(barcode AS INTEGER) <= ? ORDER BY CAST(barcode AS INTEGER) DESC LIMIT 1',
      [minRange, maxRange],
    );

    if (result.isNotEmpty) {
      int lastPlu = int.parse(result.first['barcode'].toString());
      if (lastPlu < maxRange)
        return (lastPlu + 1).toString();
      else
        throw Exception('Группа переполнена (достигнут лимит в 999 товаров)!');
    }
    return (minRange + 1).toString();
  }

  Future<List<Product>> getProducts({
    String query = '',
    int? categoryId,
  }) async {
    final db = await _dbHelper.database;
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (query.isNotEmpty) {
      whereClause += ' AND (name LIKE ? OR barcode LIKE ?)';
      whereArgs.addAll(['%$query%', '%$query%']);
    }

    if (categoryId != null) {
      whereClause += ' AND category_id = ?';
      whereArgs.add(categoryId);
    }

    final maps = await db.query(
      'products',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );
    return maps.map((map) => Product.fromMap(map)).toList();
  }

  int _calculateEan13Checksum(String code12) {
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      int digit = int.parse(code12[i]);
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    return (10 - (sum % 10)) % 10;
  }

  Future<String> generateInternalEan13() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      "SELECT barcode FROM products WHERE barcode LIKE '200%' AND length(barcode) = 13 ORDER BY barcode DESC LIMIT 1",
    );

    String baseCode;
    if (result.isNotEmpty) {
      String lastBarcode = result.first['barcode'].toString();
      String lastBase = lastBarcode.substring(0, 12);
      int nextVal = int.parse(lastBase) + 1;
      baseCode = nextVal.toString().padLeft(12, '0');
    } else {
      baseCode = "200000000001";
    }

    int checksum = _calculateEan13Checksum(baseCode);
    return '$baseCode$checksum';
  }

  // --- МЕТОД ДЛЯ МИНИ-АДМИНКИ (СОХРАНЕНИЕ ФОТО) ---
  Future<void> updateProductImage(int productId, String imagePath) async {
    final db = await _dbHelper.database;
    await db.update(
      'products',
      {'image_path': imagePath},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }
}
