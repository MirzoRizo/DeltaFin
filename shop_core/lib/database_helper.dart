import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart'; // <--- Добавили для безопасности путей

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static Future<Database>? _dbFuture;

  DatabaseHelper._init();

  Future<Database> get database {
    if (_database != null) return Future.value(_database!);
    _dbFuture ??= _initDB('shop_core_mvp.db').then((db) {
      _database = db;
      return db;
    });
    return _dbFuture!;
  }

  Future<Database> _initDB(String filePath) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // ИСПРАВЛЕНО: Используем общую папку "Документы" вместо изолированной AppSupport
    final Directory appDocDir = await getApplicationDocumentsDirectory();

    // Теперь база будет лежать по пути: C:\Users\ТвоеИмя\Documents\ShopSystem
    final String sharedDir = join(appDocDir.path, 'ShopSystem');

    final dir = Directory(sharedDir);
    if (!await dir.exists()) await dir.create(recursive: true);

    final path = join(sharedDir, filePath);
    print('Путь к БД: $path'); // Выведет путь в консоль, чтобы ты мог его найти

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 9,
        onConfigure: (db) async {
          await db.execute('PRAGMA busy_timeout = 5000;');
          await db.execute('PRAGMA foreign_keys = ON;'); // Защита целостности
        },
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      ),
    );
  }

  Future<void> _createDB(Database db, int version) async {
    final batch = db.batch();
    // Создаем все таблицы через batch для скорости и надежности
    batch.execute(
      '''CREATE TABLE products (id INTEGER PRIMARY KEY AUTOINCREMENT, barcode TEXT UNIQUE NOT NULL, name TEXT NOT NULL, cost_price REAL NOT NULL, price REAL NOT NULL, stock REAL NOT NULL, category_id INTEGER, is_weight INTEGER NOT NULL DEFAULT 0, unit TEXT NOT NULL DEFAULT 'шт', image_path TEXT, popularity INTEGER NOT NULL DEFAULT 0)''',
    );
    batch.execute(
      '''CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, prefix INTEGER NOT NULL UNIQUE CHECK(prefix >= 1 AND prefix <= 9))''',
    );
    batch.execute(
      '''CREATE TABLE sales (id INTEGER PRIMARY KEY AUTOINCREMENT, shift_id INTEGER NOT NULL DEFAULT 0, date TEXT NOT NULL, total_amount REAL NOT NULL, payment_type TEXT NOT NULL DEFAULT 'Наличными', is_returned INTEGER NOT NULL DEFAULT 0, is_synced INTEGER DEFAULT 0)''',
    );
    batch.execute(
      '''CREATE TABLE sale_items (id INTEGER PRIMARY KEY AUTOINCREMENT, sale_id INTEGER NOT NULL, product_id INTEGER NOT NULL, quantity REAL NOT NULL CHECK(quantity > 0), returned_quantity REAL NOT NULL DEFAULT 0, price REAL NOT NULL, FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE)''',
    );
    batch.execute(
      '''CREATE TABLE shifts (id INTEGER PRIMARY KEY AUTOINCREMENT, opened_at TEXT NOT NULL, closed_at TEXT, is_open INTEGER NOT NULL DEFAULT 1)''',
    );
    batch.execute(
      '''CREATE TABLE cash_operations (id INTEGER PRIMARY KEY AUTOINCREMENT, shift_id INTEGER NOT NULL, type TEXT NOT NULL, amount REAL NOT NULL, created_at TEXT NOT NULL)''',
    );
    batch.execute(
      '''CREATE TABLE held_carts (id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, total_amount REAL NOT NULL)''',
    );
    batch.execute(
      '''CREATE TABLE held_cart_items (id INTEGER PRIMARY KEY AUTOINCREMENT, held_cart_id INTEGER NOT NULL, product_id INTEGER NOT NULL, quantity REAL NOT NULL)''',
    );
    // ДОБАВЛЯЕМ ИНДЕКСЫ:
    // Индекс для ускорения фильтрации по категориям в админке
    batch.execute(
      'CREATE INDEX idx_products_category ON products(category_id)',
    );

    // Составной индекс для кассы: мгновенная выборка весовых товаров и сортировка по популярности
    batch.execute(
      'CREATE INDEX idx_products_weight_pop ON products(is_weight, popularity DESC)',
    );

    // Индекс для поиска товаров по названию (опционально, ускоряет LIKE 'A%')
    batch.execute('CREATE INDEX idx_products_name ON products(name)');
    await batch.commit();
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Безопасные миграции без слепых catch(e)
    try {
      if (oldVersion < 3) {
        await _safeAddColumn(
          db,
          'sales',
          'shift_id',
          'INTEGER NOT NULL DEFAULT 0',
        );
        await _safeAddColumn(
          db,
          'sales',
          'payment_type',
          "TEXT NOT NULL DEFAULT 'Наличными'",
        );
        await _safeAddColumn(
          db,
          'sales',
          'is_returned',
          'INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'CREATE TABLE IF NOT EXISTS shifts (id INTEGER PRIMARY KEY AUTOINCREMENT, opened_at TEXT NOT NULL, closed_at TEXT, is_open INTEGER NOT NULL DEFAULT 1)',
        );
        await db.execute(
          'CREATE TABLE IF NOT EXISTS cash_operations (id INTEGER PRIMARY KEY AUTOINCREMENT, shift_id INTEGER NOT NULL, type TEXT NOT NULL, amount REAL NOT NULL, created_at TEXT NOT NULL)',
        );
      }
      if (oldVersion < 4)
        await _safeAddColumn(
          db,
          'sale_items',
          'returned_quantity',
          'REAL NOT NULL DEFAULT 0',
        );
      if (oldVersion < 5)
        await _safeAddColumn(db, 'products', 'image_path', 'TEXT');
      if (oldVersion < 6) {
        await db.execute(
          'CREATE TABLE IF NOT EXISTS held_carts (id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, total_amount REAL NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE IF NOT EXISTS held_cart_items (id INTEGER PRIMARY KEY AUTOINCREMENT, held_cart_id INTEGER NOT NULL, product_id INTEGER NOT NULL, quantity REAL NOT NULL)',
        );
      }
      if (oldVersion < 7)
        await _safeAddColumn(
          db,
          'products',
          'popularity',
          'INTEGER NOT NULL DEFAULT 0',
        );
      if (oldVersion < 8) {
        await db.transaction((txn) async {
          await txn.execute(
            '''CREATE TABLE IF NOT EXISTS products_new (id INTEGER PRIMARY KEY AUTOINCREMENT, barcode TEXT UNIQUE NOT NULL, name TEXT NOT NULL, cost_price REAL NOT NULL, price REAL NOT NULL, stock REAL NOT NULL, category_id INTEGER, is_weight INTEGER NOT NULL DEFAULT 0, unit TEXT NOT NULL DEFAULT 'шт', image_path TEXT, popularity INTEGER NOT NULL DEFAULT 0)''',
          );
          await txn.execute(
            'INSERT INTO products_new SELECT id, barcode, name, cost_price, price, stock, category_id, is_weight, unit, image_path, popularity FROM products',
          );
          await txn.execute('DROP TABLE products');
          await txn.execute('ALTER TABLE products_new RENAME TO products');
        });
      }
      // === ДОБАВЛЯЕМ НОВЫЙ БЛОК ДЛЯ ВЕРСИИ 9 ===
      if (oldVersion < 9) {
        // Добавляем индексы безопасно через IF NOT EXISTS
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_products_weight_pop ON products(is_weight, popularity DESC)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_products_name ON products(name)',
        );
      }
    } catch (e) {
      print('КРИТИЧЕСКАЯ ОШИБКА МИГРАЦИИ БД: $e');
      rethrow;
    }
  }

  Future<void> _safeAddColumn(
    Database db,
    String table,
    String colName,
    String colDef,
  ) async {
    final res = await db.rawQuery("PRAGMA table_info($table)");
    if (!res.any((r) => r['name'] == colName)) {
      await db.execute('ALTER TABLE $table ADD COLUMN $colName $colDef');
    }
  }
}

