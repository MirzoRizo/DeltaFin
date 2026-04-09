import 'package:shop_core/shop_core.dart';

class CategoryManager {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Получить все группы, отсортированные по префиксу (1, 2, 3...)
  Future<List<Category>> getCategories() async {
    final db = await _dbHelper.database;
    final maps = await db.query('categories', orderBy: 'prefix ASC');
    return maps.map((map) => Category.fromMap(map)).toList();
  }

  // Бронебойное добавление группы
  Future<void> addCategory(String name, int prefix) async {
    if (name.trim().isEmpty) {
      throw Exception('Название группы не может быть пустым.');
    }
    if (prefix < 1 || prefix > 9) {
      throw Exception('Префикс должен быть цифрой от 1 до 9.');
    }

    final db = await _dbHelper.database;
    try {
      await db.insert('categories', {'name': name.trim(), 'prefix': prefix});
    } catch (e) {
      // Ошибка SQLite перехватывается, если мы нарушили UNIQUE
      throw Exception(
        'Ошибка: Группа с таким названием или цифрой ($prefix) уже существует!',
      );
    }
  }

  // Удаление (на будущее)
  Future<void> deleteCategory(int id) async {
    final db = await _dbHelper.database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }
}
