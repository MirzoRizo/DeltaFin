import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:shop_core/shop_core.dart';

class InventoryManager {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> saveProduct(Product product) async {
    if (product.barcode.isEmpty)
      throw Exception('Штрихкод не может быть пустым.');
    if (product.price <= 0)
      throw Exception('Розничная цена должна быть больше нуля.');
    if (product.stock < 0)
      throw Exception('Остаток не может быть отрицательным.');

    final db = await _dbHelper.database;
    try {
      // БЕЗОПАСНОСТЬ: UPSERT избавляет от задвоений и состояния гонки
      await db.rawInsert(
        '''
        INSERT INTO products (barcode, name, cost_price, price, stock, category_id, is_weight, unit, image_path, popularity)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(barcode) DO UPDATE SET
          stock = products.stock + excluded.stock,
          cost_price = excluded.cost_price,
          price = excluded.price,
          name = excluded.name,
          category_id = excluded.category_id,
          is_weight = excluded.is_weight,
          unit = excluded.unit
      ''',
        [
          product.barcode,
          product.name,
          product.costPrice,
          product.price,
          product.stock,
          product.categoryId,
          product.isWeight ? 1 : 0,
          product.unit,
          product.imagePath,
          product.popularity,
        ],
      );
    } on DatabaseException catch (e) {
      print('DB Error: $e');
      throw Exception('Ошибка сохранения товара. Проверьте данные.');
    }
  }

  // БЕЗОПАСНОСТЬ: Работа с файлами убрана из UI
  Future<String> saveImageFile(int productId, String sourceFilePath) async {
    final File sourceFile = File(sourceFilePath);
    if (!await sourceFile.exists()) throw Exception('Файл не найден');

    final Directory appDocDir = await getApplicationSupportDirectory();
    final String sharedDir = p.join(appDocDir.path, 'ShopSystem', 'Images');

    final dir = Directory(sharedDir);
    if (!await dir.exists()) await dir.create(recursive: true);

    final String fileExt = p.extension(sourceFile.path);
    final String newFileName =
        'prod_${productId}_${DateTime.now().millisecondsSinceEpoch}$fileExt';
    final String newPath = p.join(sharedDir, newFileName);

    await sourceFile.copy(newPath);
    await updateProductImage(productId, newFileName);
    return newPath;
  }

  Future<void> updateProductImage(int productId, String imagePath) async {
    final db = await _dbHelper.database;
    final safeFileName = p.basename(imagePath); // В БД только имя файла
    await db.update(
      'products',
      {'image_path': safeFileName},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  // Остальные методы (getCategories, getProductByBarcode, generateSmartPLU,
  // getProducts, generateInternalEan13) остаются без изменений как в твоем файле...

  // (Здесь скопируй старые методы из своего файла для полноты класса)
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
        throw Exception('Группа переполнена!');
    }
    return (minRange + 1).toString();
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
      baseCode = (int.parse(lastBase) + 1).toString().padLeft(12, '0');
    } else {
      baseCode = "200000000001";
    }
    int checksum = _calculateEan13Checksum(baseCode);
    return '$baseCode$checksum';
  }
}
