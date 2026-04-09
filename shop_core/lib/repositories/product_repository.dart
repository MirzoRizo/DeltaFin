import 'package:shop_core/database_helper.dart';
import 'package:shop_core/models.dart';

class ProductRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Получаем ВСЕ категории, в которых есть хотя бы один товар (убрали фильтр is_weight)
  Future<List<Category>> getCategoriesWithProducts() async {
    final db = await _dbHelper.database;
    final catMaps = await db.rawQuery(
      'SELECT DISTINCT c.* FROM categories c JOIN products p ON c.id = p.category_id',
    );
    return catMaps.map((c) => Category.fromMap(c)).toList();
  }

  // Универсальный поиск ВСЕХ товаров
  Future<List<Product>> getProducts({
    int? categoryId,
    String query = '',
  }) async {
    final db = await _dbHelper.database;

    // ИСПРАВЛЕНО: Ищем все товары (1=1), а не только весовые (is_weight = 1)
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (categoryId != null) {
      whereClause += ' AND category_id = ?';
      whereArgs.add(categoryId);
    }

    if (query.isNotEmpty) {
      whereClause += ' AND name LIKE ?';
      whereArgs.add('%$query%');
    }

    final prodMaps = await db.query(
      'products',
      where: whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'popularity DESC, name ASC',
      limit: 100,
    );

    return prodMaps.map((map) => Product.fromMap(map)).toList();
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode.trim()],
    );
    if (result.isNotEmpty) {
      return Product.fromMap(result.first);
    }
    return null;
  }
}
