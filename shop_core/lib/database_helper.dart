import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

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

    final String sharedDir = 'C:\\ProgramData\\ShopSystem';
    final dir = Directory(sharedDir);
    if (!await dir.exists()) await dir.create(recursive: true);

    final path = join(sharedDir, filePath);

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 8, // <--- ПОВЫШАЕМ ДО ВЕРСИИ 8
        onConfigure: (db) async {
          // АНТИ-БЛОКИРОВКА: Ждать 5 секунд, если база занята Складом
          await db.execute('PRAGMA busy_timeout = 5000;');
        },
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      ),
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // УБРАЛИ CHECK(stock >= 0), теперь можно продавать в минус!
    await db.execute(
      '''CREATE TABLE products (id INTEGER PRIMARY KEY AUTOINCREMENT, barcode TEXT UNIQUE NOT NULL, name TEXT NOT NULL, cost_price REAL NOT NULL, price REAL NOT NULL, stock REAL NOT NULL, category_id INTEGER, is_weight INTEGER NOT NULL DEFAULT 0, unit TEXT NOT NULL DEFAULT 'шт', image_path TEXT, popularity INTEGER NOT NULL DEFAULT 0)''',
    );
    await db.execute(
      '''CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, prefix INTEGER NOT NULL UNIQUE CHECK(prefix >= 1 AND prefix <= 9))''',
    );
    await db.execute(
      '''CREATE TABLE sales (id INTEGER PRIMARY KEY AUTOINCREMENT, shift_id INTEGER NOT NULL DEFAULT 0, date TEXT NOT NULL, total_amount REAL NOT NULL, payment_type TEXT NOT NULL DEFAULT 'Наличными', is_returned INTEGER NOT NULL DEFAULT 0, is_synced INTEGER DEFAULT 0)''',
    );
    await db.execute(
      '''CREATE TABLE sale_items (id INTEGER PRIMARY KEY AUTOINCREMENT, sale_id INTEGER NOT NULL, product_id INTEGER NOT NULL, quantity REAL NOT NULL CHECK(quantity > 0), returned_quantity REAL NOT NULL DEFAULT 0, price REAL NOT NULL)''',
    );
    await db.execute(
      '''CREATE TABLE shifts (id INTEGER PRIMARY KEY AUTOINCREMENT, opened_at TEXT NOT NULL, closed_at TEXT, is_open INTEGER NOT NULL DEFAULT 1)''',
    );
    await db.execute(
      '''CREATE TABLE cash_operations (id INTEGER PRIMARY KEY AUTOINCREMENT, shift_id INTEGER NOT NULL, type TEXT NOT NULL, amount REAL NOT NULL, created_at TEXT NOT NULL)''',
    );
    await db.execute(
      '''CREATE TABLE held_carts (id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, total_amount REAL NOT NULL)''',
    );
    await db.execute(
      '''CREATE TABLE held_cart_items (id INTEGER PRIMARY KEY AUTOINCREMENT, held_cart_id INTEGER NOT NULL, product_id INTEGER NOT NULL, quantity REAL NOT NULL)''',
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Старые обновления...
    if (oldVersion < 3) {
      try {
        await db.execute(
          'ALTER TABLE sales ADD COLUMN shift_id INTEGER NOT NULL DEFAULT 0',
        );
      } catch (e) {}
      try {
        await db.execute(
          "ALTER TABLE sales ADD COLUMN payment_type TEXT NOT NULL DEFAULT 'Наличными'",
        );
      } catch (e) {}
      try {
        await db.execute(
          'CREATE TABLE shifts (id INTEGER PRIMARY KEY AUTOINCREMENT, opened_at TEXT NOT NULL, closed_at TEXT, is_open INTEGER NOT NULL DEFAULT 1)',
        );
      } catch (e) {}
      try {
        await db.execute(
          'CREATE TABLE cash_operations (id INTEGER PRIMARY KEY AUTOINCREMENT, shift_id INTEGER NOT NULL, type TEXT NOT NULL, amount REAL NOT NULL, created_at TEXT NOT NULL)',
        );
      } catch (e) {}
      try {
        await db.execute(
          'ALTER TABLE sales ADD COLUMN is_returned INTEGER NOT NULL DEFAULT 0',
        );
      } catch (e) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute(
          'ALTER TABLE sale_items ADD COLUMN returned_quantity REAL NOT NULL DEFAULT 0',
        );
      } catch (e) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN image_path TEXT');
      } catch (e) {}
    }
    if (oldVersion < 6) {
      try {
        await db.execute(
          'CREATE TABLE held_carts (id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, total_amount REAL NOT NULL)',
        );
      } catch (e) {}
      try {
        await db.execute(
          'CREATE TABLE held_cart_items (id INTEGER PRIMARY KEY AUTOINCREMENT, held_cart_id INTEGER NOT NULL, product_id INTEGER NOT NULL, quantity REAL NOT NULL)',
        );
      } catch (e) {}
    }
    if (oldVersion < 7) {
      try {
        await db.execute(
          'ALTER TABLE products ADD COLUMN popularity INTEGER NOT NULL DEFAULT 0',
        );
      } catch (e) {}
    }

    // --- НОВОЕ: ВЕРСИЯ 8 (Миграция для продажи в МИНУС) ---
    if (oldVersion < 8) {
      try {
        // Создаем новую таблицу без жесткого правила проверки остатка
        await db.execute(
          '''CREATE TABLE products_new (id INTEGER PRIMARY KEY AUTOINCREMENT, barcode TEXT UNIQUE NOT NULL, name TEXT NOT NULL, cost_price REAL NOT NULL, price REAL NOT NULL, stock REAL NOT NULL, category_id INTEGER, is_weight INTEGER NOT NULL DEFAULT 0, unit TEXT NOT NULL DEFAULT 'шт', image_path TEXT, popularity INTEGER NOT NULL DEFAULT 0)''',
        );
        // Копируем туда все старые товары
        await db.execute(
          'INSERT INTO products_new SELECT id, barcode, name, cost_price, price, stock, category_id, is_weight, unit, image_path, popularity FROM products',
        );
        // Удаляем старую строгую таблицу
        await db.execute('DROP TABLE products');
        // Переименовываем новую
        await db.execute('ALTER TABLE products_new RENAME TO products');
      } catch (e) {}
    }
  }
}
